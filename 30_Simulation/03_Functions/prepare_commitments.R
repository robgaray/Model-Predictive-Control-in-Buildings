# -------------------------------------------------------------
# Function: prepare_commitments.R
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
# Every row corresponds to a market event (a row of Main_df where a
# Scheduling or Piloting market actually clears, i.e.
# Main_df$Sched_Market_Name or Main_df$Pilot_Market_Name is active
# there), keyed by the market interval its clearing instant falls in
# (instant_market_slot()), and every future-step column holds the
# value committed for the market-resolution interval that many steps
# ahead of that event.
# Twelve data frames are created, each with one row per market event
# (column 'time') and one column per future step ahead, named "0"
# (the event's own interval) to as.character(max_steps_ahead - 1).
# All future-step cells are initialised to 0 (double); they are
# filled later by the market integration logic. Since the energy
# signals are aggregated by sum over each MarketUTC interval, the
# committed value written to an interval is the sum of the
# underlying commitments. The twelve data frames are bundled into a
# single named list, market_commitments (e.g.
# market_commitments$Elec_net_plan_df), which is what the function
# returns.
# max_steps_ahead is the same horizon that prepare_market_information()
# uses, derived from the market configuration by
# compute_max_steps_ahead().
# -------------------------------------------------------------
# Inputs
#   Main_df                  : data frame, with MarketUTC and the
#                              market columns that say where a market
#                              clears.
#   market_events            : Data frame. The market events of the
#                              run, as build_market_events() returns
#                              them. Uses event_slot.
#   market                   : List, parameters$market. The
#                              resolution and the horizons that size
#                              the matrices.
#   market_config_scheduling : data frame,
#                              parameters$market_config_scheduling,
#                              the markets of the complex mode.
#   market_config_piloting   : data frame,
#                              parameters$market_config_piloting,
#                              the markets of the complex mode.
# -------------------------------------------------------------
# Outputs
#   market_commitments, a list of matrices with one row per market
#   event and one column per step ahead, holding:
#     - the energy bought, sold and net
#     - the two flexibility legs
#     - the accumulated differential cost
# -------------------------------------------------------------
# Code outline
# 1. Locate the rows where a market actually clears.
# 2. Create every matrix at zero, sized by those rows and by the
#    furthest horizon any market looks at, each with columns of its
#    own.
# -------------------------------------------------------------
# Usage instructions
# market_commitments <- prepare_commitments(
#   Main_df                  = Main_df,
#   market                   = parameters$market,
#   market_config_scheduling = parameters$market_config_scheduling,
#   market_config_piloting   = parameters$market_config_piloting
# )
# -------------------------------------------------------------
prepare_commitments <- function(Main_df,
                                market_events,
                                market,
                                market_config_scheduling,
                                market_config_piloting
                                ) {

  # -------------------------------------------------------------
  # 1. Furthest horizon and market-event rows (sparse)
  # -------------------------------------------------------------
  # Works out max_steps_ahead and checks that the Main_df$MarketUTC
  # column exists, then builds market_event_time (the sorted unique
  # intervals where a Scheduling or Piloting market actually clears,
  # keyed as in prepare_market_information()) and n_market, which
  # define the rows of every output matrix.
  # -------------------------------------------------------------
  {
    # compute_max_steps_ahead is called to size the future-step columns
    # from the market configuration in use: the basic Scheduling and
    # Piloting markets, or the market tables in complex mode.
    max_steps_ahead <- compute_max_steps_ahead(
      market                   = market,
      market_config_scheduling = market_config_scheduling,
      market_config_piloting   = market_config_piloting
    )

    if (!"MarketUTC" %in% names(Main_df)) {
      stop("prepare_commitments: Main_df$MarketUTC is required. ",
           "It is assigned by prepare_market_calendar().")
    }

    # The rows are the intervals where a Scheduling or Piloting market
    # actually clears, read from the table of the market events.
    market_event_time <- sort(unique(market_events$event_slot))
    n_market          <- length(market_event_time)
  }

  # -------------------------------------------------------------
  # 2. Initialise the market output data frames to zero
  # -------------------------------------------------------------
  # Twelve data frames are created, each sized (n_market x
  # (1 + max_steps_ahead)): a 'time' column (the market-event
  # intervals) plus max_steps_ahead future-step columns, initialised
  # to 0 (double). A single zero template is built once for all
  # twelve data frames, and they are then copied so that none of them
  # shares a column with another.
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

    # The twelve data frames share the column vectors of the template.
    # The simulation loop adds to their cells in place
    # (add_to_table_cells()), so each data frame gets columns of its
    # own: data.table::copy() copies every column of every data frame.
    market_commitments <- data.table::copy(market_commitments)

    rm(list = c("zero_step_columns", "step_col_names", "market_event_time",
                "n_market", "max_steps_ahead"))
  }

  return(market_commitments)
}
