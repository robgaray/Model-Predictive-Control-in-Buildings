# -------------------------------------------------------------
# Function: battery_check_input.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation check_input of the type of model Battery: checks the
# block of a battery in the input of a call, beyond the general
# rules every block meets (the interval grid, the type and the range
# of each vector). The call stops if:
#   - Stored_energy is missing at i0 in the plan itinerary: the plan
#     of a battery starts from the energy it stores at i0
#   - a value of Stored_energy, in any itinerary, is above the
#     capacity of the battery (Capacity, in its parameter file)
#   - a value of Mode, in any itinerary, is not the code of one of
#     the modes of battery_modes(). A missing mode is allowed: it is
#     a market interval that no market has decided yet.
# -------------------------------------------------------------
# Inputs
#   asset_input : Named list. The block of the battery in the input
#                 of the call, with the data frames of its
#                 itineraries, whose first row is the interval that
#                 starts at i0.
#   parameters  : Named list. The parameters of the system. Not read.
#   asset       : Named list. The parameters of the battery, its
#                 entry of parameters$assets. Uses asset_id, to name
#                 the battery in the messages, and battery$Capacity.
# -------------------------------------------------------------
# Outputs
#   The block of the battery, as it comes. The call stops if the
#   block is invalid.
# -------------------------------------------------------------
# Code outline
# 1. Stored energy at i0
# 2. Stored energy within the capacity
# 3. Modes
# -------------------------------------------------------------
# Usage instructions
# asset_input <- battery_check_input(
#   asset_input = asset_input,
#   parameters  = parameters,
#   asset       = parameters$assets[["Battery_001"]]
# )
# -------------------------------------------------------------

battery_check_input <- function(asset_input,
                                parameters,
                                asset
                                ) {

  # -------------------------------------------------------------
  # 1. Stored energy at i0
  # -------------------------------------------------------------
  {
    plan <- asset_input$itineraries$plan
    if (is.null(plan) || length(plan$Stored_energy) == 0 ||
        is.na(plan$Stored_energy[1])) {
      stop(asset$asset_id, ": the plan itinerary must give Stored_energy ",
           "at i0 (its first interval)")
    }
    rm(list = "plan")
  }

  # -------------------------------------------------------------
  # 2. Stored energy within the capacity
  # -------------------------------------------------------------
  {
    capacity <- asset$battery$Capacity
    for (CONT_001 in names(asset_input$itineraries)) {
      stored <- asset_input$itineraries[[CONT_001]]$Stored_energy
      if (any(stored > capacity, na.rm = TRUE)) {
        stop(asset$asset_id, ": Stored_energy of the itinerary ", CONT_001,
             " is above the capacity of the battery (", capacity, " kWh)")
      }
    }
    rm(list = c("CONT_001", "stored", "capacity"))
  }

  # -------------------------------------------------------------
  # 3. Modes
  # -------------------------------------------------------------
  {
    # battery_modes is called to get the codes of the modes.
    codes <- battery_modes()
    for (CONT_002 in names(asset_input$itineraries)) {
      mode <- asset_input$itineraries[[CONT_002]]$Mode
      if (any(!is.na(mode) & !(mode %in% codes))) {
        stop(asset$asset_id, ": Mode of the itinerary ", CONT_002,
             " must be one of the codes ", paste(codes, collapse = ", "),
             ", or missing")
      }
    }
    rm(list = c("CONT_002", "mode", "codes"))
  }

  return(asset_input)
}
