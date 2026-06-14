# -------------------------------------------------------------
# Function: fitness_funct_optimize_setpoint.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function is the fitness function used by the Genetic Algorithm
# in optimize_setpoints(). It converts a raw setpoint array produced
# by the GA into a structured setpoint data frame, evaluates the
# building simulation, and returns the resulting scalar reward.
# -------------------------------------------------------------
# Inputs
#   setpoint_array : Numeric vector. GA solution vector of length 2*horizon.
#                    The first 'horizon' elements are heating setpoints and
#                    the next 'horizon' elements are cooling setpoints.
#   period_chunk   : Data frame. Simulation data for the optimization
#                    horizon, as passed from optimize_setpoints().
#                    Must contain all columns required by
#                    period_calculation() (called inside evaluate_control()).
#   parameters     : Named list. Model and control parameters. Must contain:
#                      parameters$control$Deadband
#                    All other sub-elements required by evaluate_control().
#   timestamps     : Named list. Timestamp metadata. Must contain:
#                      timestamps$target_periods : POSIXct vector of market
#                                                  period timestamps.
#   simulation_control : Named list. Simulation control object passed through
#                        to evaluate_control().
#
# Outputs
#   evaluation : Numeric scalar. Reward value extracted from evaluate_control()
#                return list for the given setpoint schedule. Higher is better.
# -------------------------------------------------------------
# Code outline
# 1. Reshape chromosome into heating/cooling setpoint vectors
# 2. Convert setpoints to set_point_df
# 3. Evaluate control and compute reward
# -------------------------------------------------------------
# Usage instructions
# fitness <- fitness_funct_optimize_setpoint(x, period_chunk, timestamps, parameters)
# -------------------------------------------------------------
# Where this function/script is used
# Called by optimize_setpoints.R as the GA fitness function.
# -------------------------------------------------------------
# functions/scripts called
#   convert_setpoints() - converts raw setpoints to structured data frame with
#                         hysteresis deadbands
#   evaluate_control()  - simulates the building and returns the scalar reward
# -------------------------------------------------------------
fitness_funct_optimize_setpoint <- function(setpoint_array,
                                            period_chunk,
                                            parameters,
                                            timestamps,
                                            simulation_control) {
  horizon <- length(timestamps$target_periods)

  set_point_df <- convert_setpoints(
    setpoints_heating = setpoint_array[1:horizon],
    setpoints_cooling = setpoint_array[(horizon + 1):(2 * horizon)],
    Deadband          = parameters$control$Deadband,
    target_periods    = timestamps$target_periods
  )

  evaluation <- evaluate_control(
    period_chunk       = period_chunk,
    set_point_df       = set_point_df,
    parameters         = parameters,
    simulation_control = simulation_control
  )

  return(evaluation$reward)
}