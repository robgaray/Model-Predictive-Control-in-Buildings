# -------------------------------------------------------------
# Function: implement_control_step.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
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
# -------------------------------------------------------------
# Inputs
#   period_chunk               : Data frame. Full simulation data for at least
#                                the current control window. Must contain all
#                                columns required by period_calculation(), plus
#                                a 'time' column of POSIXct values.
#   indexes                    : Named list. Index metadata. Must contain:
#                                  indexes$i0              : Integer. Current
#                                                            simulation step index.
#                                  indexes$i_begin_horizon : Integer. Horizon start
#                                                            index (used to compute
#                                                            optimization_frequency_sec).
#   timestamps                 : Named list. Timestamp metadata. Must contain:
#                                  timestamps$time_sec : Numeric vector of the full
#                                                        time series in seconds.
#   parameters                 : Named list. Model parameters passed to
#                                period_calculation(). Must contain:
#                                  parameters$debug_and_config$verbose :
#                                    Logical. Enables console logging.
#   calculation_mode           : Integer scalar. Passed to period_calculation().
#                                1 = Setpoint mode (default).
#                                2 = Heat Input mode.
#   calculation_context        : Character. Passed to period_calculation().
#                                One of "execution", "plan", or "plan_flex".
# -------------------------------------------------------------
# Outputs
#   period_chunk : Data frame. The trimmed and simulated control window,
#                  with all columns from period_calculation() updated
#                  according to calculation_context.
# -------------------------------------------------------------
# Code outline
# 1. Build set_point_df from period_chunk plan columns
# 2. Run period_calculation with given context
# 3. Return updated period_chunk
# -------------------------------------------------------------
# Usage instructions
# result <- implement_control_step(period_chunk, indexes, timestamps, parameters, calculation_mode, calculation_context)
# -------------------------------------------------------------
# Where this function/script is used
# Called by simulation.R during initialization (step 2) and
# implementation (step 4) phases of the MPC loop.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If the trimmed period_chunk has fewer than 2 rows (edge case at the end
#     of the simulation), the function returns early without calling
#     period_calculation(). A warning message is printed if verbose = TRUE.
# -------------------------------------------------------------
# functions/scripts called
#   period_calculation() - core building physics simulation
# -------------------------------------------------------------
implement_control_step <- function(period_chunk,
                                   indexes,
                                   timestamps,
                                   parameters,
                                   calculation_mode = 1,
                                   calculation_context) {
  # Extract parameters
  i0                         <- indexes$i0
  time_sec                   <- timestamps$time_sec
  optimization_frequency_sec <- timestamps$time_sec[indexes$i_begin_horizon] -
                                 timestamps$time_sec[indexes$i0]

  # Edge case: not enough rows to simulate
  if (nrow(period_chunk) < 2) {
    if (parameters$debug_and_config$verbose) {
      cat("period_chunk<2 exception case triggered\n",
          "Step initiation:", format(period_chunk$time[1]), "\n",
          "Step end:"       , format(period_chunk$time[nrow(period_chunk)]), "\n")
    }
    return(period_chunk)
  }

  # Simulate using actual external temperature and solar radiation
  period_chunk <- period_calculation(
    period_chunk        = period_chunk,
    parameters          = parameters,
    calculation_mode    = calculation_mode,
    calculation_context = calculation_context
  )

  if (parameters$debug_and_config$verbose) {
    cat("\n")
    cat("======================================\n")
    cat("Simulation timestep:", i0, "completed \n")
    cat("Step initiation:"      , format(period_chunk$time[1]), "\n")
    cat("Control step end:"     , format(period_chunk$time[nrow(period_chunk)]), "\n")
    cat("======================================\n")
  }

  return(period_chunk)
}