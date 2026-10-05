# -------------------------------------------------------------
# Function: aggregate_to_slots.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Turns the working table back into the three itineraries returned
# by the script, one value per market interval, from the interval
# that starts at i_begin_horizon to the closing interval, the one that
# starts at i_end_control.
# Each variable is aggregated by its own nature:
#   - Ti, Te           : state at the start of the interval, read on
#                        the row of that instant.
#   - setpoints        : the value of the interval, read on its first
#                        time step.
#   - Elec_total and the commitments Elec_flex_down/Elec_flex_up: the
#                        sum of the time steps of the interval.
# The closing interval only carries the state (Ti, Te): it passes the
# state reached at i_end_control to the next market and commits no
# energy, so its other variables are missing (NA).
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. Working table after run_market_process().
#   checked      : Named list, as returned by validate_inputs().
#   parameters   : Named list. Uses market$market_resolution.
# -------------------------------------------------------------
# Outputs
#   Named list with plan, plan_flex_down and plan_flex_up, each a
#   data frame with the columns:
#     - time
#     - Ti, Te
#     - STP_heat, STP_heat_low, STP_heat_high
#     - STP_cool, STP_cool_low, STP_cool_high
#     - Elec_total
#   plan also carries Elec_flex_down and Elec_flex_up.
# -------------------------------------------------------------
# Code outline
# 1. Output intervals
# 2. Itineraries
# -------------------------------------------------------------
# Usage instructions
# itineraries <- aggregate_to_slots(period_chunk, checked, parameters)
# -------------------------------------------------------------
# Where this function/script is used
#   - optimize_market(): builds the itineraries of the output.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

aggregate_to_slots <- function(period_chunk,
                               checked,
                               parameters
                               ) {

  # -------------------------------------------------------------
  # 1. Output intervals
  # -------------------------------------------------------------
  {
    resolution_sec <- parameters$market$market_resolution * 60
    out_time <- seq(from = checked$market$i_begin_horizon,
                    to   = checked$market$i_end_control,
                    by   = resolution_sec)
    n_out     <- length(out_time)
    committed <- seq_len(n_out - 1)

    row_at_start <- match(as.numeric(out_time), as.numeric(period_chunk$time))
    first_row    <- match(as.numeric(out_time[committed]),
                          as.numeric(period_chunk$MarketUTC))
    slot_rows    <- match(as.numeric(period_chunk$MarketUTC),
                          as.numeric(out_time[committed]))

    sum_by_slot <- function(values) {
      totals <- rep(NA_real_, n_out)
      totals[committed] <- vapply(committed, function(k) {
        sum(values[which(slot_rows == k)])
      }, numeric(1))
      return(totals)
    }

    rm(resolution_sec)
  }

  # -------------------------------------------------------------
  # 2. Itineraries
  # -------------------------------------------------------------
  {
    setpoint_columns <- c("STP_heat", "STP_heat_low", "STP_heat_high",
                          "STP_cool", "STP_cool_low", "STP_cool_high")
    itineraries <- list()

    for (CONT_001 in c("plan", "plan_flex_down", "plan_flex_up")) {
      itinerary <- data.frame(time = out_time)
      itinerary$Ti <- period_chunk[[paste0("Ti_", CONT_001)]][row_at_start]
      itinerary$Te <- period_chunk[[paste0("Te_", CONT_001)]][row_at_start]

      for (CONT_002 in setpoint_columns) {
        values <- rep(NA_real_, n_out)
        values[committed] <- period_chunk[[paste0(CONT_002, "_", CONT_001)]][first_row]
        itinerary[[CONT_002]] <- values
      }

      itinerary$Elec_total <- sum_by_slot(period_chunk[[paste0("Elec_total_", CONT_001)]])

      if (CONT_001 == "plan") {
        itinerary$Elec_flex_down <- sum_by_slot(period_chunk$Elec_flex_down_plan)
        itinerary$Elec_flex_up   <- sum_by_slot(period_chunk$Elec_flex_up_plan)
      }

      itineraries[[CONT_001]] <- itinerary
    }

    rm(CONT_001, CONT_002, itinerary, values, setpoint_columns)
  }

  rm(out_time, n_out, committed, row_at_start, first_row, slot_rows, sum_by_slot)

  return(itineraries)
}
