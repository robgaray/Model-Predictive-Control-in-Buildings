# -------------------------------------------------------------
# Script: load_14_optimization_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads optimization parameters from 14_Optimization_parameters.csv,
# validates raw values against Parameter_config.csv, calls
# load_optimization_parameters() for structured loading with
# internal clamping logic, and stores the result in
# parameters$optimization.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  raw_df     <- read.csv(paths$optimization_file, comment.char = "#", stringsAsFactors = FALSE)
  raw_values <- as.list(raw_df$value)
  names(raw_values) <- trimws(raw_df$parameter)
  rm(raw_df)

  validate_parameter_config(raw_values, "14_Optimization_parameters.csv", validation_config)
  rm(raw_values)

  parameters$optimization <- load_optimization_parameters(paths$optimization_file)

  cat("Optimization parameters loaded\n")
}
