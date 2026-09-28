# -------------------------------------------------------------
# Function: market_event_index.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the index of market events of one role: one entry per market
# event, with its own market interval, its name and the period it
# trades, sorted by market interval.
# -------------------------------------------------------------
# Why it is a function of its own
# The index depends only on Main_df and the role, never on the instant
# being forecast nor on the price signal being read.
# market_price_history() used to rebuild it on every call, and it is
# called once per instant and once per price signal, so the same scan of
# Main_df was repeated thousands of times per market execution. Building
# it once per forecast and passing it down is what makes the price
# forecast affordable; it is the same change imperfect_forecast() got
# for the weather history.
# -------------------------------------------------------------
# Inputs
#   Main_df : Data frame. Must carry the market timeline columns
#             <role>_Market_Name, <role>_Market_Period_Begin and
#             <role>_Market_Period_End, plus MarketUTC.
#   role    : Character scalar, "Sched" or "Pilot". Which of the two
#             market families the index is built for.
# -------------------------------------------------------------
# Outputs
#   Data frame with one row per market event of the role, sorted by
#   market_utc, and the columns:
#     - market_utc
#     - market_num
#     - name
#     - begins_num
#     - ends_num The three "_num" columns are seconds since the epoch:
#   the caller compares them against instants inside its own loop, and
#   doing that arithmetic on numbers rather than on POSIXct is what keeps
#   the lookup cheap. market_utc stays POSIXct because it is matched
#   against the time column of the price matrices. Zero rows when the
#   role has no active market at all, which callers treat as "no history
#   available" rather than as an error.
# -------------------------------------------------------------
# Code outline
# 1. Resolve the role's timeline columns
# 2. Keep the rows where a market of that role is active
# 3. One row per market event, sorted
# -------------------------------------------------------------
# Usage instructions
# events <- market_event_index(Main_df, role)
# -------------------------------------------------------------
# Where this function/script is used
# Called by imperfect_price_forecast(), once per forecast, and passed
# from there into market_price_history().
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - An inactive market is written as 0 in the name column, so the
#     filter tests against "0" and 0 rather than calling
#     is_market_active(): this runs inside the optimizer's inner loop
#     and a vectorised test on the raw column is enough.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
market_event_index <- function(Main_df, role) {

  # 1. Resolve the role's timeline columns
  # -------------------------------------------------------------
  {
    col_name  <- paste0(role, "_Market_Name")
    col_begin <- paste0(role, "_Market_Period_Begin")
    col_end   <- paste0(role, "_Market_Period_End")

    missing_cols <- c(col_name, col_begin, col_end)[
      !c(col_name, col_begin, col_end) %in% names(Main_df)]
    if (length(missing_cols) > 0) {
      stop("market_event_index: Main_df is missing required columns: ",
           paste(missing_cols, collapse = ", "))
    }
  }

  # 2. Keep the rows where a market of that role is active
  # -------------------------------------------------------------
  {
    active_rows <- which(!is.na(Main_df[[col_name]]) &
                           Main_df[[col_name]] != "0" &
                           Main_df[[col_name]] != 0)

    if (length(active_rows) == 0) {
      return(data.frame(market_utc = Main_df$MarketUTC[0],
                        market_num = numeric(0),
                        name       = character(0),
                        begins_num = numeric(0),
                        ends_num   = numeric(0),
                        stringsAsFactors = FALSE))
    }
  }

  # 3. One row per market event, sorted
  # -------------------------------------------------------------
  {
    # The period bounds are stored in Main_df as text, the way
    # build_market_timeline() writes them, and they are parsed here once.
    # Comparing text against a POSIXct makes R parse the whole column on
    # every comparison, and building a POSIXct per day and per instant
    # inside the caller's loop costs as much again: between them they
    # were a third of the runtime of a simulation. Everything the caller
    # compares is therefore handed over as seconds since the epoch.
    events <- data.frame(
      market_utc = Main_df$MarketUTC[active_rows],
      market_num = as.numeric(Main_df$MarketUTC[active_rows]),
      name       = as.character(Main_df[[col_name]][active_rows]),
      begins_num = as.numeric(as.POSIXct(Main_df[[col_begin]][active_rows], tz = "UTC")),
      ends_num   = as.numeric(as.POSIXct(Main_df[[col_end]][active_rows], tz = "UTC")),
      stringsAsFactors = FALSE
    )
    events <- events[!duplicated(events$market_utc), ]
    events <- events[order(events$market_utc), ]
  }

  rm(col_name, col_begin, col_end, missing_cols, active_rows)

  return(events)
}
