# -------------------------------------------------------------
# Function: fitness_funct_optimize_mode.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function is the fitness function used by the Genetic Algorithm
# in optimize_modes(). It converts an integer mode vector (one mode index
# per market period) into a structured setpoint data frame, evaluates the
# building simulation, and returns the resulting scalar reward.
# -------------------------------------------------------------
# Inputs
#   x            : Integer vector of length n_periods. Each element is a
#                  mode index (integer value from 1 to n_modes) representing
#                  the active mode for that market period.
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
#   simulation_control : Named list. Simulation control object passed through
#                        to evaluate_control().
#   marginal_context   : Named list or NULL. Passed through to evaluate_control().
#
# Outputs
#   evaluation : Numeric scalar. Reward value extracted from evaluate_control()
#                return list for the given mode schedule. Higher is better.
# -------------------------------------------------------------
# Code outline
# 1. Create mode data frame from integer vector
# 2. Convert modes to setpoints
# 3. Evaluate control and compute reward
# -------------------------------------------------------------
# Usage instructions
# fitness <- fitness_funct_optimize_mode(x, n_modes, n_periods, timestamps, parameters, period_chunk)
# -------------------------------------------------------------
# Where this function/script is used
# Called by optimize_modes.R as the GA fitness function.
# -------------------------------------------------------------
# functions/scripts called
#   maxmode()                   - pairs the mode index vector with target_periods
#   convert_modes_to_setpoints() - maps mode selections to setpoint values
#                                  with hysteresis deadbands
#   evaluate_control()         - simulates the building and returns the scalar
#                                reward
# -------------------------------------------------------------
fitness_funct_optimize_mode <- function(x,
                                        n_modes,
                                        n_periods,
                                        timestamps,
                                        parameters,
                                        period_chunk,
                                        simulation_control,
                                        marginal_context = NULL) {

  # 1. Create mode data frame from integer vector
  # -------------------------------------------------------------
  # x is already an integer vector with one mode index per period
  # -------------------------------------------------------------
  {
    # maxmode is called to pair this GA candidate's per-period mode
    # indices with their corresponding target_periods timestamps, so
    # they can be converted to setpoints below.
    set_point_df_inner <- maxmode(
      x              = x,
      n_modes        = n_modes,
      n_periods      = n_periods,
      target_periods = timestamps$target_periods
    )
  }

  # 2. Convert modes to setpoints
  # -------------------------------------------------------------
  {
    # convert_modes_to_setpoints is called to translate this candidate's
    # mode-per-period schedule into the heating/cooling setpoint values
    # (with hysteresis deadbands) required by evaluate_control().
    set_point_df_conv <- convert_modes_to_setpoints(
      setpoint_modes_df = set_point_df_inner,
      setpoint_modes    = parameters$setpoint_modes,
      Deadband          = parameters$control$Deadband,
      target_periods    = timestamps$target_periods
    )
  }

  # 3. Evaluate control and compute reward
  # -------------------------------------------------------------
  {
    # evaluate_control is called to simulate the building over this
    # candidate's setpoint schedule and return the scalar reward that
    # the GA uses to rank this individual.
    evaluation <- evaluate_control(
      period_chunk       = period_chunk,
      set_point_df       = set_point_df_conv,
      parameters         = parameters,
      simulation_control = simulation_control,
      marginal_context   = marginal_context
    )
  }

  return(evaluation$reward)
}
