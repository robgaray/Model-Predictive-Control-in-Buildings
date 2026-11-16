# -------------------------------------------------------------
# Function: resolve_flex_down_hvac.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Decides which of the two HVAC systems, heating or cooling, provides a
# downward flexibility window, so that the other one can be locked
# during the Recovery Phase (see build_hvac_lock_caps()).
# -------------------------------------------------------------
# Why the system is read and not chosen
# A downward window switches off whatever is running, so, unlike an
# upward window (see resolve_flex_up_hvac()), it does not need a
# system to be chosen before it is drawn. The system that provides it
# is simply the one that was running. The simulation keeps heating and
# cooling mutually exclusive at every timestep, but not over a whole
# window, and a long Commitment Phase can contain a change of system
# halfway through. The system with the larger planned heat over the
# Commitment Phase is then the one taken:
#
#   S_heat = sum of Q_heat_plan over the rows of phase 1
#   S_cool = sum of Q_cool_plan over the same rows
#
# When both are zero, nothing was flexed and no system is locked.
# -------------------------------------------------------------
# Inputs
#   period_chunk_subset : Data frame. The rows of the window, with the
#                         columns Q_heat_plan and Q_cool_plan (kWh per
#                         timestep) and Flex_phase_down_plan, the phase
#                         code of every row (1 Commitment, 2 Neutral,
#                         3 Recovery).
# -------------------------------------------------------------
# Outputs
#   Character scalar, one of:
#     "heat" - heating accumulates at least as much heat as cooling.
#     "cool" - cooling accumulates more heat.
#     "none" - neither system runs during the Commitment Phase.
# -------------------------------------------------------------
# Code outline
# 1. Accumulate the planned heat of each system over the Commitment
#    Phase
# 2. Take the larger one
# -------------------------------------------------------------
# Usage instructions
# hvac_used <- resolve_flex_down_hvac(period_chunk_subset)
# -------------------------------------------------------------
resolve_flex_down_hvac <- function(period_chunk_subset) {

  # -------------------------------------------------------------
  # 1. Accumulate the planned heat of each system over the Commitment
  #    Phase
  # -------------------------------------------------------------
  {
    event_rows_subset <- which(period_chunk_subset$Flex_phase_down_plan == 1L)

    S_heat_event <- sum(period_chunk_subset$Q_heat_plan[event_rows_subset])
    S_cool_event <- sum(period_chunk_subset$Q_cool_plan[event_rows_subset])
  }

  # -------------------------------------------------------------
  # 2. Take the larger one
  # A tie between two systems that both run goes to heating.
  # -------------------------------------------------------------
  {
    if (S_heat_event <= 0 && S_cool_event <= 0) {
      hvac_used <- "none"
    } else if (S_heat_event >= S_cool_event) {
      hvac_used <- "heat"
    } else {
      hvac_used <- "cool"
    }
  }

  return(hvac_used)
}
