# -------------------------------------------------------------
# Script: 11_full_market_information_setup.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the future-horizon price matrices used by the market
# processes (Scheduling and Piloting) to look up energy and
# flexibility prices at each market step.
# Each price signal is stored as a data frame with one row per
# market event (a MarketUTC interval where a Scheduling or Piloting
# market actually clears, i.e. Main_df$Sched_Market_Name or
# Main_df$Pilot_Market_Name is active there) and one column per
# future step ahead of that event, named "0" (the event's own
# interval) to as.character(max_steps_ahead - 1). Column step j
# still refers to the market-resolution grid interval j steps ahead
# of the row's own MarketUTC, exactly as before; only the row set
# changed, from "every market-resolution interval" to "every market
# event". The thirteen data frames are bundled into a single named list,
# full_market_information (e.g.
# full_market_information$Elec_unit_cost_import_buy_df), which is the
# only object this script leaves in the global environment for this
# subsystem.
# Nine of the thirteen signals (Elec_unit_cost_distribution, used only
# by reward_function() via resolve_marginal_context(), and the eight
# flexibility buy/sell signals) are pass-through: the
# value assigned to a MarketUTC interval is simply the mean of the
# Main_df signal over all observations sharing that interval (step 3),
# then looked up per future step exactly as before (step 5).
# The remaining four (Elec_unit_cost_import/export_buy/sell) are NOT
# averaged from a flat Main_df column - they are computed cell by cell
# from Elec_unit_cost_buy (P_ref) using the discount formula given in
# 10_energy_price_signals_setup.R and parameters$energy_price, because
# factor_tiempo depends on h = j * market_resolution/60 (j =
# future-step column), which is not a property of a single Main_df
# row - see step 5. A flat per-row column therefore cannot represent
# this signal.
# The future-step column width (max_steps_ahead) is the distance from
# the bid time of the furthest-looking market to the end of its
# optimization horizon, in market_resolution steps. It is read from
# the market configuration in use (the basic markets of
# 03_Market_config.csv, or the market tables in complex mode) by
# compute_max_steps_ahead().
# Sourced from Main.R, after 03_climate_priority.R and before
# 07_reference_temperature_profiles.R.
# -------------------------------------------------------------
# Inputs
#   Main_df, with its market columns and its twelve price signals.
#   parameters$market, parameters$market_config_scheduling and
#     parameters$market_config_piloting : the resolution and the
#     horizons.
#   parameters$energy_price : the variation of each price with the
#     horizon it is quoted at.
#   parameters$computing : the lead edges of the four price bands.
# -------------------------------------------------------------
# Outputs
#   full_market_information, a list of data frames, one per price
#     signal, with one row per market event and one column per step
#     ahead.
# -------------------------------------------------------------
# Code outline
# 1. Determine the furthest horizon any market looks at.
# 2. Build the market-resolution grid and locate the market events.
# 3. Average each price signal over every market interval.
# 4. Create the horizon data frames, with every cell missing (NA).
# 5. Fill them from those averages, discounted to the horizon.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by Main.R before the simulation loop,
#   which reads these prices at every market.
# -------------------------------------------------------------
# Where this function/script is used
# Sourced by 30_Simulation/Main.R.
# -------------------------------------------------------------
# functions/scripts called
#   is_market_active() - says whether a market name marks an
#                        active market
#   compute_max_steps_ahead() - the number of steps ahead of the
#                        furthest-looking market
#   price_variation_at_lead() - the variation of the energy price
#                        with the lead it is quoted at
#   avg_by_market()    - local helper of block 3, defined and removed
#                        there: the mean of a Main_df signal over each
#                        market interval
# -------------------------------------------------------------

# -------------------------------------------------------------
# 1. Determine the maximum future horizon (max_steps_ahead)
# -------------------------------------------------------------
{
  # compute_max_steps_ahead is called to size the future-step columns
  # from the market configuration in use: the basic Scheduling and
  # Piloting markets, or the market tables in complex mode.
  max_steps_ahead <- compute_max_steps_ahead(parameters)
}

