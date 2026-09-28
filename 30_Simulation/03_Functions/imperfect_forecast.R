# -------------------------------------------------------------
# Function: imperfect_forecast.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds a deliberately inaccurate forecast of a weather column over a
# horizon, as a blend of two things:
#   A. The actual future value (ground truth).
#   B. A historical average: the same time of day on each of the
#      previous n_days_back days.
# The weight of the history grows with how far ahead the instant is, so
# the forecast degrades the further it looks. The aim is NOT to
# forecast well. It is to forecast with a controlled amount of error.
# -------------------------------------------------------------
# The law of the weight
#   w(t) = min(1, weight_history * hours_ahead(t) / 24)
#   forecast(t) = (1 - w) * actual(t) + w * history(t)
# where hours_ahead is counted from the first instant of the horizon.
# The weight is therefore a rate: weight_history is the weight the
# history carries one day ahead, two times that two days ahead, and so
# on, capped at 1, where the forecast is the historical average alone.
# -------------------------------------------------------------
# Why the error is normalised per day and not per horizon
# A law normalised by the length of the horizon makes the error of an
# instant depend on which market is looking at it: with the production
# configuration the same instant twelve hours ahead would carry one
# third of the weight seen from a 36 h Scheduling horizon and the full
# weight seen from a 12 h Piloting one. The error of a forecast is a
# property of how far ahead it looks, not of who is looking, so the
# weight is counted per day of horizon and every market that values the
# same instant values it with the same error.
# -------------------------------------------------------------
# Inputs
#   Main_df                 : Data frame with the full time series data.
#                             Must contain the columns referenced by target_col
#                             and time_col.
#   target_col              : Character. Name of the column in Main_df to forecast
#                             (e.g. "Text" or "SolarR").
#   i0                      : Integer. Start index of the forecast horizon in Main_df.
#   i_end_horizon           : Integer. End index of the forecast horizon in Main_df.
#   n_days_back             : Integer. Number of previous days used to compute the
#                             historical average for each forecast step.
#   weather_forecast_weight_history : Numeric (0-1). Weight the history
#                             carries one day ahead of the start of the
#                             horizon. At i0 the weight is 0 and the
#                             forecast is the actual value; it grows
#                             linearly at this rate and is capped at 1.
#   time_col                : Character. Name of the time column in Main_df.
#                             Default: "time".
# -------------------------------------------------------------
# Outputs
#   A tibble with two columns:
#     time              : POSIXct. Time index of the forecasted values,
#                         matching Main_df[[time_col]][i0:i_end_horizon].
#     pred_<target_col> : Numeric. Forecasted values of the target column.
#                         Column name is constructed as paste0("pred_", target_col).
# -------------------------------------------------------------
# Code outline
# 1. Horizon, actual values and hours ahead
# 2. Historical average of each instant
# 3. Blend
# -------------------------------------------------------------
# Usage instructions
# forecast_df <- imperfect_forecast(Main_df, target_col = "Text",
#   i0 = i0, i_end_horizon = i_end_horizon, n_days_back = n_days_back,
#   weather_forecast_weight_history = 0.3, time_col = "time")
# -------------------------------------------------------------
# Where this function/script is used
# Called by context_forecast_step(), once for Text and once for SolarR,
# before every market process of the simulation.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - An instant with no history at all keeps its actual value, and the
#     console says how many instants that happened to. It means the
#     series does not reach n_days_back days behind the horizon, which
#     with the stabilization sized by that same parameter should not
#     happen; and it makes the forecast of those instants exact, so it
#     must not pass unnoticed.
#   - An actual value that is NA takes the historical average, whatever
#     the weight.
#   - The history of one instant averages only the days that were
#     found: a missing day lowers the count, it does not void the
#     average.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

imperfect_forecast <- function(Main_df,
                               target_col,
                               i0,
                               i_end_horizon,
                               n_days_back,
                               weather_forecast_weight_history,
                               time_col = "time") {

  # 1. Horizon, actual values and hours ahead
  # -------------------------------------------------------------
  {
    range          <- i0:i_end_horizon
    forecast_steps <- length(range)

    # The time column is read as seconds once. Every lookup below is a
    # match() on this vector, which is what keeps the cost of the whole
    # function independent of the length of Main_df.
    time_num       <- as.numeric(Main_df[[time_col]])
    values         <- Main_df[[target_col]]

    forecast_times <- Main_df[[time_col]][range]
    actual         <- values[range]

    hours_ahead    <- (time_num[range] - time_num[i0]) / 3600
  }

  # 2. Historical average of each instant
  # -------------------------------------------------------------
  {
    past <- matrix(
      vapply(seq_len(n_days_back), function(day_back) {
        values[match(time_num[range] - day_back * 86400, time_num)]
      }, numeric(forecast_steps)),
      nrow = forecast_steps
    )

    days_found <- rowSums(!is.na(past))
    hist_mean  <- ifelse(days_found > 0, rowMeans(past, na.rm = TRUE), actual)

    if (any(days_found == 0)) {
      cat("WARNING: imperfect_forecast(", target_col, "): ",
          sum(days_found == 0), " of ", forecast_steps,
          " instants found no history and keep their actual value\n", sep = "")
    }
  }

  # 3. Blend
  # -------------------------------------------------------------
  {
    w <- pmin(1, weather_forecast_weight_history * hours_ahead / 24)

    forecasts <- ifelse(
      is.na(actual),
      hist_mean,
      (1 - w) * actual + w * hist_mean
    )

    result <- tibble(
      time     = forecast_times,
      forecast = forecasts
    )
    colnames(result)[2] <- paste0("pred_", target_col)
  }

  rm(range, forecast_steps, time_num, values, forecast_times, actual,
     hours_ahead, past, days_found, hist_mean, w, forecasts)

  return(result)
}
