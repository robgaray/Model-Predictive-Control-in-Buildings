# -------------------------------------------------------------
# Function: optimize_control_step.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Optimizes the control of one market over its optimization horizon
# and computes the expected building states under the result. The
# control is always mode-based:
#   1. optimize_modes() searches, with the genetic algorithm, the mode
#      of every market interval of the horizon, and returns the
#      corresponding setpoint schedule with its hysteresis deadbands.
#   2. evaluate_control() simulates the building under that schedule,
#      with the forecast weather, builds the two flexibility
#      itineraries and values the result with the reward.
# -------------------------------------------------------------
# Inputs
#   period_chunk       : Data frame. Working table over the optimization
#                        horizon, with every column period_calculation()
#                        and reward_function() read.
#   timestamps         : Named list. Must contain target_periods, the
#                        market intervals whose modes are optimized.
#   parameters         : Named list. Uses control, optimization and
#                        setpoint_modes, through the functions called.
#   simulation_control : Named list. Index metadata, passed through.
#   marginal_context   : Named list. As returned by
#                        resolve_marginal_context(), passed through.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     set_point_actual : Data frame. Optimized setpoint schedule per
#                        target period.
#     period_chunk     : Data frame. The working table with the plan
#                        and both flexibility itineraries of the
#                        optimized schedule, and the per-row Reward.
# -------------------------------------------------------------
# Code outline
# 1. Search the modes with the genetic algorithm
# 2. Evaluate the optimized schedule
# -------------------------------------------------------------
# Usage instructions
# result <- optimize_control_step(period_chunk, timestamps, parameters,
#                                 simulation_control, marginal_context)
# -------------------------------------------------------------
# Where this function/script is used
#   - run_market_process(): for the "energy" and "flexibility" aims.
# -------------------------------------------------------------
# functions/scripts called
#   - optimize_modes(): genetic algorithm over the mode of each interval
#   - evaluate_control(): simulation, flexibility itineraries and reward
# -------------------------------------------------------------

optimize_control_step <- function(period_chunk,
                                  timestamps,
                                  parameters,
                                  simulation_control,
                                  marginal_context
                                  ) {

  # -------------------------------------------------------------
  # 1. Search the modes with the genetic algorithm
  # -------------------------------------------------------------
  {
    # optimize_modes is called to search the mode of each target period
    # that maximizes the reward over the horizon.
    set_point_actual <- optimize_modes(period_chunk       = period_chunk,
                                       timestamps         = timestamps,
                                       parameters         = parameters,
                                       simulation_control = simulation_control,
                                       marginal_context   = marginal_context
                                       )
  }

  # -------------------------------------------------------------
  # 2. Evaluate the optimized schedule
  # -------------------------------------------------------------
  {
    # evaluate_control is called to simulate the building under the
    # optimized schedule and rebuild its itineraries and reward.
    period_chunk <- evaluate_control(period_chunk       = period_chunk,
                                     set_point_df       = set_point_actual,
                                     parameters         = parameters,
                                     simulation_control = simulation_control,
                                     marginal_context   = marginal_context
                                     )$period_chunk
  }

  return(list(
    set_point_actual = set_point_actual,
    period_chunk     = period_chunk
  ))
}
