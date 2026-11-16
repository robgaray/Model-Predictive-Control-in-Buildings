# -------------------------------------------------------------
# Function: building_spread_input.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation spread_input of the type of model Building: turns the
# block of a building in the input of a call, given per market
# interval, into its table on the internal time steps of the call,
# the one the simulation of the building runs on. It holds the
# columns of the variable registry of the building that the input
# fills, and those that start at their initial value.
# -------------------------------------------------------------
# How each input is spread over the rows
#   - Occupancy        : the value of the interval of the row.
#   - Overall_Climate  : the climate season of the building, on
#                        every row.
#   - Setpoints        : the value of the interval of the row, per
#                        itinerary.
#   - Elec_total       : the interval energy divided evenly between
#                        the steps of the interval, per itinerary.
#   - Ti, Te           : the value given at each interval start, on
#                        the row of that instant, per itinerary.
# The remaining columns start at 0: the activation of the heating
# and cooling systems, their heat and electricity, and the comfort.
# Every itinerary of the input holds every column, with NA where the
# call gave no value.
# -------------------------------------------------------------
# Inputs
#   asset_input : Named list. The block of the building in the input
#                 of the call:
#                 - Overall_Climate: character scalar
#                 - context: data frame with time and Occupancy, one
#                   row per market interval
#                 - itineraries: list with plan, plan_flex_down and
#                   plan_flex_up, each a data frame with time, Ti,
#                   Te, the six setpoints (STP_heat, STP_heat_low,
#                   STP_heat_high, STP_cool, STP_cool_low,
#                   STP_cool_high) and Elec_total, one row per
#                   market interval
#   grid        : Named list. The time grid of the call:
#                 - time: POSIXct vector, one value per internal step
#                 - slot_of_row: integer vector, the position in the
#                   input of the interval of each row
#                 - row_at_slot_start: integer vector, the row of the
#                   start of each interval of the input
#                 - steps_per_slot: numeric scalar, the number of
#                   internal steps of a market interval
#   asset       : Named list. The parameters of the building, its
#                 entry of parameters$assets. Not read.
# -------------------------------------------------------------
# Outputs
#   Data frame, the table of the building, one row per internal
#   step, with the columns:
#     - time, Occupancy, Overall_Climate
#     - for each itinerary (plan, plan_flex_down, plan_flex_up): the
#       six setpoints, Ti, Te, Elec_total, Act_heat, Act_cool,
#       Thermostat_heat, Thermostat_cool, Q_heat, Q_cool, Elec_heat,
#       Elec_cool and Comfort, each with
#       the suffix of the itinerary
# -------------------------------------------------------------
# Code outline
# 1. Context columns
# 2. Itinerary columns
# 3. Remaining columns
# -------------------------------------------------------------
# Usage instructions
# asset_df <- building_spread_input(
#   asset_input = checked$assets[["Building_001"]],
#   grid        = grid,
#   asset       = parameters$assets[["Building_001"]]
# )
# -------------------------------------------------------------

building_spread_input <- function(asset_input,
                                  grid,
                                  asset
                                  ) {

  # -------------------------------------------------------------
  # 1. Context columns
  # -------------------------------------------------------------
  {
    asset_df <- data.frame(time = grid$time)

    asset_df$Occupancy       <- as.integer(
      asset_input$context$Occupancy[grid$slot_of_row]
    )
    asset_df$Overall_Climate <- as.character(asset_input$Overall_Climate)
  }

  # -------------------------------------------------------------
  # 2. Itinerary columns
  # The three itineraries are spread the same way. The process
  # rebuilds both flexibility itineraries from the plan, so their
  # values only set the starting point.
  # -------------------------------------------------------------
  {
    setpoint_columns <- c("STP_heat", "STP_heat_low", "STP_heat_high",
                          "STP_cool", "STP_cool_low", "STP_cool_high")

    for (CONT_001 in c("plan", "plan_flex_down", "plan_flex_up")) {
      itinerary <- asset_input$itineraries[[CONT_001]]

      for (CONT_002 in setpoint_columns) {
        asset_df[[paste0(CONT_002, "_", CONT_001)]] <-
          itinerary[[CONT_002]][grid$slot_of_row]
      }

      for (CONT_003 in c("Ti", "Te")) {
        state <- rep(NA_real_, nrow(asset_df))
        state[grid$row_at_slot_start] <- itinerary[[CONT_003]]
        asset_df[[paste0(CONT_003, "_", CONT_001)]] <- state
      }

      # spread_slot_energy is called to divide the energy of each
      # interval evenly between its internal steps.
      asset_df[[paste0("Elec_total_", CONT_001)]] <- spread_slot_energy(
        slot_energy = itinerary$Elec_total,
        grid        = grid
      )
    }

    rm(list = c("CONT_001", "CONT_002", "CONT_003", "itinerary", "state",
                "setpoint_columns"))
  }

  # -------------------------------------------------------------
  # 3. Remaining columns
  # -------------------------------------------------------------
  {
    for (CONT_004 in c("plan", "plan_flex_down", "plan_flex_up")) {
      for (CONT_005 in c("Act_heat", "Act_cool", "Thermostat_heat",
                         "Thermostat_cool")) {
        asset_df[[paste0(CONT_005, "_", CONT_004)]] <- 0L
      }
      for (CONT_006 in c("Q_heat", "Q_cool", "Elec_heat", "Elec_cool",
                         "Comfort")) {
        asset_df[[paste0(CONT_006, "_", CONT_004)]] <- 0
      }
    }
    rm(list = c("CONT_004", "CONT_005", "CONT_006"))
  }

  return(asset_df)
}
