# -------------------------------------------------------------
# Script: load_30_debug_and_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads debug and configuration parameters from
# 30_Debug_and_config.csv, validates raw values against
# Parameter_config.csv, calls load_debug_and_config_parameters()
# for structured loading, and stores the result in
# parameters$debug_and_config.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  raw_df     <- read.csv(paths$debug_and_config_file, comment.char = "#", stringsAsFactors = FALSE)
  raw_values <- as.list(raw_df$value)
  names(raw_values) <- trimws(raw_df$parameter)
  rm(raw_df)

  validate_parameter_config(raw_values, "30_Debug_and_config.csv", validation_config)
  rm(raw_values)

  parameters$debug_and_config <- load_debug_and_config_parameters(paths$debug_and_config_file)

  cat("Debug and config parameters loaded\n")
}
