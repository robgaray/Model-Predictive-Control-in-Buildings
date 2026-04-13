# -------------------------------------------------------------
# Function: optimize_control_step.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function performs the optimization of the control strategy
# for a single MPC step. It selects either setpoint-based or
# mode-based optimization depending on control_type, and then
# computes the forecasted building states resulting from the
# optimized setpoints.
# It performs the following steps:
#   1. Replaces actual weather data in period_chunk with forecast
#      values (Text_forec, SolarR_forec) so the optimizer works on
#      predicted conditions.
#   2. Calls optimize_setpoints() or optimize_modes() according to
#      control_type to find the optimal control schedule.
#   3. Converts the optimized schedule to a set_point_df with
#      histeresis deadbands.
#   4. Runs period_calculation() with the optimized setpoints and
#      forecasted weather to compute expected building states.
# -------------------------------------------------------------
# Inputs
#   period_chunk             : Data frame. Simulation data for the optimization
#                              horizon. Must contain 'Text_forec', 'SolarR_forec',
#                              'Text', 'SolarR', and all columns required by
#                              period_calculation().
#   target_periods           : POSIXct vector. Market period timestamps for the
#                              optimization horizon. Passed for interface
#                              compatibility; periods_target is derived
#                              internally from period_chunk$MarketUTC.
#   parameters               : List. Model parameters passed to period_calculation()
#                              and reward_function(). The following sub-elements
#                              are extracted internally:
#                                parameters$control$control_type
#                                parameters$control$set_point_range_heating
#                                parameters$control$set_point_range_cooling
#                                parameters$control$Deadband
#                                parameters$control$optimization_aim
#                                parameters$optimization
#                                parameters$setpoint_modes
#   i0                       : Integer or NULL. Current simulation step index,
#                              used only for verbose logging. Default: NULL.
#
# Outputs
#   A named list with two elements:
#     set_point_actual : Data frame. Optimized setpoint schedule with histeresis
#                        deadbands for the target periods, as returned by
#                        optimize_setpoints() or optimize_modes().
#     period_chunk     : Data frame. Expected building states under the optimized
#                        setpoints and forecasted weather, corresponding to the best
#                        flexibility scenario found (period_chunk from
#                        evaluate_control()). Contains all columns returned by
#                        period_calculation() plus *_plan and *_plan_flex columns:
#                        Ti_plan, Te_plan,
#                        STP_heat_low_plan, STP_heat_high_plan,
#                        STP_cool_low_plan, STP_cool_high_plan,
#                        Act_heat_plan, Act_cool_plan, Q_heat_plan, Q_cool_plan,
#                        Elec_heat_plan, Elec_cool_plan, Elec_total_plan;
#                        and the following *_flex columns representing the best
#                        flexibility scenario (Q=0 over the optimal window):
#                        Ti_plan_flex, Te_plan_flex,
#                        STP_heat_low_plan_flex, STP_heat_high_plan_flex,
#                        STP_cool_low_plan_flex, STP_cool_high_plan_flex,
#                        Act_heat_plan_flex, Act_cool_plan_flex,
#                        Q_heat_plan_flex, Q_cool_plan_flex,
#                        Elec_heat_plan_flex, Elec_cool_plan_flex,
#                        Elec_total_plan_flex, Elec_flex_plan,
#                        Elec_flex_com_revenue_plan, Elec_flex_exec_revenue_plan,
#                        Elec_flex_revenue_plan.
# -------------------------------------------------------------
# Code outline
# 1. Determine control type (setpoint or modes)
# 2. Dispatch to appropriate optimizer
# 3. Return optimized period_chunk and set_point_df
# -------------------------------------------------------------
# Usage instructions
# result <- optimize_control_step(period_chunk, timestamps, parameters, indexes)
# -------------------------------------------------------------
# Where this function/script is used
# Called by simulation.R in the optimization phase (step 3) of the MPC loop.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If control_type is neither "setpoint" nor "modes", the function
#     raises an error via stop().
#   - The function temporarily overwrites period_chunk$Text and
#     period_chunk$SolarR with forecast values before optimization;
#     the original period_chunk in the calling environment is not modified.
#   - Parallelization is initialized inside optimize_setpoints() and
#     optimize_modes(); the cluster is stopped within those functions.
# -------------------------------------------------------------
# functions/scripts called
#   optimize_setpoints() - GA optimization for real-valued setpoints
#   optimize_modes()     - GA optimization for binary-encoded modes
#   evaluate_control()   - building simulation, flexibility evaluation, reward
# -------------------------------------------------------------
optimize_control_step <- function(period_chunk,
                                  timestamps,
                                  parameters,
                                  indexes) {
  
  # Optimization
  if (parameters$control$control_type == "setpoint") {
    set_point_actual <- optimize_setpoints(period_chunk,
                                           timestamps,
                                           parameters,
                                           indexes
                                           )
  } else if (parameters$control$control_type == "modes") {
    set_point_actual <- optimize_modes(period_chunk,
                                       timestamps,
                                       parameters,
                                       indexes
                                       )
  } else {
    stop("Invalid control_type. Use 'setpoint' or 'modes'.")
  }
  
  # Calculation of forecast states (with optimized setpoints)
  period_chunk <- evaluate_control(period_chunk = period_chunk,
                                   set_point_df = set_point_actual,
                                   parameters   = parameters)$period_chunk

  if (parameters$debug_and_config$verbose) {
    cat("\n")
    cat("======================================\n")
    cat("Control optimization completed\n")
    cat("Simulation timestep:"  , indexes$i0, "\n")
    cat("Step initiation:"      , format(period_chunk$time[1]), "\n")
    cat("Step end:"             , format(period_chunk$time[nrow(period_chunk)]), "\n")
    cat("======================================\n")
  }
  
  return(list(
    set_point_actual = set_point_actual,
    period_chunk     = period_chunk
  ))
}
