# -------------------------------------------------------------
# Function: imperfect_price_forecast.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds an imperfect forecast of a price signal for the stretch of the
# optimization horizon that lies beyond the control horizon.
# -------------------------------------------------------------
# Why it exists
# A market publishes prices for the period it trades, which is the
# control horizon. The optimizer, however, decides over the whole
# optimization horizon, and it has to value the energy of that longer
# stretch too. Reading the true price of those later hours straight from
# the data structures would give the optimizer information it cannot
# have when it decides: perfect foresight. This function replaces that
# reading with a forecast which is deliberately inaccurate, so that the
# error has to be corrected later, in subsequent markets.
# The aim is NOT to forecast well. It is to forecast with a controlled
# amount of error.
# -------------------------------------------------------------
# Same formulation as the weather forecast
# The blend is the one imperfect_forecast() uses for Text and SolarR: a
# weighted sum of the true future value and a historical average of the
# same time of day on previous days, with the weight of the history
# growing at weight_history per day of forecast horizon, so that the
# forecast degrades the further ahead it looks:
#   w(t) = min(1, weight_history * hours_ahead(t) / 24)
# The error of a forecast is a property of how far ahead it looks and
# not of the length of the stretch it belongs to, which is why the
# weight is counted per day and not per stretch.
# Two things differ, and both come from prices not being a flat column
# of Main_df:
#   - The history is collected by market_price_history(), which follows
#     the market structure and its fallback rule, instead of averaging
#     the same column on previous days.
#   - The stretch to forecast starts at the END of the control horizon,
#     not at the start of the horizon. Inside the control horizon the
#     price is published and is used as it is, which is the weight-1 end
#     of the same law.
# -------------------------------------------------------------
# Inputs
#   target_times : POSIXct vector. The instants to forecast, in order.
#                  Those at or before end_control_time are returned
#                  untouched.
#   true_values  : Numeric vector, same length. The price each instant
#                  actually has in the data structures.
#   end_control_time : POSIXct scalar. Close of the control horizon. The
#                  forecast starts after it.
#   The following are passed straight through to
#   market_price_history(); see that function's header:
#     - market_name
#     - role
#     - signal_df
#     - Main_df
#     - market_time
#   n_days_back  : Integer scalar. Days of history.
#   weight_history : Numeric in [0, 1]. Weight of the historical average
#                  at the far end of the forecast stretch. At its start
#                  the weight is 0, that is, the true value.
# -------------------------------------------------------------
# Outputs
#   Numeric vector, same length as target_times. The price the optimizer
#   is allowed to see for each instant.
# -------------------------------------------------------------
# Code outline
# 1. Split the instants into published and forecast
# 2. Blend, instant by instant, along the forecast stretch
# -------------------------------------------------------------
# Usage instructions
# p <- imperfect_price_forecast(target_times, true_values, end_control_time,
#        market_name, role, signal_df, Main_df, market_time,
#        n_days_back, weight_history)
# -------------------------------------------------------------
# Where this function/script is used
# Called by resolve_marginal_context(), once per price signal, to fill
# the valuation intervals that lie beyond the control horizon.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - An instant with no history at all keeps its true value. It happens
#     at the beginning of the series, when there are no previous days to
#     look at, and it is the same fallback imperfect_forecast() takes.
#   - The first instant beyond the control horizon carries weight 0 and
#     is therefore exact: hours_ahead is counted from the close of the
#     control horizon, which is where the published price stops and the
#     forecast starts.
#   - Nothing at or before end_control_time is ever touched: inside the
#     control horizon the market has published a price and the optimizer
#     is entitled to it.
# -------------------------------------------------------------
# functions/scripts called
#   market_event_index() - the role's market event index, built once per
#                          forecast and reused for every instant
#   market_price_history() - values of the same time of day in the
#                            markets of previous days
# -------------------------------------------------------------
imperfect_price_forecast <- function(target_times,
                                     true_values,
                                     end_control_time,
                                     market_name,
                                     role,
                                     signal_df,
                                     Main_df,
                                     market_time,
                                     n_days_back,
                                     weight_history) {

  # 1. Split the instants into published and forecast
  # -------------------------------------------------------------
  {
    forecast_idx <- which(target_times > end_control_time)

    if (length(forecast_idx) == 0) {
      return(true_values)
    }

    forecast_values <- true_values
    n_forecast      <- length(forecast_idx)
  }

  # 2. Blend, instant by instant, along the forecast stretch
  # -------------------------------------------------------------
  # The weight of the history grows at weight_history per day from 0 at
  # the close of the control horizon, which is the law imperfect_forecast()
  # applies from the start of its own horizon. Counting the hours from
  # the close and not from the market instant is what keeps the first
  # forecast instant exact: inside the control horizon the price is
  # published, and the forecast begins where that stops.
  # -------------------------------------------------------------
  {
    # The market event index depends on Main_df and the role alone, not
    # on the instant being forecast, so it is built once here instead of
    # once per instant inside market_price_history(). Rebuilding it in
    # the loop scanned the whole of Main_df thousands of times per market
    # execution and was what made the price forecast the dominant cost of
    # a run at production n_days_back.
    events <- market_event_index(Main_df, role)

    for (CONT_001 in seq_len(n_forecast)) {

      idx <- forecast_idx[CONT_001]

      history <- market_price_history(
        target_time = target_times[idx],
        market_name = market_name,
        events      = events,
        signal_df   = signal_df,
        market_time = market_time,
        n_days_back = n_days_back
      )

      if (length(history) == 0) next

      hist_mean <- mean(history, na.rm = TRUE)
      if (is.na(hist_mean)) next

      hours_ahead <- as.numeric(
        difftime(target_times[idx], end_control_time, units = "hours")
      )

      w <- min(1, weight_history * hours_ahead / 24)

      forecast_values[idx] <- (1 - w) * true_values[idx] + w * hist_mean

      rm(idx, history, hist_mean, hours_ahead, w)
    }

    rm(list = intersect(c("CONT_001", "events"), ls()))
  }

  rm(forecast_idx, n_forecast)

  return(forecast_values)
}
