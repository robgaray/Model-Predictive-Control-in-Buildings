# -------------------------------------------------------------
# Function: fitness_funct_optimize_mode.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function is the fitness function used by the Genetic Algorithm
# in optimize_modes(). It converts an integer mode vector (one mode index
# per market period) into a structured setpoint data frame, evaluates the
# building simulation, and returns the resulting scalar reward.
# -------------------------------------------------------------
# A candidate that cannot be evaluated
# A chromosome carrying NA is not a building operation: it cannot be
# turned into setpoints and there is nothing to simulate. It is scored
# with a penalty large enough to be worse than any reachable reward, so
# the optimizer discards it, instead of being allowed to stop the run
# inside convert_modes_to_setpoints(). The chromosome should never
# arrive in that state - optimize_modes() sizes the elitism so that
# ga() cannot build one - and this is the net under that.
# -------------------------------------------------------------
# Inputs
#   x            : Integer vector, one element per market period of the
#                  optimization horizon. Each element is a mode index
#                  (integer value from 1 to the number of modes)
#                  representing the active mode for that market period.
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
# -------------------------------------------------------------
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
# fitness <- fitness_funct_optimize_mode(x, timestamps, parameters, period_chunk,
#                                        simulation_control, marginal_context)
# -------------------------------------------------------------
# Where this function/script is used
#   - optimize_modes()
# -------------------------------------------------------------
# functions/scripts called
#   maxmode()                   - pairs the mode index vector with target_periods
#   convert_modes_to_setpoints() - maps mode selections to setpoint values
#                                  with hysteresis deadbands
#   evaluate_control()         - simulates the building and returns the scalar
#                                reward, or -1e9 when the chromosome
#                                carries NA and cannot be evaluated
# -------------------------------------------------------------
fitness_funct_optimize_mode <- function(x,
                                        timestamps,
                                        parameters,
                                        period_chunk,
                                        simulation_control,
                                        marginal_context = NULL
                                        ) {

  # 0. Refuse a chromosome that carries NA
  # -------------------------------------------------------------
  # The penalty is deliberately not a parameter: an unevaluable
  # candidate is not a preference the user can weigh. Its magnitude only
  # has to dominate any reachable reward, and the rewards of this model
  # are of the order of 1e3.
  # -------------------------------------------------------------
  {
    if (any(is.na(x))) {
      return(-1e9)
    }
  }

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
