# -------------------------------------------------------------
# Function: load_flexibility_event_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Structures the parameters that define a flexibility event, as read
# and validated from 08_Flexibility_Event_Configuration.csv:
#   - the phases of the event
#   - the convergence of its Recovery Phase
#   - the system that renders an upward event
#   - the feasibility of a window
#   - the tolerances and margin of the commitment
# flex_up_max_power_heating is kept as text; every other value is
# converted to a number.
# -------------------------------------------------------------
# Inputs
#   values : Named list. Raw parameter/value pairs of
#            08_Flexibility_Event_Configuration.csv:
#              - commitment_phase_length_max : maximum duration of
#                the Commitment Phase [h]
#              - neutral_phase_timespan : duration of the Neutral
#                Phase [h]
#              - recovery_phase_timespan : duration of the Recovery
#                Phase [h]
#              - minimum_flexibility : smallest flexibility worth
#                committing [kW]
#              - recovery_convergence_window : window at the end of
#                the control horizon over which the convergence of
#                the Recovery Phase is measured [min]
#              - recovery_convergence_tol_rel : relative tolerance of
#                that check [%]
#              - recovery_convergence_tol_abs : absolute tolerance of
#                that check [kW]
#              - flex_up_horizon_long : long horizon over which the
#                system of an upward event is chosen [h]
#              - flex_up_horizon_short : short horizon of the same
#                choice [h]
#              - flex_up_dominance_threshold : share a system must
#                dominate by to render an upward event [%]
#              - flex_up_max_power_heating : rated power an upward
#                heating event may reach, Q_hp_heat_1 or Q_hp_heat_2
#                (text)
#              - flex_feasibility_tolerance : share of the dominant
#                increment below which the other system does not
#                count as a decision [%]
#              - flex_feasibility_floor : increment below which
#                neither system counts as a decision [kWh]
#              - flex_restatement_tol : energy a re-stated standing
#                commitment may miss its target by [kWh]
#              - flexibility_commitment_margin : electrical headroom
#                every market slot of a window keeps against the
#                limit of its system [kW]
# -------------------------------------------------------------
# Outputs
#   Named list with the same fifteen elements.
# -------------------------------------------------------------
# Code outline
# 1. Keep flex_up_max_power_heating as text and convert the rest to
#    numbers.
# -------------------------------------------------------------
# Usage instructions
# flexibility_events <- load_flexibility_event_parameters(raw_values)
# -------------------------------------------------------------
# Where this function/script is used
# Called by load_08_flexibility_event_configuration.R.
# -------------------------------------------------------------
# functions/scripts called
# None.
# -------------------------------------------------------------

load_flexibility_event_parameters <- function(values) {

  # -------------------------------------------------------------
  # 1. Keep flex_up_max_power_heating as text and convert the rest
  # to numbers
  # -------------------------------------------------------------
  {
    flexibility_events <- list(
      commitment_phase_length_max   = as.numeric(values$commitment_phase_length_max),
      neutral_phase_timespan        = as.numeric(values$neutral_phase_timespan),
      recovery_phase_timespan       = as.numeric(values$recovery_phase_timespan),
      minimum_flexibility           = as.numeric(values$minimum_flexibility),
      recovery_convergence_window   = as.numeric(values$recovery_convergence_window),
      recovery_convergence_tol_rel  = as.numeric(values$recovery_convergence_tol_rel),
      recovery_convergence_tol_abs  = as.numeric(values$recovery_convergence_tol_abs),
      flex_up_horizon_long          = as.numeric(values$flex_up_horizon_long),
      flex_up_horizon_short         = as.numeric(values$flex_up_horizon_short),
      flex_up_dominance_threshold   = as.numeric(values$flex_up_dominance_threshold),
      flex_up_max_power_heating     = trimws(as.character(values$flex_up_max_power_heating)),
      flex_feasibility_tolerance    = as.numeric(values$flex_feasibility_tolerance),
      flex_feasibility_floor        = as.numeric(values$flex_feasibility_floor),
      flex_restatement_tol          = as.numeric(values$flex_restatement_tol),
      flexibility_commitment_margin = as.numeric(values$flexibility_commitment_margin)
    )
  }

  return(flexibility_events)
}
