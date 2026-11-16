# -------------------------------------------------------------
# Function: price_estimate_sources.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Says, for every market interval of a market's optimization
# horizon, where its price is read from. Inside the control horizon
# the market publishes the price, and it is read as it is. Beyond
# it, the market has no price yet, and the price is estimated from
# what the markets already know, by these rules, in this order:
#   1. The price of the last earlier market that traded that
#      interval: the market that cleared most recently before this
#      one and whose control period holds the interval.
#   2. When no earlier market traded it, the price of the same
#      interval one day before: from this market, if its control
#      period holds that interval, or otherwise from the last
#      earlier market that traded it.
#   3. When neither gives a price, the mean of the prices of the
#      market's own control horizon.
# The rules only depend on the market structure, not on the price
# signal, so they are resolved once per market and applied to every
# signal by estimate_price_signal().
# -------------------------------------------------------------
# Earlier markets
# An earlier market is one that cleared strictly before this one,
# of either family, Scheduling or Piloting. It traded an interval
# when the interval starts at or after its Period_Begin and before
# its Period_End. The price it had for that interval is the one in
# its own row of the price matrices of full_market_information, at
# the column of that interval.
# -------------------------------------------------------------
# Inputs
#   target_times      : POSIXct vector. The market intervals of the
#                       optimization horizon, in order.
#   end_control_time  : POSIXct scalar. The last interval of the
#                       control horizon.
#   event_slot        : POSIXct scalar. The interval this market's
#                       clearing instant falls in
#                       (instant_market_slot()).
#   events            : Data frame. The market events of both
#                       families, as built by market_event_index():
#                       market_num, begins_num and ends_num, in
#                       seconds since the epoch.
#   market_resolution : Numeric scalar (min). Length of a market
#                       interval.
# -------------------------------------------------------------
# Outputs
#   Data frame, one row per entry of target_times, with:
#     - source      : character, one of
#                       - "published"
#                       - "earlier_market"
#                       - "day_before_current"
#                       - "day_before_earlier"
#                       - "current_mean"
#     - event_num   : numeric, the clearing interval of the earlier
#                     market to read, in seconds since the epoch;
#                     NA for the other sources
#     - column      : character, the column of the price matrices
#                     to read in that market's row; NA for the other
#                     sources
#     - current_pos : integer, the position in target_times of the
#                     interval one day before, for
#                     "day_before_current"; NA for the others
# -------------------------------------------------------------
# Code outline
# 1. Published intervals and earlier markets
# 2. Source of every interval beyond the control horizon
# -------------------------------------------------------------
# Usage instructions
# sources <- price_estimate_sources(target_times, end_control_time,
#                                   event_slot, events,
#                                   market_resolution)
# -------------------------------------------------------------
price_estimate_sources <- function(target_times,
                                   end_control_time,
                                   event_slot,
                                   events,
                                   market_resolution
                                   ) {

  # -------------------------------------------------------------
  # 1. Published intervals and earlier markets
  # -------------------------------------------------------------
  {
    slot_sec   <- market_resolution * 60
    target_num <- as.numeric(target_times)
    published  <- target_num <= as.numeric(end_control_time)

    earlier <- events[events$market_num < as.numeric(event_slot), ,
                      drop = FALSE]

    # The last earlier market whose control period holds the interval
    # that starts at slot_num, or NA when none does.
    last_market_with <- function(slot_num) {
      hit <- which(earlier$begins_num <= slot_num &
                     earlier$ends_num   >  slot_num)
      if (length(hit) == 0) {
        return(NA_real_)
      }
      return(max(earlier$market_num[hit]))
    }

    sources <- data.frame(
      source      = ifelse(published, "published", NA_character_),
      event_num   = NA_real_,
      column      = NA_character_,
      current_pos = NA_integer_,
      stringsAsFactors = FALSE
    )
  }

  # -------------------------------------------------------------
  # 2. Source of every interval beyond the control horizon
  # The rules of the header are tried in their order, and the first
  # one that gives a price is kept. The interval one day before is
  # the same time of day on the previous day.
  # -------------------------------------------------------------
  {
    for (CONT_001 in which(!published)) {

      market_num <- last_market_with(target_num[CONT_001])
      if (!is.na(market_num)) {
        sources$source[CONT_001]    <- "earlier_market"
        sources$event_num[CONT_001] <- market_num
        sources$column[CONT_001]    <- as.character(
          round((target_num[CONT_001] - market_num) / slot_sec))
        next
      }

      day_before <- target_num[CONT_001] - 86400
      own_pos    <- which(published & target_num == day_before)
      if (length(own_pos) == 1) {
        sources$source[CONT_001]      <- "day_before_current"
        sources$current_pos[CONT_001] <- own_pos
        next
      }

      market_num <- last_market_with(day_before)
      if (!is.na(market_num)) {
        sources$source[CONT_001]    <- "day_before_earlier"
        sources$event_num[CONT_001] <- market_num
        sources$column[CONT_001]    <- as.character(
          round((day_before - market_num) / slot_sec))
        next
      }

      sources$source[CONT_001] <- "current_mean"
    }

    rm(list = intersect(c("CONT_001", "market_num", "day_before",
                          "own_pos"), ls()))
  }

  rm(list = c("slot_sec", "target_num", "published", "earlier",
              "last_market_with"))

  return(sources)
}