# -------------------------------------------------------------
# 2. Market-resolution grid (full) and market-event rows (sparse)
# -------------------------------------------------------------
# Ensures the market-interval timestamp column Main_df$MarketUTC
# exists, flooring every Main_df timestamp to the
# market_resolution grid. market_time_full is the sorted vector of
# every unique MarketUTC interval in the simulation and is used only
# to compute per-interval price averages and to look up future
# steps; it is not the row set of the matrices. market_event_time is
# the sorted vector of MarketUTC intervals where a Scheduling or
# Piloting market actually clears, and defines the rows of every
# price matrix. row_group maps each Main_df observation to its
# market interval (on the full grid), and group_count holds the
# number of observations per interval.
# -------------------------------------------------------------
{
  if (!"MarketUTC" %in% names(Main_df)) {
    Main_df$MarketUTC <- as.POSIXct(
      floor(as.numeric(Main_df$time) / (parameters$market$market_resolution * 60)) *
        (parameters$market$market_resolution * 60),
      origin = "1970-01-01",
      tz     = "UTC"
    )
  }

  market_time_full <- sort(unique(Main_df$MarketUTC))
  n_market_full     <- length(market_time_full)

  row_group   <- match(Main_df$MarketUTC, market_time_full)
  group_count <- tabulate(row_group, nbins = n_market_full)

  # is_market_active is called per row to flag which MarketUTC
  # intervals actually have a Scheduling or Piloting market clearing,
  # so that market_event_time can be restricted to those intervals.
  sched_active <- sapply(Main_df$Sched_Market_Name, is_market_active)
  pilot_active <- sapply(Main_df$Pilot_Market_Name, is_market_active)

  market_event_time <- sort(unique(Main_df$MarketUTC[sched_active | pilot_active]))
  n_market          <- length(market_event_time)
  event_base_index  <- match(market_event_time, market_time_full)

  rm(sched_active, pilot_active)
}

# -------------------------------------------------------------
# 3. Average price per market interval (full grid)
# -------------------------------------------------------------
# For the nine pass-through price signals, the value of a MarketUTC
# interval is the mean of the Main_df observations sharing that
# interval, i.e. the per-interval sum divided by the number of
# observations in the interval. Each resulting vector is aligned with
# market_time_full. The nine signal names below are the Main_df column
# names; the matching output matrix in full_market_information is the
# same name with a "_df" suffix (see sections 4-5).
# Elec_unit_cost_buy is averaged the same way (buy_ref_by_market), but
# only as the P_ref input to the four energy-signal formulas computed
# per cell in step 5 - it is not itself one of the thirteen output
# matrices.
# -------------------------------------------------------------
{
  avg_by_market <- function(signal_values) {
    as.numeric(rowsum(signal_values, row_group)) / group_count
  }

  price_signal_names <- c(
    "Elec_unit_cost_distribution",
    "Flex_unit_cost_down_com_buy", "Flex_unit_cost_down_com_sell",
    "Flex_unit_cost_down_exec_buy", "Flex_unit_cost_down_exec_sell",
    "Flex_unit_cost_up_com_buy", "Flex_unit_cost_up_com_sell",
    "Flex_unit_cost_up_exec_buy", "Flex_unit_cost_up_exec_sell"
  )

  price_market_by_signal <- lapply(
    setNames(price_signal_names, price_signal_names),
    function(signal_name) avg_by_market(Main_df[[signal_name]])
  )

  buy_ref_by_market <- avg_by_market(Main_df$Elec_unit_cost_buy)

  rm(avg_by_market, row_group, group_count)
}

