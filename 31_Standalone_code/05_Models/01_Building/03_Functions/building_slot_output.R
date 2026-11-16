# -------------------------------------------------------------
# Function: building_slot_output.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation slot_output of the type of model Building: turns the
# table of a building back into its three itineraries, one value per
# market interval, from the interval that starts at i_begin_horizon
# to the closing interval, the one that starts at i_end_control.
# Each variable is aggregated by its own nature:
#   - Ti, Te    : state at the start of the interval, read on the
#                 row of that instant.
#   - setpoints : the value of the interval, read on its first time
#                 step.
#   - Elec_total: the sum of the time steps of the interval.
# The closing interval only carries the state (Ti, Te): it passes the
# state reached at i_end_control to the next market and commits no
# energy, so its other variables are missing (NA).
# -------------------------------------------------------------
# Inputs
#   asset_df : Data frame. The table of the building after the
#              market process.
#   slots    : Named list. The output intervals of the call:
#              - out_time: POSIXct vector, the start of each output
#                interval, the closing one included
#              - n_out: integer scalar, the length of out_time
#              - row_at_start: integer vector, the row of the table
#                at each instant of out_time
#              - first_row: integer vector, the first row of each
#                committed interval (every one but the closing one)
#              - slot_rows: integer vector, one value per row of the
#                table, the position of its interval among the
#                committed ones, and NA outside them
#   asset    : Named list. The parameters of the building. Not read.
# -------------------------------------------------------------
# Outputs
#   Named list with plan, plan_flex_down and plan_flex_up, each a
#   data frame with the columns:
#     - time
#     - Ti, Te
#     - STP_heat, STP_heat_low, STP_heat_high
#     - STP_cool, STP_cool_low, STP_cool_high
#     - Elec_total
# -------------------------------------------------------------
# Code outline
# 1. Itineraries
# -------------------------------------------------------------
# Usage instructions
# itineraries <- building_slot_output(asset_df, slots, asset)
# -------------------------------------------------------------

building_slot_output <- function(asset_df,
                                 slots,
                                 asset
                                 ) {

  # -------------------------------------------------------------
  # 1. Itineraries
  # -------------------------------------------------------------
  {
    committed        <- seq_len(slots$n_out - 1)
    setpoint_columns <- c("STP_heat", "STP_heat_low", "STP_heat_high",
                          "STP_cool", "STP_cool_low", "STP_cool_high")
    itineraries      <- list()

    for (CONT_001 in c("plan", "plan_flex_down", "plan_flex_up")) {
      itinerary    <- data.frame(time = slots$out_time)
      itinerary$Ti <- asset_df[[paste0("Ti_", CONT_001)]][slots$row_at_start]
      itinerary$Te <- asset_df[[paste0("Te_", CONT_001)]][slots$row_at_start]

      for (CONT_002 in setpoint_columns) {
        values            <- rep(NA_real_, slots$n_out)
        values[committed] <- asset_df[[paste0(CONT_002, "_", CONT_001)]][
          slots$first_row
        ]
        itinerary[[CONT_002]] <- values
      }

      # sum_over_slots is called to add up the electricity of the
      # steps of each committed interval.
      itinerary$Elec_total <- sum_over_slots(
        values = asset_df[[paste0("Elec_total_", CONT_001)]],
        slots  = slots
      )

      itineraries[[CONT_001]] <- itinerary
    }

    rm(list = c("CONT_001", "CONT_002", "itinerary", "values",
                "setpoint_columns", "committed"))
  }

  return(itineraries)
}
