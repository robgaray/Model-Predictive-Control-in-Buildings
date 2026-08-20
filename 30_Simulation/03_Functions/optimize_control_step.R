# -------------------------------------------------------------
# Function: optimize_control_step.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function performs the optimization of the control strategy
# for a single MPC step. It selects either setpoint-based or
# mode-based optimization depending on control_type, and then
# computes the forecasted building states resulting from the
# optimized setpoints.
# It performs the following steps:
#   1. Calls optimize_setpoints() or optimize_modes() according to
#      control_type to find the optimal control schedule (each of
#      these already returns a set_point_df with hysteresis
#      deadbands, built internally via convert_setpoints()).
#   2. Calls evaluate_control() with the optimized setpoints to
#      compute the expected building states under forecasted
#      weather (period_calculation() internally reads
#      Text_forec/SolarR_forec instead of Text/SolarR for the
#      "plan"/"plan_flex" calculation contexts; period_chunk$Text/
#      SolarR are not overwritten).
# -------------------------------------------------------------
# Inputs
#   period_chunk             : Data frame. Simulation data for the optimization
#                              horizon. Must contain 'Text_forec', 'SolarR_forec',
#                              'Text', 'SolarR', and all columns required by
#                              period_calculation().
#   timestamps               : Named list. Timestamp metadata, passed through
#                              to optimize_setpoints()/optimize_modes() and to
#                              evaluate_control(). Must contain
#                              timestamps$target_periods (POSIXct vector of
#                              market period timestamps for the optimization
#                              horizon).
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
#   simulation_control        : Named list. Index/step metadata, passed
#                              through to optimize_setpoints()/optimize_modes()
#                              and evaluate_control() for interface consistency.
#   marginal_context          : Named list or NULL (default NULL). Passed
#                              through to optimize_setpoints()/optimize_modes()
#                              and to the final evaluate_control() call.
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
#                        Elec_flex_revenue_plan (reward_function()'s own
#                        internal/transient column, see that function's
#                        header - unrelated to any persisted Main_df column).
# -------------------------------------------------------------
# Code outline
# 1. Dispatch to optimize_setpoints() or optimize_modes() according
#    to control_type
# 2. Run evaluate_control() with the optimized setpoints and
#    forecasted weather to compute expected building states
# 3. Return the optimized set_point_actual and period_chunk
# -------------------------------------------------------------
# Usage instructions
# result <- optimize_control_step(period_chunk, timestamps, parameters, simulation_control)
# -------------------------------------------------------------
# Where this function/script is used
# Called by run_market_process.R (which is itself called by simulation.R
# in the optimization phase of the MPC loop).
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If control_type is neither "setpoints" nor "modes", the function
#     raises an error via stop().
#   - Parallelization is initialized inside optimize_setpoints() and
#     optimize_modes(); the cluster is stopped within those functions.
# -------------------------------------------------------------
# functions/scripts called
#   optimize_setpoints() - GA optimization for real-valued setpoints
#   optimize_modes()     - GA optimization for integer mode indices with
#                          custom population, crossover, and mutation operators
#   evaluate_control()   - building simulation, flexibility evaluation, reward
# -------------------------------------------------------------
optimize_control_step <- function(period_chunk,
                                  timestamps,
                                  parameters,
                                  simulation_control,
                                  marginal_context = NULL) {

  # Optimization
  if (parameters$control$control_type == "setpoints") {
    # optimize_setpoints is called to run the GA search over real-valued
    # heating/cooling setpoints for the horizon, since control_type
    # selects the setpoint-based control strategy.
    set_point_actual <- optimize_setpoints(period_chunk       = period_chunk,
                                           timestamps         = timestamps,
                                           parameters         = parameters,
                                           simulation_control = simulation_control,
                                           marginal_context   = marginal_context
                                           )
  } else if (parameters$control$control_type == "modes") {
    # optimize_modes is called instead to run the GA search over the
    # discrete control modes defined in parameters$setpoint_modes, since
    # control_type selects the mode-based control strategy.
    set_point_actual <- optimize_modes(period_chunk       = period_chunk,
                                       timestamps         = timestamps,
                                       parameters         = parameters,
                                       simulation_control = simulation_control,
                                       marginal_context   = marginal_context
                                       )
  } else {
    stop("Invalid control_type. Use 'setpoints' or 'modes'.")
  }

  # Calculation of forecast states (with optimized setpoints)
  period_chunk <- evaluate_control(period_chunk       = period_chunk,
                                   set_point_df       = set_point_actual,
                                   parameters         = parameters,
                                   simulation_control = simulation_control,
                                   marginal_context   = marginal_context)$period_chunk

  return(list(
    set_point_actual = set_point_actual,
    period_chunk     = period_chunk
  ))
}