# -------------------------------------------------------------
# 4. Initialise the future-horizon price data frames
# -------------------------------------------------------------
# Thirteen data frames are created (the nine pass-through signals of
# step 3 plus the four energy signals computed in step 5), one per
# price signal, each sized (n_market x (1 + max_steps_ahead)): a
# 'time' column (the market-event intervals) plus max_steps_ahead
# future-step columns, initialised to NA (double). A single NA
# template is built once and reused for all thirteen data frames to
# avoid repeated allocation. The thirteen data frames are bundled into
# a single named list, full_market_information, which is the only
# object that persists in the global environment for this subsystem.
# -------------------------------------------------------------
{
  energy_signal_names <- c(
    "Elec_unit_cost_import_buy", "Elec_unit_cost_import_sell",
    "Elec_unit_cost_export_buy", "Elec_unit_cost_export_sell"
  )
  all_signal_names <- c(energy_signal_names, price_signal_names)

  step_col_names <- as.character(0:(max_steps_ahead - 1))

  na_step_columns <- as.data.frame(
    matrix(NA_real_, nrow = n_market, ncol = max_steps_ahead, dimnames = list(NULL, step_col_names))
  )

  full_market_information <- setNames(
    lapply(
      all_signal_names,
      function(signal_name) data.frame(time = market_event_time, na_step_columns, check.names = FALSE)
    ),
    paste0(all_signal_names, "_df")
  )

  rm(na_step_columns, step_col_names)
}

# -------------------------------------------------------------
# 5. Fill the price data frames from the per-interval averages
# -------------------------------------------------------------
# For every future step CONT_001 (0 = the market event's own
# interval), the source interval is the market event's position on
# the full grid (event_base_index) shifted forward by CONT_001
# positions, clamped to the last available interval so that steps
# beyond the end of the series repeat the last known value.
# The nine pass-through signals are looked up directly. The four
# energy signals are instead computed from buy_ref_by_market (P_ref)
# using the discount formula (see header): factor_tiempo depends only
# on h = CONT_001 * market_resolution/60 (identical for every market
# event in this column), via the 4-tier partition of
# Price_variation_in_time:
# day_ahead if h >= price_lead_day_ahead_h, 5h if h >= price_lead_5h_h,
# 1_5h if h > price_lead_1h_h, below_1h otherwise (24, 5 and 1 h in
# 01_computing_parameters.csv); see price_variation_at_lead().
# -------------------------------------------------------------
{
  d_exp  <- parameters$energy_price$Energy_Export_discount / 100
  d_sell <- parameters$energy_price$Energy_Sell_discount / 100

  for (CONT_001 in 0:(max_steps_ahead - 1)) {

    col_name       <- as.character(CONT_001)
    target_indices <- pmin(event_base_index + CONT_001, n_market_full)

    for (signal_name in price_signal_names) {
      full_market_information[[paste0(signal_name, "_df")]][[col_name]] <-
        price_market_by_signal[[signal_name]][target_indices]
    }

    h             <- CONT_001 * parameters$market$market_resolution / 60
    # price_variation_at_lead is called to find which of the four
    # variations applies at this lead, from the band edges of
    # 01_computing_parameters.csv.
    factor_tiempo <- 1 + price_variation_at_lead(
      lead_h       = h,
      energy_price = parameters$energy_price,
      computing    = parameters$computing
    ) / 100

    p_ref       <- buy_ref_by_market[target_indices]
    import_buy  <- p_ref * factor_tiempo
    import_sell <- import_buy * (1 - d_sell)
    export_buy  <- p_ref * factor_tiempo * (1 - d_exp)
    export_sell <- export_buy * (1 - d_sell)

    full_market_information$Elec_unit_cost_import_buy_df[[col_name]]  <- import_buy
    full_market_information$Elec_unit_cost_import_sell_df[[col_name]] <- import_sell
    full_market_information$Elec_unit_cost_export_buy_df[[col_name]]  <- export_buy
    full_market_information$Elec_unit_cost_export_sell_df[[col_name]] <- export_sell
  }

  rm(CONT_001, col_name, target_indices, signal_name, h, factor_tiempo,
     p_ref, import_buy, import_sell, export_buy, export_sell,
     d_exp, d_sell, buy_ref_by_market,
     price_market_by_signal, price_signal_names, energy_signal_names,
     all_signal_names, market_time_full, n_market_full, event_base_index,
     market_event_time, n_market)
}
