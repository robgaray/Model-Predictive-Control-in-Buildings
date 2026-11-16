# -------------------------------------------------------------
# Function: battery_slot_output.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation slot_output of the type of model Battery: turns the table
# of a battery back into its three itineraries, one value per market
# interval, from the interval that starts at i_begin_horizon to the
# closing interval, the one that starts at i_end_control. For each
# itinerary:
#   - Stored_energy: the energy stored at the start of each interval.
#   - Mode: the mode of the first step of the interval.
#   - Elec_charge, Elec_discharge and Elec_total: the sum of the time
#     steps of the interval.
# The closing interval commits no energy, so it only holds the
# stored energy at its start, the state from which the next call
# starts; its other values are missing (NA).
# -------------------------------------------------------------
# Inputs
#   asset_df : Data frame. The table of the battery after the market
#              process.
#   slots    : Named list. The output intervals of the call:
#              - out_time: POSIXct vector, the start of each output
#                interval, the closing one included
#              - n_out: integer scalar, the length of out_time
#              - row_at_start: integer vector, the row of the start
#                of each output interval
#              - first_row: integer vector, the first row of each
#                committed interval
#              - slot_rows: integer vector, one value per row of the
#                table, the position of its interval among the
#                committed ones, and NA outside them
#   asset    : Named list. The parameters of the battery. Not read.
# -------------------------------------------------------------
# Outputs
#   Named list with plan, plan_flex_down and plan_flex_up, each a
#   data frame with the columns time, Mode, Stored_energy,
#   Elec_charge, Elec_discharge and Elec_total.
# -------------------------------------------------------------
# Code outline
# 1. Itineraries
# -------------------------------------------------------------
# Usage instructions
# itineraries <- battery_slot_output(asset_df, slots, asset)
# -------------------------------------------------------------

battery_slot_output <- function(asset_df,
                                slots,
                                asset
                                ) {

  # -------------------------------------------------------------
  # 1. Itineraries
  # -------------------------------------------------------------
  {
    committed   <- seq_len(slots$n_out - 1)
    itineraries <- list()

    for (CONT_001 in c("plan", "plan_flex_down", "plan_flex_up")) {
      itinerary <- data.frame(time = slots$out_time)

      mode            <- rep(NA_integer_, slots$n_out)
      mode[committed] <- asset_df[[paste0("Mode_", CONT_001)]][
        slots$first_row
      ]
      itinerary$Mode          <- mode
      itinerary$Stored_energy <- asset_df[[paste0("Stored_energy_",
                                                  CONT_001)]][
        slots$row_at_start
      ]

      for (CONT_002 in c("Elec_charge", "Elec_discharge", "Elec_total")) {
        # sum_over_slots is called to add up the energy of the steps
        # of each committed interval.
        itinerary[[CONT_002]] <- sum_over_slots(
          values = asset_df[[paste0(CONT_002, "_", CONT_001)]],
          slots  = slots
        )
      }

      itineraries[[CONT_001]] <- itinerary
    }

    rm(list = c("CONT_001", "CONT_002", "itinerary", "mode", "committed"))
  }

  return(itineraries)
}
