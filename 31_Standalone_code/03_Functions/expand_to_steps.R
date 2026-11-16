# -------------------------------------------------------------
# Function: expand_to_steps.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Turns the checked inputs, given per market interval, into the
# piece the simulation functions run on: the table of the system and
# one table per asset of the call, each with one row per internal
# time step (main_resolution_sec), from i0 to i_end_horizon, both
# included. Every function of the market process reads and writes
# this piece.
# -------------------------------------------------------------
# Rows and market intervals
# A row holds the state of the assets at its instant and the energy
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
# The piece
# A list with:
#   - system : the table of the system, with time, MarketUTC, the
#     weather, the activation probability of each leg, the net
#     electricity of the system in each itinerary, the flexibility
#     committed on the plan and the phases of the flexibility
#     windows.
#   - assets : one entry per asset of the call, in the order of the
#     asset registry, each with df, the table of the asset. Its
#     columns are those of its type of model: the operation
#     spread_input of the model writes them from the block of the
#     asset, and the operation prepare_period completes them for the
#     period.
# -------------------------------------------------------------
# How each input of the system is spread over the rows
#   - Text, SolarR     : linear interpolation between interval starts,
#                        held constant past the last one. The input
#                        already is the forecast, so the same values
#                        go to the columns of the weather and to those
#                        of its forecast (Text_forec, SolarR_forec),
#                        which the simulation of the plan reads.
#   - T_ext_24h        : the single value of the call, on every row.
#                        It is known when the market clears, so the
#                        same value goes to T_ext_24h_forec, which the
#                        simulation of the plan reads.
#   - Flex_Probab_down, Flex_Probab_up: the activation probability of
#                        the interval of the row, on every row. The
#                        reward reads it on the first row, which has no
#                        interval of the market.
#   - Elec_total of each itinerary and the commitments
#     Elec_flex_down/Elec_flex_up: the interval energy divided
#                        evenly between the steps of the interval.
# The phases of the flexibility windows start at 0.
# -------------------------------------------------------------
# Inputs
#   checked    : Named list, as returned by validate_inputs().
#   parameters : Named list. Uses computing$main_resolution_sec,
#                market$market_resolution and assets, whose
#                asset_type selects the operations of each asset.
# -------------------------------------------------------------
# Outputs
#   List, the piece, with system and assets as described above.
# -------------------------------------------------------------
# Code outline
# 1. Time grid and interval of every row
# 2. Table of the system
# 3. Table of each asset
# -------------------------------------------------------------
# Usage instructions
# piece <- expand_to_steps(checked, parameters)
# -------------------------------------------------------------

expand_to_steps <- function(checked,
                            parameters
                            ) {

  # -------------------------------------------------------------
  # 1. Time grid and interval of every row
  # grid is the time grid the operation spread_input of each type of
  # model receives: time, slot_of_row, row_at_slot_start and
  # steps_per_slot.
  # -------------------------------------------------------------
  {
    step_sec       <- parameters$computing$main_resolution_sec
    resolution_sec <- parameters$market$market_resolution * 60

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

    grid <- list(
      time              = time,
      slot_of_row       = slot_of_row,
      row_at_slot_start = match(as.numeric(checked$slot_time),
                                as.numeric(time)),
      steps_per_slot    = resolution_sec / step_sec
    )

    rm(list = c("resolution_sec", "step_sec", "slot_of_row"))
  }

  # -------------------------------------------------------------
  # 2. Table of the system
  # -------------------------------------------------------------
  {
    system_df <- data.frame(
      time      = time,
      MarketUTC = market_utc
    )

    # Text and SolarR are the weather of the call, and the forecast
    # of the plan is the same weather.
    for (CONT_001 in c("Text", "SolarR")) {
      weather <- approx(
        x    = as.numeric(checked$slot_time),
        y    = checked$context[[CONT_001]],
        xout = as.numeric(time),
        rule = 2
      )$y
      system_df[[CONT_001]]                     <- weather
      system_df[[paste0(CONT_001, "_forec")]]   <- weather
    }

    # T_ext_24h is the mean Text of the day before the clearing date,
    # known when the market clears, and the plan reads it as
    # T_ext_24h_forec.
    system_df$T_ext_24h       <- checked$market$T_ext_24h
    system_df$T_ext_24h_forec <- checked$market$T_ext_24h

    for (CONT_007 in c("Flex_Probab_down", "Flex_Probab_up")) {
      system_df[[CONT_007]] <- checked$prices[[CONT_007]][grid$slot_of_row]
    }

    for (CONT_002 in names(checked$system$itineraries)) {
      # spread_slot_energy is called to divide the net energy of the
      # system of each interval evenly between its internal steps.
      system_df[[paste0("Elec_total_", CONT_002)]] <- spread_slot_energy(
        slot_energy = checked$system$itineraries[[CONT_002]]$Elec_total,
        grid        = grid
      )
    }

    for (CONT_003 in c("Elec_flex_down", "Elec_flex_up")) {
      # spread_slot_energy is called to divide the commitment of each
      # interval evenly between its internal steps.
      system_df[[paste0(CONT_003, "_plan")]] <- spread_slot_energy(
        slot_energy = checked$system$itineraries$plan[[CONT_003]],
        grid        = grid
      )
    }

    system_df$Flex_phase_down_plan <- 0
    system_df$Flex_phase_up_plan   <- 0

    rm(list = c("CONT_001", "CONT_002", "CONT_003", "CONT_007", "weather",
                "market_utc"))
  }

  # -------------------------------------------------------------
  # 3. Table of each asset
  # Each type of model writes the table of its assets from their
  # blocks of the input, and prepares it for the period.
  # -------------------------------------------------------------
  {
    asset_tables <- list()
    for (CONT_004 in names(checked$assets)) {
      asset <- parameters$assets[[CONT_004]]

      # model_type_contract is called to take the operations of the
      # type of model of the asset.
      model <- model_type_contract(asset$asset_type)

      # The operation spread_input of the model is called to turn the
      # block of the asset in the input into its table on the internal
      # time steps.
      asset_df <- model$spread_input(
        asset_input = checked$assets[[CONT_004]],
        grid        = grid,
        asset       = asset
      )

      # The operation prepare_period of the model is called to add the
      # columns the asset needs over this period, such as the comfort
      # bands of a building.
      asset_df <- model$prepare_period(
        asset_df = asset_df,
        asset    = asset
      )

      asset_tables[[CONT_004]] <- list(df = asset_df)
      rm(list = c("asset", "model", "asset_df"))
    }
    rm(list = "CONT_004")
  }

  rm(list = c("time", "grid"))

  return(list(system = system_df, assets = asset_tables))
}
