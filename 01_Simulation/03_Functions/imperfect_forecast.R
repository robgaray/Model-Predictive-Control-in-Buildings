# -------------------------------------------------------------
# Function: imperfect_forecast.R
# Part of the Model Predictive Control in buildings repository
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Generates imperfect (weather) forecasts
# This function gets a time series of a particular variable for
# a long timespan and performs a fictive forecasts of this variable.
# The fictive forecast consist on a weighted sum of two terms:
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
# Inputs:
#   Main_df: Dataframe with the full time series data
#   target_col: Name of the target column to forecast
#   i0: Index of the start of the forecast horizon in Main_df
#   i_end_horizon: Index of the end of the forecast horizon in Main_df
#   n_days_back: Number of previous days to consider for the historical average
#   forecast_weight_history: Weight of the historical average at the end of the horizon
#   time_col: Name of the time column in Main_df (default: "time")
# -------------------------------------------------------------
# Outputs:
#   A tibble with two columns:
#     time: Time index of the forecasted values
#     pred_<target_col>: Forecasted values of the target column
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
  for (k in 1:forecast_steps) {
    # Current step
    current_idx   <- range[k]
    current_time  <- Main_df[[time_col]][current_idx]
    
    # Actual value (Ground Truth)
    actual_val    <- Main_df[[target_col]][current_idx]
    
    # Historical Average (Average of same hour in preceding days)
    {
      # collects all previous values
      historical_values <- c()
      for (d in 1:n_days_back) {
        target_past_time <- current_time - days(d)
        
        # Takes past values for day d
        past_val <- Main_df[[target_col]][Main_df[[time_col]] == target_past_time]
        
        # Adds it to the list of historical values only if there was a successful match
        if (length(past_val) > 0) {
          historical_values <- c(historical_values, past_val[1])
        }
      }
      
      # Calculates the averagee of historical values
      # If there are no historical values, the actual value is used. THis is needed for the initial days in the time series.
      hist_mean <- if (length(historical_values) > 0) {
        mean(historical_values, na.rm = TRUE)
      } else {
        actual_val
      }
    }
    
    # calculation of specific weight 'w'. This rises over time
    # k=1 (i0): 100% actual_val
    # k=forecast_steps (i_end_horizon): forecast_weight_history
    if (forecast_steps > 1) {
      w <- 1.0 - (1.0 - forecast_weight_history) * ((k - 1) / (forecast_steps - 1))
    } else {
      w <- 1.0
    }
    
    # Blending of historical value and actual value with weight
    if (is.na(actual_val)) {
      # In the case where the actual value does not exist (should not happen)
      forecasts[k] <- hist_mean
    } else {
      forecasts[k] <- ((1-w) * actual_val) + (w * hist_mean)
    }
  }
  
  # Output formatting
  result <- tibble(
    time = forecast_times,
    forecast = forecasts
  )
  colnames(result)[2] <- paste0("pred_", target_col)
  
  return(result)
}