# -------------------------------------------------------------
# Function: context_forecast_step.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function extracts or generates a fake forecast context for a
# given optimization horizon.
#
# It returns a data frame containing only the time, external
# temperature forecast (Text_forec), solar radiation forecast
# (SolarR_forec) and mean outdoor temperature of the plan
# (T_ext_24h_forec) columns for the requested horizon window.
# T_ext_24h_forec is what the plan knows of T_ext_24h when the market
# clears: the T_ext_24h of the bid time row i0, which is the mean
# measured Text of the day before the date of the clearing. It is
# held constant over the whole window, so the plan never reads the
# temperature of a day that has not ended yet. It is the same with
# both forecast types.
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
#   simulation_control : Named list. Must contain
#                        simulation_control$indexes_global$i0 (Integer. Index of
#                        the bid time of the market in Main_df) and
#                        simulation_control$indexes_global$i_end_horizon
#                        (Integer. Index of the last step of the forecast
#                        horizon in Main_df).
#   time_sec         : Numeric vector. Time in seconds (currently unused
#                      internally but kept for interface consistency).
#   Main_df          : Data frame. Full simulation time series containing at
#                      least the columns 'time', 'Text', 'SolarR' and
#                      'T_ext_24h'.
#   parameters       : List. Model/forecast parameters. Must contain a sub-list
#                      'forecast_parameters' with fields:
#                        weather_forecast_type           : Character.
#                                                Either "accurate" or
#                                                "inaccurate".
#                        weather_forecast_n_days_back    : Integer.
#                                                Days of history. Required
#                                                with "inaccurate".
#                        weather_forecast_weight_history : Numeric.
#                                                Weight of the history one
#                                                day ahead. Required with
#                                                "inaccurate".
#                        Also requires:
#                        debug_and_config_parameters$verbose: Logical. Read
#                                                             into a local
#                                                             variable but not
#                                                             currently used
#                                                             (no progress
#                                                             messages are
#                                                             printed).
# -------------------------------------------------------------
# Outputs
#   A named list with two elements:
#     forecast_df : Data frame with columns:
#                     time         – POSIXct timestamps
#                     Text_forec   – Forecast of external air temperature (°C)
#                     SolarR_forec – Forecast of solar radiation (W/m²)
#                     T_ext_24h_forec – Mean outdoor temperature the
#                                  plan reads (°C), T_ext_24h at i0
#                                  on every row
#                   Rows span from index i0 to i_end_horizon in Main_df.
#     no_history  : Integer. Number of instants of the horizon that
#                   found no history in the inaccurate forecast of
#                   Text and of SolarR, added up. 0 for an accurate
#                   forecast.
# -------------------------------------------------------------
# Code outline
# 1. Extract forecast parameters
# 2. Select forecast method (accurate or inaccurate)
# 3. Generate forecast data frame
# 4. Return forecast results
# -------------------------------------------------------------
# Usage instructions
# result <- context_forecast_step(simulation_control, time_sec, Main_df,
# parameters)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If weather_forecast_type == "inaccurate" and imperfect_forecast() returns
#     no matching timestamps, the corresponding forecast column retains the
#     ground-truth value (fallback to accurate forecast).
#   - If weather_forecast_type == "inaccurate" and
#     weather_forecast_n_days_back or weather_forecast_weight_history
#     is missing from parameters$forecast, the function stops with an
#     error message. It holds no fallback value for them.
#   - If all predicted values are NA (e.g., at the very start of the series
#     where no historical days exist), the original ground-truth values are
#     kept unchanged.
# -------------------------------------------------------------
context_forecast_step <- function(simulation_control,
                                  time_sec,
                                  Main_df,
                                  parameters) {
  i0            <- simulation_control$indexes_global$i0
  i_end_horizon <- simulation_control$indexes_global$i_end_horizon

  # Extract parameters from the parameters object
  weather_forecast_type <- parameters$forecast$weather_forecast_type
  verbose       <- parameters$debug_and_config$verbose
  
  # Reduced dataframe of horizon - explicitly create data frame with 4
  # columns. T_ext_24h_forec is the T_ext_24h of the bid time row, the
  # mean measured Text of the day before the clearing date, on every
  # row of the window.
  forecast_df <- data.frame(
    time            = Main_df$time[i0:i_end_horizon],
    Text_forec      = Main_df$Text[i0:i_end_horizon],
    SolarR_forec    = Main_df$SolarR[i0:i_end_horizon],
    T_ext_24h_forec = Main_df$T_ext_24h[i0]
  )
  
  no_history <- 0L

  # Inaccurate predictions (if applicable)
  if (weather_forecast_type == "inaccurate") {
    # Both parameters are read from the forecast parameter file. The
    # function holds no fallback value for them: a missing parameter
    # stops the run.
    if (is.null(parameters$forecast$weather_forecast_n_days_back)) {
      stop(paste0(
        "context_forecast_step: parameter ",
        "'weather_forecast_n_days_back' is missing from ",
        "parameters$forecast. It is required with ",
        "weather_forecast_type = 'inaccurate'."
      ))
    }
    if (is.null(parameters$forecast$weather_forecast_weight_history)) {
      stop(paste0(
        "context_forecast_step: parameter ",
        "'weather_forecast_weight_history' is missing from ",
        "parameters$forecast. It is required with ",
        "weather_forecast_type = 'inaccurate'."
      ))
    }
    n_days_back                     <-
      parameters$forecast$weather_forecast_n_days_back
    weather_forecast_weight_history <-
      parameters$forecast$weather_forecast_weight_history
    
    # imperfect_forecast is called to blend the ground-truth external
    # temperature with a historical average, so the returned forecast
    # progressively deviates from the actual value along the horizon.
    pred_air_temperature <- imperfect_forecast(
      Main_df,
      target_col = "Text",
      i0 = i0,
      i_end_horizon = i_end_horizon,
      n_days_back = n_days_back,
      weather_forecast_weight_history = weather_forecast_weight_history,
      time_col = "time"
    )

    # imperfect_forecast is called again, this time on solar radiation,
    # to build the same kind of degraded forecast for SolarR.
    pred_solar_radiation <- imperfect_forecast(
      Main_df,
      target_col = "SolarR",
      i0 = i0,
      i_end_horizon = i_end_horizon,
      n_days_back = n_days_back,
      weather_forecast_weight_history = weather_forecast_weight_history,
      time_col = "time"
    )
    no_history <- attr(pred_air_temperature, "no_history") +
      attr(pred_solar_radiation, "no_history")
    rm(list = c("n_days_back", "weather_forecast_weight_history"))
    
    idx_air_temperature <- match(forecast_df$time, pred_air_temperature$time)
    idx_solar_radiation <- match(forecast_df$time, pred_solar_radiation$time)
    
    pred_vals_air_temperature <- if (!all(is.na(idx_air_temperature))) {
      pred_air_temperature$pred_Text[idx_air_temperature]
    } else rep(NA_real_, nrow(forecast_df))
    rm(list = c("pred_air_temperature", "idx_air_temperature"))
    
    pred_vals_solar_radiation <- if (!all(is.na(idx_solar_radiation))) {
      pred_solar_radiation$pred_SolarR[idx_solar_radiation]
    } else rep(NA_real_, nrow(forecast_df))
    rm(list = c("pred_solar_radiation", "idx_solar_radiation"))
    
    forecast_df$Text_forec <- ifelse(
      !is.na(pred_vals_air_temperature),
      pred_vals_air_temperature,
      forecast_df$Text_forec
    )
    rm(list = "pred_vals_air_temperature")
    
    forecast_df$SolarR_forec <- ifelse(
      !is.na(pred_vals_solar_radiation),
      pred_vals_solar_radiation,
      forecast_df$SolarR_forec
    )
    rm(list = "pred_vals_solar_radiation")
  }
  
  return(list(
    forecast_df = forecast_df,
    no_history  = no_history
  ))
}