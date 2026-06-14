# -------------------------------------------------------------
# Function: imperfect_forecast.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Generates imperfect (weather) forecasts.
# This function gets a time series of a particular variable for
# a long timespan and performs a fictive forecast of this variable.
# The fictive forecast consists of a weighted sum of two terms:
#   A. The actual future value (Ground Truth)
#   B. A robust historical average (same hour in previous days)
# The weight of the historical average increases linearly along
# the forecast horizon.
# By doing so, the forecast progressively deviates from the actual
# value, resulting in an increasingly inaccurate prediction.
# The outcome of this function is used to introduce uncertainty
# in the building performance forecasts due to imperfect
# (meteorological) predictions.
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
#   forecast_weight_history : Numeric (0-1). Weight assigned to the historical
#                             average at the far end of the horizon (step
#                             i_end_horizon). At step i0 the weight is always 1.0
#                             (100% ground truth). The weight increases linearly
#                             from 1.0 (at i0) toward forecast_weight_history
#                             (at i_end_horizon).
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
# 1. Identify forecast range
# 2. Build forecast by averaging past observations
# 3. Apply weighting between historical average and persistence
# -------------------------------------------------------------
# Usage instructions
# forecast_df <- imperfect_forecast(i0, time_sec, Main_df, parameters, i_end_horizon)
# -------------------------------------------------------------
# Where this function/script is used
# Called by context_forecast_step.R when forecast_type is "inaccurate".
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If no historical values are found for a given step (e.g. at the very
#     start of the series where fewer than n_days_back days of data exist),
#     the actual (ground-truth) value is used as the historical mean, so
#     the forecast is equivalent to the accurate forecast for those steps.
#   - If the actual value at a given step is NA (should not normally occur),
#     the historical mean is used directly as the forecast.
#   - If forecast_steps == 1 (single-step horizon), the weight w is fixed at
#     1.0, meaning the actual value is always used regardless of
#     forecast_weight_history.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
imperfect_forecast <- function(Main_df,
                               target_col,
                               i0,
                               i_end_horizon,
                               n_days_back,
                               forecast_weight_history,
                               time_col = "time") {
  
  # Prediction range
  range           <- i0:i_end_horizon
  forecast_steps  <- length(range)
  
  # Initialize results
  forecasts       <- numeric(forecast_steps)
  forecast_times  <- Main_df[[time_col]][range]
  
  # Process for each forecast step
  for (CONT_001 in 1:forecast_steps) {
    # Current step
    current_idx   <- range[CONT_001]
    current_time  <- Main_df[[time_col]][current_idx]
    
    # Actual value (Ground Truth)
    actual_val    <- Main_df[[target_col]][current_idx]
    rm(current_idx)
    
    # Historical Average (Average of same hour in preceding days)
    {
      # collects all previous values
      historical_values <- c()
      for (CONT_002 in 1:n_days_back) {
        target_past_time <- current_time - days(CONT_002)
        
        # Takes past values for day d
        past_val <- Main_df[[target_col]][Main_df[[time_col]] == target_past_time]
        rm(target_past_time)
        
        # Adds it to the list of historical values only if there was a successful match
        if (length(past_val) > 0) {
          historical_values <- c(historical_values, past_val[1])
        }
        rm(past_val)
      }
      
    # Calculates the average of historical values.
      # If there are no historical values, the actual value is used.
      # This is needed for the initial days in the time series.
      hist_mean <- if (length(historical_values) > 0) {
        mean(historical_values, na.rm = TRUE)
      } else {
        actual_val
      }
      rm(historical_values)
    }
    
    # calculation of specific weight 'w'. This rises over time
    # k=1 (i0): 100% actual_val
    # k=forecast_steps (i_end_horizon): forecast_weight_history
    if (forecast_steps > 1) {
      w <- 1.0 - (1.0 - forecast_weight_history) * ((CONT_001 - 1) / (forecast_steps - 1))
    } else {
      w <- 1.0
    }
    
    # Blending of historical value and actual value with weight
    if (is.na(actual_val)) {
      # In the case where the actual value does not exist (should not happen)
      forecasts[CONT_001] <- hist_mean
    } else {
      forecasts[CONT_001] <- ((1-w) * actual_val) + (w * hist_mean)
    }
    rm(current_time, actual_val, hist_mean, w)
  }
  
  # Output formatting
  result <- tibble(
    time = forecast_times,
    forecast = forecasts
  )
  rm(range, forecast_steps, forecasts, forecast_times)
  colnames(result)[2] <- paste0("pred_", target_col)
  
  return(result)
}