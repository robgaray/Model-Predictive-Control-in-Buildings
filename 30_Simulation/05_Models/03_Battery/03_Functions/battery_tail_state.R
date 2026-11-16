# -------------------------------------------------------------
# Function: battery_tail_state.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads the state a flexibility window left in the itinerary of a
# leg of a battery at the start of the optimization horizon. The
# optimization continues the tail of the window from that state
# (battery_continue_window_tail()). It is the operation tail_state of
# the type of model Battery (model_type_contract()).
# The state of a battery is the energy it stores. A battery has no
# system to choose, so it gives none, and the tail of the window
# holds no entry of the system for it.
# -------------------------------------------------------------
# Inputs
#   stretch_chunk   : Data frame. The view of the battery of the
#                     simulated stretch, from its first row to the end
#                     of the tail, with the flexibility itineraries
#                     projected over it. Reads
#                     Stored_energy_plan_flex_<leg>.
#   i_begin_horizon : Integer. Row of the stretch where the
#                     optimization horizon starts.
#   leg             : Character scalar, "down" or "up".
#   asset           : Named list. The parameters of the battery, its
#                     entry of parameters$assets. Every operation of
#                     the type of model receives them; the state is
#                     read from the stretch alone, so none of them is
#                     read here.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     state  : One-row data frame with the column
#              Stored_energy_plan_flex_<leg>, the energy the leg
#              stores at i_begin_horizon (kWh).
#     system : NULL.
# -------------------------------------------------------------
# Code outline
# 1. State at i_begin_horizon
# -------------------------------------------------------------
# Usage instructions
# tail_state <- battery_tail_state(stretch_chunk, i_begin_horizon,
#                                  "down", asset)
# -------------------------------------------------------------

battery_tail_state <- function(stretch_chunk,
                               i_begin_horizon,
                               leg,
                               asset
                               ) {

  # -------------------------------------------------------------
  # 1. State at i_begin_horizon
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("battery_tail_state: leg must be \"down\" or \"up\"")
    }
    if (!is.numeric(i_begin_horizon) || length(i_begin_horizon) != 1 ||
        i_begin_horizon < 1 || i_begin_horizon > nrow(stretch_chunk)) {
      stop("battery_tail_state: i_begin_horizon must be a row of the ",
           "stretch (", asset$asset_id, ")")
    }

    state_column <- paste0("Stored_energy_plan_flex_", leg)
    state <- stretch_chunk[i_begin_horizon, state_column, drop = FALSE]
    rownames(state) <- NULL
    rm(list = "state_column")
  }

  return(list(state = state, system = NULL))
}
