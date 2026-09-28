# -------------------------------------------------------------
# Script: load_15_forecast_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads forecast parameters from 15_Forecast_parameters.csv,
# validates values against Parameter_config.csv, reads
# weather_forecast_type directly as text ("accurate" or "inaccurate"),
# and stores the result in parameters$forecast. Its validity is
# already enforced by Parameter_config.csv (Options type, Error
# level, "accurate,inaccurate") inside
# read_and_validate_parameter_csv(), so it is not re-checked here.
# Sourced from 02_load_all_parameters.R.
# -------------------------------------------------------------
# Inputs
#   paths$forecast_file : path of 15_Forecast_parameters.csv, resolved by
#     01_initialization.R.
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$forecast, populated. Nothing else is
#     modified.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value.
# 2. Store the result in parameters$forecast.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by 02_load_all_parameters.R, which supplies
#   paths and parameters and takes the updated parameters back.
# -------------------------------------------------------------
# Where this function/script is used
# Sourced by 02_load_all_parameters.R.
# -------------------------------------------------------------
# functions/scripts called
#   read_and_validate_parameter_csv() - reads a configuration
#                                       file and validates
#                                       every value
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 15_Forecast_parameters.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$forecast_file, "15_Forecast_parameters.csv", validation_config
  )

  weather_forecast_type <- trimws(as.character(raw_values$weather_forecast_type))
  price_forecast_type   <- trimws(as.character(raw_values$price_forecast_type))

  text_params <- c("weather_forecast_type", "price_forecast_type")
  numeric_values <- lapply(raw_values[!names(raw_values) %in% text_params], as.numeric)
  rm(raw_values)

  parameters$forecast <- c(
    list(weather_forecast_type = weather_forecast_type,
         price_forecast_type   = price_forecast_type),
    numeric_values
  )
  rm(weather_forecast_type, price_forecast_type, numeric_values, text_params)

  cat("Forecast parameters loaded\n")
}
