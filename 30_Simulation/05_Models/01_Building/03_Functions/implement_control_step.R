# -------------------------------------------------------------
# Function: implement_control_step.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function implements a single MPC control step by running the
# physical simulation of the building over the window it receives,
# with the setpoints that the markets have already written in it. The
# weather it uses is the one period_calculation() reads for the
# calculation context: the actual (measured) weather for "execution",
# and the forecast for "plan" and the flexibility contexts.
# It does not cut the window: period_chunk is simulated as received,
# and the caller chooses its rows.
# It is the asset side of the execution: it works with the physics of
# the building, writes no money and no column of the system. The
# executed net electricity of the system without a flexibility event
# (Elec_total_no_flex) is fixed by simulate(), and the execution cash
# flows of the new rows (Elec_deviations_net_cost_h, Elec_cost_distr_h
# and Elec_net_cost_h) are settled by settle_execution(), on the net
# electricity of the system that Main_df holds once every asset has
# executed the step.
# -------------------------------------------------------------
# Inputs
#   period_chunk               : Data frame. Full simulation data for at least
#                                the current control window. Must contain all
#                                columns required by period_calculation(),
#                                plus a 'time' column of POSIXct values.
#   simulation_control         : Named list. Control metadata. Only
#                                simulation_control$calculation_mode is read
#                                here (default: 1 = Setpoint mode, used when
#                                NULL/absent).
#   timestamps                 : Named list. Timestamp metadata, forwarded
#                                unused to this function's signature but kept
#                                for interface symmetry with
#                                run_market_process().
#   parameters                 : Named list. Must contain:
#                                  parameters$debug_and_config$verbose :
#                                    Logical. Enables console logging.
#   asset                      : Named list. The parameters of the
#                                building, its entry of
#                                parameters$assets, passed to
#                                period_calculation().
#   calculation_context        : Character. Passed to period_calculation().
#                                One of "execution", "plan",
#                                "plan_flex_down" or "plan_flex_up".
# -------------------------------------------------------------
# Outputs
#   period_chunk : Data frame. The simulated control window, with all
#                  columns from period_calculation() updated according
#                  to calculation_context.
# -------------------------------------------------------------
# Code outline
# 0. Extract calculation_mode from simulation_control (default 1)
# 1. Validate: if period_chunk has fewer than 2 rows, return it
#    unchanged (see EXCEPTIONS below)
# 2. Run period_calculation() with calculation_mode/calculation_context
# 3. Return updated period_chunk
# -------------------------------------------------------------
# Usage instructions
# result <- implement_control_step(period_chunk, simulation_control, timestamps,
# parameters, asset, calculation_context)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If period_chunk has fewer than 2 rows, the function
#     returns early without calling period_calculation(). A warning message
#     is printed if verbose = TRUE. This is a defensive fallback: the
#     execution-phase call from simulate() already skips calling this
#     function entirely at the last simulation row (where this condition
#     would otherwise always occur), but the guard remains here in case
#     of degenerate horizons from other callers.
#   - calculation_mode defaults to 1 (Setpoint) when
#     simulation_control$calculation_mode is NULL or absent.
# -------------------------------------------------------------
implement_control_step <- function(period_chunk,
                                  simulation_control,
                                   timestamps,
                                   parameters,
                                   asset,
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
        # console_message is called to warn that the window has a
        # single row, so there is nothing to simulate.
        console_message(
          label = "WARNING",
          text  = "implement_control_step: window of a single row, not simulated",
          time  = period_chunk$time[1]
        )
      }
      return(period_chunk)
    }
  }

  # 2. Simulation
  {
    # period_calculation is called to run the building physics
    # simulation over this control window, with the weather of
    # calculation_context (measured for "execution", forecast
    # otherwise) and the setpoints already resolved for it.
    period_chunk <- period_calculation(
      period_chunk        = period_chunk,
      asset               = asset,
      calculation_mode    = calculation_mode,
      calculation_context = calculation_context
    )
  }

  return(period_chunk)
}