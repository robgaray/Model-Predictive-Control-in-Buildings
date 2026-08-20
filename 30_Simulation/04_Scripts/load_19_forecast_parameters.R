# -------------------------------------------------------------
# Script: load_19_forecast_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads forecast parameters from 19_Forecast_parameters.csv,
# validates values against Parameter_config.csv, reads
# forecast_type directly as text ("accurate" or "inaccurate"),
# and stores the result in parameters$forecast. Its validity is
# already enforced by Parameter_config.csv (Options type, Error
# level, "accurate,inaccurate") inside
# read_and_validate_parameter_csv(), so it is not re-checked here.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 19_Forecast_parameters.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$forecast_file, "19_Forecast_parameters.csv", validation_config
  )

  forecast_type <- trimws(as.character(raw_values$forecast_type))

  text_params <- c("forecast_type")
  numeric_values <- lapply(raw_values[!names(raw_values) %in% text_params], as.numeric)
  rm(raw_values)

  parameters$forecast <- c(
    list(forecast_type = forecast_type),
    numeric_values
  )
  rm(forecast_type, numeric_values, text_params)

  cat("Forecast parameters loaded\n")
}
