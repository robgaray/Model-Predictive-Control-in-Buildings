# -------------------------------------------------------------
# Script: load_30_debug_and_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
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
  # read_and_validate_parameter_csv is called to read
  # 30_Debug_and_config.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$debug_and_config_file, "30_Debug_and_config.csv", validation_config
  )

  # load_debug_and_config_parameters is called to turn the raw
  # key/value pairs into the structured debug/config parameter list.
  parameters$debug_and_config <- load_debug_and_config_parameters(raw_values)
  rm(raw_values)

  cat("Debug and config parameters loaded\n")
}
