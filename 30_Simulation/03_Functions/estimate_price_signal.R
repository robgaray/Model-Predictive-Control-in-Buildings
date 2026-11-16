# -------------------------------------------------------------
# Function: estimate_price_signal.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the price a market sees for each interval of its
# optimization horizon, for one price signal. Inside the control
# horizon it keeps the published price. Beyond it, it reads the
# price from the source price_estimate_sources() chose for each
# interval:
#   - an earlier market that traded the interval, or that traded
#     the same interval one day before: the value in that market's
#     row of the price matrix;
#   - this market's own price for the same interval one day before;
#   - the mean of this market's published prices.
# -------------------------------------------------------------
# Inputs
#   values    : Numeric vector, one entry per interval of the
#               optimization horizon. The prices of this market; only
#               those of the control horizon are read.
#   signal_df : Data frame. The price matrix of the signal, one of
#               full_market_information: a time column with the
#               clearing interval of each market and one column per
#               step ahead.
#   sources   : Data frame, as returned by price_estimate_sources(),
#               one row per entry of values.
# -------------------------------------------------------------
# Outputs
#   Numeric vector, the same length as values: the price of each
#   interval as the market sees it.
# -------------------------------------------------------------
# Code outline
# 1. Check the inputs
# 2. Read each interval from its source
# -------------------------------------------------------------
# Usage instructions
# P_import_buy_by_market <- estimate_price_signal(
#   P_import_buy_by_market,
#   full_market_information$Elec_unit_cost_import_buy_df,
#   sources)
# -------------------------------------------------------------
estimate_price_signal <- function(values,
                                  signal_df,
                                  sources
                                  ) {

  # -------------------------------------------------------------
  # 1. Check the inputs
  # -------------------------------------------------------------
  {
    if (length(values) != nrow(sources)) {
      stop("estimate_price_signal: values and sources must describe ",
           "the same intervals.")
    }
    if (!any(sources$source == "published")) {
      stop("estimate_price_signal: the market has no published price ",
           "to estimate from.")
    }
  }

  # -------------------------------------------------------------
  # 2. Read each interval from its source
  # -------------------------------------------------------------
  {
    estimated <- values

    from_market <- which(sources$source %in%
                           c("earlier_market", "day_before_earlier"))
    if (length(from_market) > 0) {
      market_row <- match(sources$event_num[from_market],
                          as.numeric(signal_df$time))
      missing_column <- !sources$column[from_market] %in% names(signal_df)
      if (anyNA(market_row) || any(missing_column)) {
        stop("estimate_price_signal: an earlier market has no price ",
             "for an interval it traded. The price matrices of ",
             "full_market_information do not reach it.")
      }
      # .subset2() reads each column without the method of data
      # frames.
      for (CONT_001 in seq_along(from_market)) {
        estimated[from_market[CONT_001]] <- .subset2(
          signal_df, sources$column[from_market[CONT_001]]
        )[market_row[CONT_001]]
      }
      rm(list = c("market_row", "missing_column"))
    }

    from_own <- which(sources$source == "day_before_current")
    estimated[from_own] <- values[sources$current_pos[from_own]]

    from_mean <- which(sources$source == "current_mean")
    estimated[from_mean] <- mean(values[sources$source == "published"])

    rm(list = intersect(c("CONT_001", "from_market", "from_own",
                          "from_mean"), ls()))
  }

  return(estimated)
}
