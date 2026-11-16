# -------------------------------------------------------------
# Function: building_tail_state.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads the state a flexibility window left in the itinerary of its
# leg at the start of the optimization horizon, and the system of the
# building that provides the window. The optimization continues the
# tail of the window from that state, with that system. It is the
# operation tail_state of the type Building (see
# model_type_contract()).
# -------------------------------------------------------------
# The state and the system
# The state of a building is its two temperatures and what its two
# systems do: Ti, Te, Act_heat, Act_cool, Thermostat_heat,
# Thermostat_cool, Q_heat and Q_cool of the itinerary of the leg, at
# the row where the horizon starts. The thermostats carry the state
# the hysteresis goes on from, also when the heat of that row was
# imposed (Act_heat or Act_cool 2).
# The Commitment Phase of the window is the last stretch of phase 1
# that starts before the horizon. The system is the one the building
# takes over that stretch when it contributes to a window
# (flex_evaluation()):
#   - downward, the one with the larger heat in the plan;
#   - upward, the one the window raises above the plan.
# It is "none" when the window has no Commitment Phase before the
# horizon or neither system works over it.
# -------------------------------------------------------------
# Inputs
#   stretch_chunk   : Data frame. The view of the building of the
#                     simulated stretch, from its first
#                     row to the end of the tail, with the flexibility
#                     itineraries projected over it and the phases of
#                     the leg in Flex_phase_<leg>_plan.
#   i_begin_horizon : Integer. Row of the stretch where the optimization
#                     horizon starts.
#   leg             : Character scalar, "down" or "up".
#   asset           : Named list. The parameters of the building, its
#                     entry of parameters$assets. Every operation of the
#                     type of model receives them (model_type_contract());
#                     the state of a building's tail is read from the
#                     stretch alone, so none of them is read here.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     state  : One-row data frame. Ti, Te, Act_heat, Act_cool,
#              Thermostat_heat, Thermostat_cool, Q_heat and Q_cool of
#              the itinerary of the leg at i_begin_horizon, named with
#              their itinerary suffix.
#     system : Character scalar, "heat", "cool" or "none".
# -------------------------------------------------------------
# Code outline
# 1. State at i_begin_horizon
# 2. System of the window
# -------------------------------------------------------------
# Usage instructions
# tail_state <- building_tail_state(stretch_chunk, i_begin_horizon, "down",
#                                   asset)
# -------------------------------------------------------------

building_tail_state <- function(stretch_chunk,
                                i_begin_horizon,
                                leg,
                                asset
                                ) {

  # -------------------------------------------------------------
  # 1. State at i_begin_horizon
  # -------------------------------------------------------------
  {
    state_columns <- paste0(c("Ti", "Te", "Act_heat", "Act_cool",
                              "Thermostat_heat", "Thermostat_cool",
                              "Q_heat", "Q_cool"),
                            "_plan_flex_", leg)
    state <- stretch_chunk[i_begin_horizon, state_columns, drop = FALSE]
    rownames(state) <- NULL
    rm(list = "state_columns")
  }

  # -------------------------------------------------------------
  # 2. System of the window
  # -------------------------------------------------------------
  {
    phase_column  <- paste0("Flex_phase_", leg, "_plan")
    in_commitment <- stretch_chunk[[phase_column]] == 1L
    starts        <- which(in_commitment &
                             c(TRUE, !in_commitment[-length(in_commitment)]))
    starts        <- starts[starts < i_begin_horizon]

    system <- "none"
    if (length(starts) > 0) {
      commitment_end <- max(starts)
      while (commitment_end < length(in_commitment) &&
             in_commitment[commitment_end + 1]) {
        commitment_end <- commitment_end + 1
      }
      commitment_rows <- max(starts):commitment_end

      if (leg == "down") {
        S_heat <- sum(stretch_chunk$Q_heat_plan[commitment_rows],
                      na.rm = TRUE)
        S_cool <- sum(stretch_chunk$Q_cool_plan[commitment_rows],
                      na.rm = TRUE)
      } else {
        S_heat <- sum(pmax(stretch_chunk$Q_heat_plan_flex_up -
                             stretch_chunk$Q_heat_plan, 0)[commitment_rows],
                      na.rm = TRUE)
        S_cool <- sum(pmax(stretch_chunk$Q_cool_plan_flex_up -
                             stretch_chunk$Q_cool_plan, 0)[commitment_rows],
                      na.rm = TRUE)
      }

      if (S_heat > 0 || S_cool > 0) {
        system <- if (S_heat >= S_cool) "heat" else "cool"
      }
      rm(list = c("commitment_end", "commitment_rows", "S_heat", "S_cool"))
    }

    rm(list = c("phase_column", "in_commitment", "starts"))
  }

  return(list(state = state, system = system))
}
