# -------------------------------------------------------------
# Function: expand_to_steps.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Turns the checked inputs, given per market interval, into the
# working table the simulation functions run on: one row per internal
# time step (main_resolution_sec), from i0 to i_end_horizon, both
# included. Every function of the market process reads and writes
# this table.
# -------------------------------------------------------------
# Rows and market intervals
# A row holds the state of the building at its instant and the energy
# of the time step that ends at that instant. Each row is therefore
# assigned (column MarketUTC) to the market interval that contains its
# time step, i.e. the interval of the instant one step earlier. With
# this rule the energy of a market interval is exactly the energy of
# the steps that fall inside it.
# The first row (i0) is the initial condition. Its time step lies
# before i0, so its MarketUTC is the interval before i0, which is not
# part of the input. Interval values are copied onto it from the first
# interval, and its energies are 0.
# -------------------------------------------------------------
# How each input is spread over the rows
#   - Text, SolarR     : linear interpolation between interval starts,
#                        held constant past the last one. The input
#                        already is the forecast, so the simulation
#                        reads these columns directly.
#   - T_ext_24h        : the single value of the call, on every row.
#   - Occupancy        : the value of the row's interval.
#   - New-commitment flexibility prices (Flex_unit_cost_down_com_sell,
#     Flex_unit_cost_up_com_sell): the value of the row's interval.
#                        They are the only prices read row by row, to
#                        decide where a flexibility window may start.
#                        Every other price is read per interval from
#                        the context built by resolve_marginal_context().
#   - Setpoints        : the value of the row's interval, per itinerary.
#   - Elec_total and the commitments Elec_flex_down/Elec_flex_up: the
#                        interval energy divided evenly between the
#                        steps of the interval.
#   - Ti, Te           : the value given at each interval start, on the
#                        row of that instant.
# The remaining simulation columns start at 0.
# -------------------------------------------------------------
# Inputs
#   checked    : Named list, as returned by validate_inputs().
#   parameters : Named list. Uses computing$main_resolution_sec and
#                market$market_resolution.
# -------------------------------------------------------------
# Outputs
#   Data frame, the working table (period_chunk), one row per step.
# -------------------------------------------------------------
# Code outline
# 1. Time grid and interval of every row
# 2. Context columns
# 3. Price columns
# 4. Itinerary columns
# 5. Remaining simulation columns
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- expand_to_steps(checked, parameters)
# -------------------------------------------------------------
# Where this function/script is used
#   - optimize_market(): builds the working table of the call.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

expand_to_steps <- function(checked,
                            parameters
                            ) {

  # -------------------------------------------------------------
  # 1. Time grid and interval of every row
  # -------------------------------------------------------------
  {
    step_sec       <- parameters$computing$main_resolution_sec
    resolution_sec <- parameters$market$market_resolution * 60
    steps_per_slot <- resolution_sec / step_sec

    time <- seq(from = checked$market$i0,
                to   = checked$market$i_end_horizon,
                by   = step_sec)

    market_utc <- as.POSIXct(
      floor((as.numeric(time) - step_sec) / resolution_sec) * resolution_sec,
      origin = "1970-01-01",
      tz     = "UTC"
    )

    # Position of each row's interval in the input grid. The first row
    # falls before i0 and takes the first interval's values.
    slot_of_row <- match(as.numeric(market_utc), as.numeric(checked$slot_time))
    slot_of_row[1] <- 1L

    period_chunk <- data.frame(
      time      = time,
      MarketUTC = market_utc
    )

    rm(market_utc, resolution_sec)
  }

  # -------------------------------------------------------------
  # 2. Context columns
  # -------------------------------------------------------------
  {
    for (CONT_001 in c("Text", "SolarR")) {
      period_chunk[[CONT_001]] <- approx(
        x    = as.numeric(checked$slot_time),
        y    = checked$context[[CONT_001]],
        xout = as.numeric(time),
        rule = 2
      )$y
    }

    period_chunk$T_ext_24h <- checked$market$T_ext_24h
    period_chunk$Occupancy <- as.integer(checked$context$Occupancy[slot_of_row])

    rm(CONT_001)
  }

  # -------------------------------------------------------------
  # 3. Price columns
  # -------------------------------------------------------------
  # Only the new-commitment flexibility prices are read from the
  # working table: they decide where a flexibility window may start.
  # -------------------------------------------------------------
  {
    for (CONT_002 in c("Flex_unit_cost_down_com_sell", "Flex_unit_cost_up_com_sell")) {
      period_chunk[[CONT_002]] <- checked$prices[[CONT_002]][slot_of_row]
    }
    rm(CONT_002)
  }

  # -------------------------------------------------------------
  # 4. Itinerary columns
  # -------------------------------------------------------------
  # The three itineraries are spread the same way. The process rebuilds
  # both flexibility itineraries from the plan, so their values only set
  # the starting point.
  # -------------------------------------------------------------
  {
    setpoint_columns <- c("STP_heat", "STP_heat_low", "STP_heat_high",
                          "STP_cool", "STP_cool_low", "STP_cool_high")
    row_at_slot_start <- match(as.numeric(checked$slot_time), as.numeric(time))

    spread_energy <- function(slot_energy) {
      row_energy    <- slot_energy[slot_of_row] / steps_per_slot
      row_energy[1] <- 0
      return(row_energy)
    }

    for (CONT_003 in c("plan", "plan_flex_down", "plan_flex_up")) {
      itinerary <- checked$itineraries[[CONT_003]]

      for (CONT_004 in setpoint_columns) {
        period_chunk[[paste0(CONT_004, "_", CONT_003)]] <- itinerary[[CONT_004]][slot_of_row]
      }

      for (CONT_005 in c("Ti", "Te")) {
        state <- rep(NA_real_, nrow(period_chunk))
        state[row_at_slot_start] <- itinerary[[CONT_005]]
        period_chunk[[paste0(CONT_005, "_", CONT_003)]] <- state
      }

      period_chunk[[paste0("Elec_total_", CONT_003)]] <- spread_energy(itinerary$Elec_total)
    }

    period_chunk$Elec_flex_down_plan <- spread_energy(checked$itineraries$plan$Elec_flex_down)
    period_chunk$Elec_flex_up_plan   <- spread_energy(checked$itineraries$plan$Elec_flex_up)

    rm(CONT_003, CONT_004, CONT_005, itinerary, state, setpoint_columns,
       row_at_slot_start, spread_energy)
  }

  # -------------------------------------------------------------
  # 5. Remaining simulation columns
  # -------------------------------------------------------------
  {
    for (CONT_006 in c("plan", "plan_flex_down", "plan_flex_up")) {
      for (CONT_007 in c("Act_heat", "Act_cool")) {
        period_chunk[[paste0(CONT_007, "_", CONT_006)]] <- 0L
      }
      for (CONT_008 in c("Q_heat", "Q_cool", "Elec_heat", "Elec_cool", "Comfort")) {
        period_chunk[[paste0(CONT_008, "_", CONT_006)]] <- 0
      }
    }

    period_chunk$Flex_phase_down_plan <- 0
    period_chunk$Flex_phase_up_plan   <- 0

    rm(CONT_006, CONT_007, CONT_008)
  }

  rm(time, slot_of_row, step_sec, steps_per_slot)

  return(period_chunk)
}
