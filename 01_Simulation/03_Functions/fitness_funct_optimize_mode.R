# -------------------------------------------------------------
# Function: fitness_funct_optimize_mode.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function is the fitness function used by the Genetic Algorithm
# in optimize_modes(). It converts a binary GA solution vector into a
# structured setpoint data frame (via mode selection), evaluates the
# building simulation, and returns the resulting scalar reward.
# -------------------------------------------------------------
# Inputs
#   x_bin        : Integer vector (0/1). Binary GA solution of length
#                  n_modes * n_periods. The first n_periods genes correspond
#                  to mode_1, the next n_periods to mode_2, and so on.
#   n_modes      : Integer scalar. Number of available control modes.
#   n_periods    : Integer scalar. Number of market periods in the
#                  optimization horizon.
#   timestamps   : Named list. Timestamp metadata. Must contain:
#                    timestamps$target_periods : POSIXct vector of market
#                                               period timestamps.
#   parameters   : Named list. Model and control parameters. Must contain:
#                    parameters$setpoint_modes : Data frame mapping mode
#                                               indices to setpoint values.
#                    parameters$control$Deadband : Numeric. Deadband.
#                    All other sub-elements required by evaluate_control().
#   period_chunk : Data frame. Simulation data for the optimization
#                  horizon, as passed from optimize_modes().
#                  Must contain all columns required by
#                  period_calculation() (called inside evaluate_control()).
#
# Outputs
#   evaluation : Numeric scalar. Reward value extracted from evaluate_control()
#                return list for the given mode schedule. Higher is better.
#                Returns -99 immediately if maxmode() reports an error
#                (any time step has more than one or zero active modes).
# -------------------------------------------------------------
# Code outline
# 1. Reshape chromosome into mode selections
# 2. Convert mode indices to maxmode result
# 3. Convert modes to setpoints
# 4. Evaluate control and compute reward
# -------------------------------------------------------------
# Usage instructions
# fitness <- fitness_funct_optimize_mode(x, period_chunk, timestamps, parameters)
# -------------------------------------------------------------
# Where this function/script is used
# Called by optimize_modes.R as the GA fitness function.
# -------------------------------------------------------------
# functions/scripts called
#   maxmode()                  - selects highest-active mode per period from
#                                the binary GA vector
#   convert_modes_to_setpoints() - maps mode selections to setpoint values
#                                  with hysteresis deadbands
#   evaluate_control()         - simulates the building and returns the scalar
#                                reward
# -------------------------------------------------------------
fitness_funct_optimize_mode <- function(x_bin,
                                        n_modes,
                                        n_periods,
                                        timestamps,
                                        parameters,
                                        period_chunk) {

  maxmode_result <- maxmode(
    x_bin          = x_bin,
    n_modes        = n_modes,
    n_periods      = n_periods,
    target_periods = timestamps$target_periods
  )

  if (maxmode_result$error) {
    return(-99)
  }

  set_point_df_inner <- maxmode_result$set_point_df_inner

  set_point_df_conv <- convert_modes_to_setpoints(
    setpoint_modes_df = set_point_df_inner,
    setpoint_modes    = parameters$setpoint_modes,
    Deadband          = parameters$control$Deadband,
    target_periods    = timestamps$target_periods
  )

  evaluation <- evaluate_control(
    period_chunk = period_chunk,
    set_point_df = set_point_df_conv,
    parameters   = parameters
  )

  return(evaluation$reward)
}