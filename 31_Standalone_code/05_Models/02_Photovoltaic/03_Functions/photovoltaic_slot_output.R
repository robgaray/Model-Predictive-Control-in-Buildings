# -------------------------------------------------------------
# Function: photovoltaic_slot_output.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation slot_output of the type of model Photovoltaic: turns the
# table of a photovoltaic installation back into its three
# itineraries, one value per market interval, from the interval that
# starts at i_begin_horizon to the closing interval, the one that
# starts at i_end_control. Elec_PV and Elec_total are the sum of the
# time steps of the interval. The installation has no state, so the
# closing interval, which commits no energy, is missing (NA).
# -------------------------------------------------------------
# Inputs
#   asset_df : Data frame. The table of the installation after the
#              market process.
#   slots    : Named list. The output intervals of the call:
#              - out_time: POSIXct vector, the start of each output
#                interval, the closing one included
#              - n_out: integer scalar, the length of out_time
#              - slot_rows: integer vector, one value per row of the
#                table, the position of its interval among the
#                committed ones, and NA outside them
#   asset    : Named list. The parameters of the installation. Not
#              read.
# -------------------------------------------------------------
# Outputs
#   Named list with plan, plan_flex_down and plan_flex_up, each a
#   data frame with the columns time, Elec_PV and Elec_total.
# -------------------------------------------------------------
# Code outline
# 1. Itineraries
# -------------------------------------------------------------
# Usage instructions
# itineraries <- photovoltaic_slot_output(asset_df, slots, asset)
# -------------------------------------------------------------

photovoltaic_slot_output <- function(asset_df,
                                     slots,
                                     asset
                                     ) {

  # -------------------------------------------------------------
  # 1. Itineraries
  # -------------------------------------------------------------
  {
    itineraries <- list()

    for (CONT_001 in c("plan", "plan_flex_down", "plan_flex_up")) {
      itinerary <- data.frame(time = slots$out_time)

      for (CONT_002 in c("Elec_PV", "Elec_total")) {
        # sum_over_slots is called to add up the energy of the steps
        # of each committed interval.
        itinerary[[CONT_002]] <- sum_over_slots(
          values = asset_df[[paste0(CONT_002, "_", CONT_001)]],
          slots  = slots
        )
      }

      itineraries[[CONT_001]] <- itinerary
    }

    rm(list = c("CONT_001", "CONT_002", "itinerary"))
  }

  return(itineraries)
}
