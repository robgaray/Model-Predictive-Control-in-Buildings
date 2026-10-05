# -------------------------------------------------------------
# Script: 12_market_commitments_setup.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Initialises the market output matrices that record, per market
# step, what the Scheduling and Piloting processes produce:
#   - the energy commitments (buy, sell and net)
#   - the flexibility commitments
#   - the accumulated differential costs
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
# Each leg has its own committed volume, and both are non-negative by
# construction: Main_df$Elec_flex_down_plan = Elec_total_plan -
# Elec_total_plan_flex_down over the Commitment Phase, the load the building
# commits to shed, and Main_df$Elec_flex_up_plan =
# Elec_total_plan_flex_up - Elec_total_plan over its own Commitment Phase,
# the load it commits to add. Each is recorded on its own pair of
# matrices; neither is read off the sign of the other.
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
# 11_full_market_information_setup.R; it is recomputed here as a
# safeguard if absent, using the same dynamic horizon derived from
# parameters$market_config_scheduling and
# parameters$market_config_piloting.
# Sourced from Main.R, right after 11_full_market_information_setup.R.
# -------------------------------------------------------------
# Inputs
#   Main_df, whose market columns say where a market clears.
#   parameters$market : the resolution and the horizons that size
#     the matrices.
# -------------------------------------------------------------
# Outputs
#   market_commitments, a list of matrices with one row per market
#     event and one column per step ahead, holding:
#       - the energy bought, sold and net
#       - the two flexibility legs
#       - the accumulated differential cost
# -------------------------------------------------------------
# Code outline
# 1. Locate the rows where a market actually clears.
# 2. Create every matrix at zero, sized by those rows and by the
#    furthest horizon any market looks at.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by Main.R before the simulation loop,
#   which fills these matrices market by market.
# -------------------------------------------------------------
# Where this function/script is used
# Sourced by 30_Simulation/Main.R.
# -------------------------------------------------------------
# functions/scripts called
#   compute_max_steps_ahead() - the number of steps ahead of the
#                        furthest-looking market, when it is not
#                        set yet
#   is_market_active() - says whether a market name marks an
#                        active market
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
    # compute_max_steps_ahead is called to size the future-step columns
    # when 11_full_market_information_setup.R has not done it.
    max_steps_ahead <- compute_max_steps_ahead(parameters)
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
    Elec_buy_plan_flex_down_df       = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_sell_plan_flex_down_df      = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_net_plan_flex_down_df       = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_flex_down_sell_plan_df = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_flex_down_buy_plan_df  = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_flex_up_sell_plan_df   = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_flex_up_buy_plan_df    = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_Cost_plan_df           = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE),
    Elec_flex_Cost_plan_df      = data.frame(time = market_event_time, zero_step_columns, check.names = FALSE)
  )

  rm(zero_step_columns, step_col_names, market_event_time, n_market)
}
