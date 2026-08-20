# -------------------------------------------------------------
# Script: market_commitments_setup.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Initialises the market output matrices that record, per market
# step, the energy commitments (buy, sell and net), the flexibility
# commitments and the accumulated differential costs produced by
# the Scheduling and Piloting processes.
# -------------------------------------------------------------
# Flexibility commitments: up and down legs
# A flexibility commitment is a service the building sells to the
# grid, and it has two independent legs: down-flexibility (a promise
# to reduce load on request) and up-flexibility (a promise to increase
# it). Each leg can be sold (a new or larger commitment) and bought
# back (unwinding part or all of a commitment sold in an earlier
# market), so four matrices are kept:
#   Elec_flex_down_sell_plan_df - down-flexibility newly sold
#   Elec_flex_down_buy_plan_df  - down-flexibility bought back
#   Elec_flex_up_sell_plan_df   - up-flexibility newly sold
#   Elec_flex_up_buy_plan_df    - up-flexibility bought back
# The optimizer currently only ever offers down-flexibility: the
# committed volume is Main_df$Elec_flex_plan = Elec_total_plan -
# Elec_total_plan_flex, which is positive when the flexibilized load
# is lower than the baseline load, i.e. a load reduction. All of it is
# therefore recorded on the down leg, and the two up-leg matrices stay
# at 0 for the whole simulation. They exist so that the accounting
# structure is complete and an up-flexibility product can later be
# recorded without changing the shape of these outputs.
# Every row corresponds to a market event (a MarketUTC interval
# where a Scheduling or Piloting market actually clears, i.e.
# Main_df$Sched_Market_Name or Main_df$Pilot_Market_Name is active
# there), and every future-step column holds the value committed for
# the market-resolution interval that many steps ahead of that
# event, exactly as before.
# Twelve data frames are created, each with one row per market event
# (column 'time') and one column per future step ahead, named "0"
# (the event's own interval) to as.character(max_steps_ahead - 1).
# All future-step cells are initialised to 0 (double); they are
# filled later by the market integration logic. Since the energy
# signals are aggregated by sum over each MarketUTC interval, the
# committed value written to an interval is the sum of the
# underlying commitments. The twelve data frames are bundled into a
# single named list, market_commitments (e.g.
# market_commitments$Elec_net_plan_df), which is the only object
# this script leaves in the global environment for this subsystem.
# max_steps_ahead is expected to be available from
# full_market_information_setup.R; it is recomputed here as a
# safeguard if absent, using the same dynamic horizon derived from
# parameters$market_config_scheduling and
# parameters$market_config_piloting.
# Sourced from Main.R, right after full_market_information_setup.R.
# -------------------------------------------------------------

# -------------------------------------------------------------
# 1. Prerequisites and market-event rows (sparse)
# -------------------------------------------------------------
# Ensures max_steps_ahead and the Main_df$MarketUTC column exist,
# then builds market_event_time (sorted unique MarketUTC intervals
# where a Scheduling or Piloting market actually clears) and
# n_market, which define the rows of every output matrix.
# -------------------------------------------------------------
{
  if (!exists("max_steps_ahead")) {
    max_hours_sched <- 0
    if (!is.null(parameters$market_config_scheduling) &&
        nrow(parameters$market_config_scheduling) > 0) {
      max_hours_sched <- max(
        as.numeric(parameters$market_config_scheduling$end) +
        as.numeric(parameters$market_config_scheduling$end_optimization) +
        as.numeric(parameters$market_config_scheduling$closure)
      )
    }

    max_hours_pilot <- 0
    if (!is.null(parameters$market_config_piloting) &&
        nrow(parameters$market_config_piloting) > 0) {
      max_hours_pilot <- max(
        as.numeric(parameters$market_config_piloting$end) +
        as.numeric(parameters$market_config_piloting$end_optimization) +
        as.numeric(parameters$market_config_piloting$closure)
      )
    }

    max_hours_ahead <- max(max_hours_sched, max_hours_pilot)
    max_steps_ahead <- as.integer(ceiling(max_hours_ahead * 60 / parameters$market$market_resolution))

    rm(max_hours_sched, max_hours_pilot, max_hours_ahead)
  }

  if (!"MarketUTC" %in% names(Main_df)) {
    Main_df$MarketUTC <- as.POSIXct(
      floor(as.numeric(Main_df$time) / (parameters$market$market_resolution * 60)) *
        (parameters$market$market_resolution * 60),
      origin = "1970-01-01",
      tz     = "UTC"
    )
  }

  # is_market_active is called per row to flag which MarketUTC
  # intervals actually have a Scheduling or Piloting market clearing,
  # so that market_event_time can be restricted to those intervals.
  sched_active <- sapply(Main_df$Sched_Market_Name, is_market_active)
  pilot_active <- sapply(Main_df$Pilot_Market_Name, is_market_active)

  market_event_time <- sort(unique(Main_df$MarketUTC[sched_active | pilot_active]))
  n_market          <- length(market_event_time)

  rm(sched_active, pilot_active)
}

# -------------------------------------------------------------
# 2. Initialise the market output data frames to zero
# -------------------------------------------------------------
# Twelve data frames are created, each sized (n_market x
# (1 + max_steps_ahead)): a 'time' column (the market-event
# intervals) plus max_steps_ahead future-step columns, initialised
# to 0 (double). A single zero template is built once and reused
# for all twelve data frames to avoid repeated allocation.
# -------------------------------------------------------------
{
  step_col_names <- as.character(0:(max_steps_ahead - 1))

  zero_step_columns <- as.data.frame(
    matrix(0, nrow = n_market, ncol = max_steps_ahead, dimnames = list(NULL, step_col_names))
  )

  market_commitments <- list(
    Elec_buy_plan_df            = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_sell_plan_df           = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_net_plan_df            = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_buy_plan_flex_df       = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_sell_plan_flex_df      = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_net_plan_flex_df       = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_flex_down_sell_plan_df = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_flex_down_buy_plan_df  = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_flex_up_sell_plan_df   = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_flex_up_buy_plan_df    = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_Cost_plan_df           = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_flex_Cost_plan_df      = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE)
  )

  rm(zero_step_columns, step_col_names, market_event_time, n_market)
}
