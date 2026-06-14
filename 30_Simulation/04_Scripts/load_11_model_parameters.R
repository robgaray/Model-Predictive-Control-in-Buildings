# -------------------------------------------------------------
# Script: load_11_model_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads model parameters from 11_Model_parameters.csv,
# validates them against Parameter_config.csv, applies the
# domain-specific validate_model_parameters() check, computes
# Rvent parameters via compute_Rvent(), and stores the result
# in parameters$model.
# Sourced from load_all_parameters.R.
# Requires parameters$physical_properties to be already loaded.
# -------------------------------------------------------------

{
  raw_df     <- read.csv(paths$model_file, comment.char = "#", stringsAsFactors = FALSE)
  raw_values <- as.list(raw_df$value)
  names(raw_values) <- trimws(raw_df$parameter)
  rm(raw_df)

  validate_parameter_config(raw_values, "11_Model_parameters.csv", validation_config)

  model_params_raw <- lapply(raw_values, as.numeric)
  rm(raw_values)

  model_params_raw <- validate_model_parameters(model_params_raw)
  model_params_raw <- compute_Rvent(model_params_raw, parameters$physical_properties)

  parameters$model <- model_params_raw
  rm(model_params_raw)

  cat("Model parameters loaded\n")
}
