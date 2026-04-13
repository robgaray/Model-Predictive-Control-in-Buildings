# -------------------------------------------------------------
# Function: context_forecast_step.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function extracts or generates a fake forecast context for a
# given optimization horizon.
#
# It returns a data frame containing only the time, external
# temperature forecast (Text_forec), and solar radiation forecast
# (SolarR_forec) columns for the requested horizon window.
# When an inaccurate forecast type is requested, the function
# calls imperfect_forecast() to blend ground-truth values with
# a historical average, introducing realistic forecast uncertainty.
#
# The forecast consists of a weighted average beween the actual climate and
# a historical average, with the weight of the historical average increasing
# linearly along the horizon. This allows to introduce realistic forecast
# uncertainty in the building performance predictions.
# -------------------------------------------------------------
# Inputs
#   i0               : Integer. Index of the current simulation step in Main_df.
#   time_sec         : Numeric vector. Time in seconds (currently unused internally
#                      but kept for interface consistency).
#   Main_df          : Data frame. Full simulation time series containing at least
#                      the columns 'time', 'Text', and 'SolarR'.
#   parameters       : List. Model/forecast parameters. Must contain a sub-list
#                      'forecast_parameters' with fields:
#                        forecast_type           (default "accurate"): Character.
#                                                Either "accurate" or "inaccurate".
#                                                Extracted internally.
#                        forecast_n_days_back    (default 5)
#                        forecast_weight_history (default 0.2)
#                        Also requires:
#                        debug_and_config_parameters$verbose: Logical. If TRUE, progress
#                                                             messages are printed.
#   i_end_horizon    : Integer. Index of the last step of the forecast horizon
#                      in Main_df.
# -------------------------------------------------------------
# Outputs
#   A named list with one element:
#     forecast_df : Data frame with columns:
#                     time         – POSIXct timestamps
#                     Text_forec   – Forecast of external air temperature (°C)
#                     SolarR_forec – Forecast of solar radiation (W/m²)
#                   Rows span from index i0 to i_end_horizon in Main_df.
# -------------------------------------------------------------
# Code outline
# 1. Extract forecast parameters
# 2. Select forecast method (accurate or inaccurate)
# 3. Generate forecast data frame
# 4. Return forecast results
# -------------------------------------------------------------
# Usage instructions
# result <- context_forecast_step(i0, time_sec, Main_df, parameters, i_end_horizon)
# -------------------------------------------------------------
# Where this function/script is used
# Called by simulation.R in the MPC simulation loop (step 1: CONTEXT).
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If forecast_type == "inaccurate" and imperfect_forecast() returns no
#     matching timestamps, the corresponding forecast column retains the
#     ground-truth value (fallback to accurate forecast).
#   - Parameters forecast_n_days_back and forecast_weight_history default to
#     5 and 0.2 respectively when not present in parameters$forecast.
#   - If all predicted values are NA (e.g., at the very start of the series
#     where no historical days exist), the original ground-truth values are
#     kept unchanged.
# -------------------------------------------------------------
# functions/scripts called
#   imperfect_forecast() - generates blended historical/actual weather forecasts
#                          (called only when forecast_type == "inaccurate")
# -------------------------------------------------------------
context_forecast_step <- function(i0,
                                  time_sec,
                                  Main_df,
                                  parameters,
                                  i_end_horizon) {
  # Extract parameters from the parameters object
  forecast_type <- parameters$forecast$forecast_type
  verbose       <- parameters$debug_and_config$verbose
  
  # Reduced dataframe of horizon - explicitly create data frame with 3 columns
  forecast_df <- data.frame(
    time = Main_df$time[i0:i_end_horizon],
    Text_forec = Main_df$Text[i0:i_end_horizon],
    SolarR_forec = Main_df$SolarR[i0:i_end_horizon]
  )
  
  # Inaccurate predictions (if applicable)
  if (forecast_type == "inaccurate") {
    n_days_back             <- if (!is.null(parameters$forecast$forecast_n_days_back)) parameters$forecast$forecast_n_days_back else 5
    forecast_weight_history <- if (!is.null(parameters$forecast$forecast_weight_history)) parameters$forecast$forecast_weight_history else 0.2
    
    pred_air_temperature <- imperfect_forecast(
      Main_df,
      target_col = "Text",
      i0 = i0,
      i_end_horizon = i_end_horizon,
      n_days_back = n_days_back,
      forecast_weight_history = forecast_weight_history,
      time_col = "time"
    )
    
    pred_solar_radiation <- imperfect_forecast(
      Main_df,
      target_col = "SolarR",
      i0 = i0,
      i_end_horizon = i_end_horizon,
      n_days_back = n_days_back,
      forecast_weight_history = forecast_weight_history,
      time_col = "time"
    )
    rm(n_days_back, forecast_weight_history)
    
    idx_air_temperature <- match(forecast_df$time, pred_air_temperature$time)
    idx_solar_radiation <- match(forecast_df$time, pred_solar_radiation$time)
    
    pred_vals_air_temperature <- if (!all(is.na(idx_air_temperature))) {
      pred_air_temperature$pred_Text[idx_air_temperature]
    } else rep(NA_real_, nrow(forecast_df))
    rm(pred_air_temperature, idx_air_temperature)
    
    pred_vals_solar_radiation <- if (!all(is.na(idx_solar_radiation))) {
      pred_solar_radiation$pred_SolarR[idx_solar_radiation]
    } else rep(NA_real_, nrow(forecast_df))
    rm(pred_solar_radiation, idx_solar_radiation)
    
    forecast_df$Text_forec <- ifelse(
      !is.na(pred_vals_air_temperature),
      pred_vals_air_temperature,
      forecast_df$Text_forec
    )
    rm(pred_vals_air_temperature)
    
    forecast_df$SolarR_forec <- ifelse(
      !is.na(pred_vals_solar_radiation),
      pred_vals_solar_radiation,
      forecast_df$SolarR_forec
    )
    rm(pred_vals_solar_radiation)
  }
  
  return(list(
    forecast_df = forecast_df
  ))
}