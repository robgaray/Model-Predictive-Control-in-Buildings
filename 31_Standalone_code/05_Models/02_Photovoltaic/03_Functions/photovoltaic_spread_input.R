# -------------------------------------------------------------
# Function: photovoltaic_spread_input.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation spread_input of the type of model Photovoltaic: turns the
# block of a photovoltaic installation in the input of a call, given
# per market interval, into its table on the internal time steps of
# the call. The installation has no occupancy, no climate season and
# no state: its table holds, for each itinerary, the electricity it
# produces (Elec_PV) and its electricity for the system
# (Elec_total, minus the production). Both are energies of the
# interval, divided evenly between the steps of the interval. The
# radiation on its modules (G_poa) and the temperature of its cells
# (T_cell) start at 0. The production is computed again from the
# weather when the plan is simulated, so the values of the input
# only set the starting point.
# Every itinerary of the input holds every column, with NA where the
# call gave no value.
# -------------------------------------------------------------
# Inputs
#   asset_input : Named list. The block of the installation in the
#                 input of the call, with itineraries: a list with
#                 plan, plan_flex_down and plan_flex_up, each a data
#                 frame with time, Elec_PV and Elec_total, one row
#                 per market interval.
#   grid        : Named list. The time grid of the call:
#                 - time: POSIXct vector, one value per internal step
#                 - slot_of_row: integer vector, the position in the
#                   input of the interval of each row
#                 - steps_per_slot: numeric scalar, the number of
#                   internal steps of a market interval
#   asset       : Named list. The parameters of the installation.
#                 Not read.
# -------------------------------------------------------------
# Outputs
#   Data frame, the table of the installation, one row per internal
#   step, with the columns time and, for each itinerary (plan,
#   plan_flex_down, plan_flex_up), Elec_PV, Elec_total, G_poa and
#   T_cell with the suffix of the itinerary.
# -------------------------------------------------------------
# Code outline
# 1. Energy columns of each itinerary
# 2. Radiation and cell temperature columns
# -------------------------------------------------------------
# Usage instructions
# asset_df <- photovoltaic_spread_input(
#   asset_input = checked$assets[["Photovoltaic_001"]],
#   grid        = grid,
#   asset       = parameters$assets[["Photovoltaic_001"]]
# )
# -------------------------------------------------------------

photovoltaic_spread_input <- function(asset_input,
                                      grid,
                                      asset
                                      ) {

  # -------------------------------------------------------------
  # 1. Energy columns of each itinerary
  # -------------------------------------------------------------
  {
    asset_df <- data.frame(time = grid$time)

    for (CONT_001 in c("plan", "plan_flex_down", "plan_flex_up")) {
      itinerary <- asset_input$itineraries[[CONT_001]]

      for (CONT_002 in c("Elec_PV", "Elec_total")) {
        # spread_slot_energy is called to divide the energy of each
        # interval evenly between its internal steps.
        asset_df[[paste0(CONT_002, "_", CONT_001)]] <- spread_slot_energy(
          slot_energy = itinerary[[CONT_002]],
          grid        = grid
        )
      }
    }

    rm(list = c("CONT_001", "CONT_002", "itinerary"))
  }

  # -------------------------------------------------------------
  # 2. Radiation and cell temperature columns
  # The model writes them when it simulates the plan, so they start
  # at 0.
  # -------------------------------------------------------------
  {
    for (CONT_003 in c("plan", "plan_flex_down", "plan_flex_up")) {
      asset_df[[paste0("G_poa_", CONT_003)]]  <- 0
      asset_df[[paste0("T_cell_", CONT_003)]] <- 0
    }

    rm(list = "CONT_003")
  }

  return(asset_df)
}
