# -------------------------------------------------------------
# Function: battery_spread_input.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation spread_input of the type of model Battery: turns the
# block of a battery in the input of a call, given per market
# interval, into its table on the internal time steps of the call.
# For each itinerary:
#   - Mode: the mode of the interval, on every step of the interval.
#     A missing mode stays missing: the market process gives it the
#     default control of the battery, the stop mode.
#   - Stored_energy: the energy stored at the start of each interval,
#     on the row of that instant. Until the battery is simulated, the
#     other rows hold the last energy given before them, so that the
#     energy of every row is known whenever the reward values it. A
#     flexibility itinerary that gives no energy at i0 starts from
#     the energy of the plan at i0, as the market process starts it.
#   - Elec_charge, Elec_discharge and Elec_total: the energy of the
#     interval, divided evenly between the steps of the interval.
#     They are computed again when the battery is simulated, so the
#     values of the input only set the starting point.
#   - Elec_rest: 0. The net electricity of the rest of the system is
#     written by the system before the battery is simulated.
# -------------------------------------------------------------
# Inputs
#   asset_input : Named list. The block of the battery in the input
#                 of the call, with itineraries: a list with plan,
#                 plan_flex_down and plan_flex_up, each a data frame
#                 with time, Mode, Stored_energy, Elec_charge,
#                 Elec_discharge and Elec_total, one row per market
#                 interval.
#   grid        : Named list. The time grid of the call:
#                 - time: POSIXct vector, one value per internal step
#                 - slot_of_row: integer vector, the position in the
#                   input of the interval of each row
#                 - row_at_slot_start: integer vector, the row of the
#                   start of each interval of the input
#                 - steps_per_slot: numeric scalar, the number of
#                   internal steps of a market interval
#   asset       : Named list. The parameters of the battery. Not
#                 read.
# -------------------------------------------------------------
# Outputs
#   Data frame, the table of the battery, one row per internal step,
#   with the columns time and, for each itinerary (plan,
#   plan_flex_down, plan_flex_up), Mode, Stored_energy, Elec_rest,
#   Elec_charge, Elec_discharge and Elec_total with the suffix of the
#   itinerary.
# -------------------------------------------------------------
# Code outline
# 1. Mode and stored energy of each itinerary
#    1.1. Energy of the rows between the starts of the intervals
# 2. Energy columns of each itinerary
# -------------------------------------------------------------
# Usage instructions
# asset_df <- battery_spread_input(
#   asset_input = checked$assets[["Battery_001"]],
#   grid        = grid,
#   asset       = parameters$assets[["Battery_001"]]
# )
# -------------------------------------------------------------

battery_spread_input <- function(asset_input,
                                 grid,
                                 asset
                                 ) {

  # -------------------------------------------------------------
  # 1. Mode and stored energy of each itinerary
  # -------------------------------------------------------------
  {
    asset_df <- data.frame(time = grid$time)

    for (CONT_001 in c("plan", "plan_flex_down", "plan_flex_up")) {
      itinerary <- asset_input$itineraries[[CONT_001]]

      asset_df[[paste0("Mode_", CONT_001)]] <- as.integer(
        itinerary$Mode[grid$slot_of_row]
      )

      stored <- rep(NA_real_, nrow(asset_df))
      stored[grid$row_at_slot_start] <- itinerary$Stored_energy
      asset_df[[paste0("Stored_energy_", CONT_001)]] <- stored
    }

    rm(list = c("CONT_001", "itinerary", "stored"))

    # -------------------------------------------------------------
    # 1.1. Energy of the rows between the starts of the intervals
    # Each missing row takes the energy of the row before it. The
    # flexibility itineraries take, at i0, the energy of the plan
    # when the input gives none.
    # -------------------------------------------------------------
    {
      for (CONT_002 in c("plan", "plan_flex_down", "plan_flex_up")) {
        column <- paste0("Stored_energy_", CONT_002)
        stored <- asset_df[[column]]
        if (is.na(stored[1])) {
          stored[1] <- asset_df$Stored_energy_plan[1]
        }
        for (CONT_003 in seq_along(stored)[-1]) {
          if (is.na(stored[CONT_003])) {
            stored[CONT_003] <- stored[CONT_003 - 1]
          }
        }
        asset_df[[column]] <- stored
      }

      rm(list = c("CONT_002", "CONT_003", "column", "stored"))
    }
  }

  # -------------------------------------------------------------
  # 2. Energy columns of each itinerary
  # -------------------------------------------------------------
  {
    for (CONT_004 in c("plan", "plan_flex_down", "plan_flex_up")) {
      itinerary <- asset_input$itineraries[[CONT_004]]

      asset_df[[paste0("Elec_rest_", CONT_004)]] <- 0

      for (CONT_005 in c("Elec_charge", "Elec_discharge", "Elec_total")) {
        # spread_slot_energy is called to divide the energy of each
        # interval evenly between its internal steps.
        asset_df[[paste0(CONT_005, "_", CONT_004)]] <- spread_slot_energy(
          slot_energy = itinerary[[CONT_005]],
          grid        = grid
        )
      }
    }

    rm(list = c("CONT_004", "CONT_005", "itinerary"))
  }

  return(asset_df)
}
