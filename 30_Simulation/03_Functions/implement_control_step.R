# -------------------------------------------------------------
# Function: implement_control_step.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function implements a single MPC control step by running the
# physical simulation of the building over the control implementation
# horizon using actual (measured) weather data and the setpoints that
# were previously optimized by optimize_control_step().
# It performs the following steps:
#   1. Determines the end index of the control window based on
#      optimization_frequency_sec starting from i0.
#   2. Trims period_chunk to the control window.
#   3. Calls period_calculation() with the actual weather data and
#      the provided setpoints.
#   4. Appends forecasted state columns from forecast_states to the
#      result for later comparison and logging.
#   5. For calculation_context == "execution" only: resolves
#      Elec_deviations_net_cost_h for the just-simulated rows via
#      calc_differential_cost(), since period_calculation() itself
#      performs no economic calculation (see period_calculation.R and
#      period_simulation_cpp.cpp headers). E_orig is the row's last
#      committed plan (Elec_total_plan) and E_new is the realized
#      Elec_total_exec, so this values the deviation from what was
#      planned, not the whole executed energy from zero (positive =
#      net income, negative = net expense, per
#      calc_differential_cost()'s sign convention). Also resolves
#      Elec_cost_distr_h for the same rows, as
#      -Elec_unit_cost_distribution * abs(Elec_total_exec) (negative,
#      since distribution is always an expense) - the net of all
#      electricity bought/sold in that hour, market and deviations
#      combined, since Elec_total_exec is already that net by
#      construction (see
#      01_Agent_Comments/20260725_Plan_Reporte_Costes_Mercados_Main_df.md,
#      Parte B.4/B.9). Finally, Elec_net_cost_h = Elec_market_net_cost_h
#      (already accumulated in Main_df by any prior market decision for
#      that row, via integrate_market_process.R) + the just-resolved
#      Elec_deviations_net_cost_h. Elec_total_no_flex is also fixed for
#      the same rows, since it is execution-phase state (see step 3
#      below).
# -------------------------------------------------------------
# Sign convention of the flexibility-execution columns
# Elec_flex_execution_revenue_h and Elec_flex_deviations_net_cost_h are
# reserved for the execution of explicit flexibility, which is not
# simulated yet, so nothing writes to them today and both stay 0 for
# every row. When they are written, they must carry the repository's
# usual sign - positive = income to the building, negative = expense -
# exactly like every other economic column here. Their consumer,
# economic_analysis_finalize.R, adds them together to get the executed-
# flexibility cash flow; it does not negate either of them. Writing
# Elec_flex_deviations_net_cost_h as a positive "cost" magnitude would
# therefore flip the sign of that cash flow.
# -------------------------------------------------------------
# Inputs
#   period_chunk               : Data frame. Full simulation data for at least
#                                the current control window. Must contain all
#                                columns required by period_calculation(),
#                                plus (for calculation_context == "execution")
#                                Elec_total_plan, Elec_total_exec,
#                                Elec_unit_cost_import_buy/sell,
#                                Elec_unit_cost_export_buy/sell,
#                                Elec_unit_cost_distribution,
#                                Elec_market_net_cost_h, Elec_deviations_net_cost_h,
#                                Elec_cost_distr_h, Elec_net_cost_h and
#                                Elec_total_no_flex, plus a 'time' column of
#                                POSIXct values.
#   simulation_control         : Named list. Control metadata. Only
#                                simulation_control$calculation_mode is read
#                                here (default: 1 = Setpoint mode, used when
#                                NULL/absent).
#   timestamps                 : Named list. Timestamp metadata, forwarded
#                                unused to this function's signature but kept
#                                for interface symmetry with run_market_process().
#   parameters                 : Named list. Model parameters passed to
#                                period_calculation(). Must contain:
#                                  parameters$debug_and_config$verbose :
#                                    Logical. Enables console logging.
#   calculation_context        : Character. Passed to period_calculation().
#                                One of "execution", "plan", or "plan_flex".
# -------------------------------------------------------------
# Outputs
#   period_chunk : Data frame. The trimmed and simulated control window,
#                  with all columns from period_calculation() updated
#                  according to calculation_context.
# -------------------------------------------------------------
# Code outline
# 0. Extract calculation_mode from simulation_control (default 1)
# 1. Validate: if period_chunk has fewer than 2 rows, return it
#    unchanged (see EXCEPTIONS below)
# 2. Run period_calculation() with calculation_mode/calculation_context
# 3. If calculation_context == "execution": resolve
#    Elec_deviations_net_cost_h, Elec_cost_distr_h, Elec_net_cost_h and
#    Elec_total_no_flex for the new rows (see header above)
# 4. Return updated period_chunk
# -------------------------------------------------------------
# Usage instructions
# result <- implement_control_step(period_chunk, simulation_control, timestamps, parameters, calculation_context)
# -------------------------------------------------------------
# Where this function/script is used
# Called by simulation.R during initialization (step 2) and
# implementation (step 4) phases of the MPC loop, and by
# run_market_process.R (step 3, Initialization) to run the
# calculation_context == "plan" pass used to seed the market's
# optimization chunk.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If the trimmed period_chunk has fewer than 2 rows, the function
#     returns early without calling period_calculation(). A warning message
#     is printed if verbose = TRUE. This is a defensive fallback: the
#     execution-phase call from simulation.R already skips calling this
#     function entirely at the last simulation row (where this condition
#     would otherwise always occur), but the guard remains here in case
#     of degenerate horizons from other callers.
#   - calculation_mode defaults to 1 (Setpoint) when simulation_control$calculation_mode
#     is NULL or absent.
# -------------------------------------------------------------
# functions/scripts called
#   period_calculation()       - core building physics simulation
#   calc_differential_cost()   - resolves Elec_deviations_net_cost_h for
#                                 "execution" only
#   (Elec_cost_distr_h/Elec_net_cost_h are resolved inline, no helper
#   function needed)
# -------------------------------------------------------------
implement_control_step <- function(period_chunk,
                                  simulation_control,
                                   timestamps,
                                   parameters,
                                   calculation_context) {
  # 0. Extract parameters
  {
    calculation_mode <- if (!is.null(simulation_control$calculation_mode)) {
      simulation_control$calculation_mode
    } else {
      1
    }
  }
  
  # 1. Validation
  {
    if (nrow(period_chunk) < 2) {
      if (parameters$debug_and_config$verbose) {
        cat("period_chunk<2 exception case triggered\n",
            "Step initiation:", format(period_chunk$time[1]), "\n",
            "Step end:"       , format(period_chunk$time[nrow(period_chunk)]), "\n")
      }
      return(period_chunk)
    }
  }

  # 2. Simulation
  {
    # period_calculation is called to run the building physics
    # simulation over this control window, using the actual (measured)
    # weather data and the setpoints already resolved for
    # calculation_context.
    period_chunk <- period_calculation(
      period_chunk        = period_chunk,
      parameters          = parameters,
      calculation_mode    = calculation_mode,
      calculation_context = calculation_context
    )
  }

  # 3. Economic accounting (execution only, see header)
  {
    if (calculation_context == "execution") {
      new_rows <- 2:nrow(period_chunk)
      # calc_differential_cost is called to value the deviation between
      # the last committed plan (Elec_total_plan) and the realized
      # execution (Elec_total_exec) for the newly-simulated rows, under
      # this row's market/deviation prices (see header above).
      period_chunk$Elec_deviations_net_cost_h[new_rows] <- calc_differential_cost(
        E_orig        = period_chunk$Elec_total_plan[new_rows],
        E_new         = period_chunk$Elec_total_exec[new_rows],
        P_import_buy  = period_chunk$Elec_unit_cost_import_buy[new_rows],
        P_import_sell = period_chunk$Elec_unit_cost_import_sell[new_rows],
        P_export_buy  = period_chunk$Elec_unit_cost_export_buy[new_rows],
        P_export_sell = period_chunk$Elec_unit_cost_export_sell[new_rows]
      )
      period_chunk$Elec_cost_distr_h[new_rows] <-
        -period_chunk$Elec_unit_cost_distribution[new_rows] *
        abs(period_chunk$Elec_total_exec[new_rows])
      period_chunk$Elec_net_cost_h[new_rows] <-
        period_chunk$Elec_market_net_cost_h[new_rows] +
        period_chunk$Elec_deviations_net_cost_h[new_rows]
      # Elec_total_no_flex is reserved for the energy that would have
      # been used during a flexibility event had that event not been
      # executed (see
      # 00_Agent_Input/20260818_comentarios_observaciones_anteriores.md,
      # finding 4). It is fixed here, once per executed row, together
      # with the rest of this row's execution-phase accounting.
      # Flexibility execution is not simulated yet (Elec_flex_execution_revenue_h/
      # Elec_flex_deviations_net_cost_h are always 0), so the executed
      # energy is always the baseline plan: until execution is
      # implemented, Elec_total_no_flex trivially equals Elec_total_exec.
      period_chunk$Elec_total_no_flex[new_rows] <-
        period_chunk$Elec_total_exec[new_rows]
    }
  }

  if (parameters$debug_and_config$verbose && calculation_context == "execution") {
    cat("\n")
    cat("======================================\n")
    cat("Energy transfer performed\n")
    cat("Transfer period begin:", format(period_chunk$time[1]), "\n")
    cat("Transfer period end:"  , format(period_chunk$time[nrow(period_chunk)]), "\n")
    cat("======================================\n")
  }

  return(period_chunk)
}