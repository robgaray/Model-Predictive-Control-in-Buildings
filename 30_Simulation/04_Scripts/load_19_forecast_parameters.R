# -------------------------------------------------------------
# Script: load_19_forecast_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads forecast parameters from 19_Forecast_parameters.csv,
# validates values against Parameter_config.csv, reads
# forecast_type directly as text ("accurate" or "inaccurate"),
# validates it strictly, and stores the result in
# parameters$forecast.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  raw_df     <- read.csv(paths$forecast_file, comment.char = "#", stringsAsFactors = FALSE)
  raw_values <- as.list(raw_df$value)
  names(raw_values) <- trimws(raw_df$parameter)
  rm(raw_df)

  validate_parameter_config(raw_values, "19_Forecast_parameters.csv", validation_config)

  forecast_type <- trimws(as.character(raw_values$forecast_type))

  if (!forecast_type %in% c("accurate", "inaccurate")) {
    stop(paste0(
      "Invalid forecast_type: '", forecast_type,
      "'. Must be 'accurate' or 'inaccurate'."
    ))
  }

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
