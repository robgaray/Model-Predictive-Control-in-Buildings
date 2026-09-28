# -------------------------------------------------------------
# Function: market_price_history.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Collects the values a price signal took, at the same time of day, in
# the markets of previous days, so that a forecast can be built from
# them.
# -------------------------------------------------------------
# Why a market and not just a timestamp
# A price is not a property of an hour: it is a property of an hour AS
# PUBLISHED BY A MARKET. The same hour has a different price in the day
# ahead market and in an intraday market, and that is the whole point of
# a multi market structure. A forecast of what a given market will pay
# for a given hour has to be built from what THAT market paid for that
# same hour on previous days, not from an average of every price that
# hour ever had.
# -------------------------------------------------------------
# The fallback rule
# A market does not publish a price for every hour: it publishes for the
# period it trades. When the market being forecast did not cover the
# time of day being looked for, the value is taken from the nearest
# EARLIER market that did cover it.
# The example in the assignment, which is also one of the test cases:
# market M25 trades H2 to H4, so it has a price for H3 but not for H1.
# To forecast H1, M24 is tried next, which trades H2 to H3 and does not
# cover it either, and then M23, which trades H0 to H3 and does. The
# value for H1 therefore comes from M23.
# -------------------------------------------------------------
# Inputs
#   target_time  : POSIXct scalar. The instant whose price is being
#                  forecast.
#   market_name  : Character scalar. Name of the market doing the
#                  forecasting, as it appears in Main_df's
#                  <role>_Market_Name column.
#   events       : Data frame. The market event index of the role, as
#                  built by market_event_index(): one row per market
#                  event, sorted by market_utc, with the columns:
#                    - market_utc
#                    - name
#                    - begins
#                    - ends It is supplied by the caller rather
#                  than built here because it does not depend on the
#                  instant nor on the signal, and this function is called
#                  once per instant and once per signal.
#   signal_df    : Data frame. One of the matrices of
#                  full_market_information, with a time column and one
#                  column per step ahead.
#   market_time  : POSIXct vector. The full market-resolution grid, used
#                  to resolve the step-ahead column of a lookup.
#   n_days_back  : Integer scalar. How many previous days to collect.
# -------------------------------------------------------------
# Outputs
#   Numeric vector, of length between 0 and n_days_back. The values
#   found, oldest last. Empty when no previous day yields a value, which
#   happens at the beginning of the series.
# -------------------------------------------------------------
# Code outline
# 1. Nothing to look up when the role has no market at all
# 2. For each previous day, find the market that covers the instant
# 3. Read the value from the signal matrix
# -------------------------------------------------------------
# Usage instructions
# vals <- market_price_history(target_time, market_name, events,
#                              signal_df, market_time, n_days_back)
# -------------------------------------------------------------
# Where this function/script is used
# Called by imperfect_price_forecast(), once per instant to forecast.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - A day with no market of that role at all contributes nothing, and
#     the returned vector is simply shorter. It is not an error: the
#     first days of a series have no history behind them.
#   - The fallback walks back over market EVENTS, not over days: it
#     looks for the latest market event of the role whose traded period
#     covers the instant and whose bid time is not later than the one
#     being forecast. If none does, that day contributes nothing.
#   - The step-ahead column is resolved against market_time, the full
#     market-resolution grid, exactly as the rest of the price lookups
#     do. An instant that falls outside the columns available for that
#     market event contributes nothing.
# -------------------------------------------------------------
# functions/scripts called
#   (none) - the market event index it works on is built by
#   market_event_index() and supplied by the caller.
# -------------------------------------------------------------
market_price_history <- function(target_time,
                                 market_name,
                                 events,
                                 signal_df,
                                 market_time,
                                 n_days_back) {

  # 1. Nothing to look up when the role has no market at all
  # -------------------------------------------------------------
  if (nrow(events) == 0) {
    return(numeric(0))
  }

  # 2. For each previous day, find the market that covers the instant
  # -------------------------------------------------------------
  {
    values <- numeric(0)

    # Everything this loop compares is resolved to seconds since the
    # epoch, once, before it starts. The loop runs once per day of
    # history, per instant to forecast and per price signal, so building
    # a POSIXct inside it costs more than all the rest of the lookup
    # together: the conversions alone were a third of the runtime of a
    # simulation at production n_days_back.
    grid_sec        <- as.numeric(market_time[2]) - as.numeric(market_time[1])
    market_time_num <- as.numeric(market_time)
    signal_time_num <- as.numeric(signal_df$time)
    target_num      <- as.numeric(target_time)
    is_same_name    <- events$name == market_name

    for (CONT_001 in seq_len(n_days_back)) {

      past_num <- target_num - CONT_001 * 86400

      # The market of the same name on that day, if it covers the
      # instant; otherwise the nearest earlier market of the role that
      # does. Both conditions are applied at once: covering the instant
      # and having cleared no later than the market of the same name.
      same_name <- which(is_same_name & events$market_num <= past_num)

      if (length(same_name) == 0) next
      reference_num <- max(events$market_num[same_name])

      candidates <- which(events$market_num <= reference_num &
                            events$begins_num <= past_num &
                            events$ends_num   >= past_num)

      if (length(candidates) == 0) next
      chosen <- candidates[which.max(events$market_num[candidates])]

      # 3. Read the value from the signal matrix
      # -----------------------------------------------------------
      # The row is the chosen market event and the column is how many
      # market-resolution steps ahead the instant is from it.
      # -----------------------------------------------------------
      row_m <- match(events$market_num[chosen], signal_time_num)
      if (is.na(row_m)) next

      step_target <- match(floor(past_num / grid_sec) * grid_sec, market_time_num)
      step_event  <- match(events$market_num[chosen], market_time_num)
      if (is.na(step_target) || is.na(step_event)) next

      col_j <- as.character(step_target - step_event)
      if (!col_j %in% names(signal_df)) next

      values <- c(values, signal_df[[col_j]][row_m])

      rm(past_num, same_name, reference_num, candidates, chosen, row_m,
         step_target, step_event, col_j)
    }

    rm(list = intersect(c("CONT_001", "grid_sec", "market_time_num",
                          "signal_time_num", "target_num", "is_same_name"), ls()))
  }

  return(values)
}
