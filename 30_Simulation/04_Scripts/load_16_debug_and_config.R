# -------------------------------------------------------------
# Script: load_16_debug_and_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads debug and configuration parameters from
# 16_Debug_and_config.csv, validates raw values against
# Parameter_config.csv, calls load_debug_and_config_parameters()
# for structured loading, and stores the result in
# parameters$debug_and_config.
# Sourced from 02_load_all_parameters.R.
# -------------------------------------------------------------
# Inputs
#   paths$debug_and_config_file : path of 16_Debug_and_config.csv, resolved by
#     01_initialization.R.
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$debug_and_config, populated. Nothing else is
#     modified.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value.
# 2. Turn the raw values into the debug sub-list.
# 3. Store the result in parameters$debug_and_config.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by 02_load_all_parameters.R, which supplies
#   paths and parameters and takes the updated parameters back.
# -------------------------------------------------------------
# Where this function/script is used
# Sourced by 02_load_all_parameters.R.
# -------------------------------------------------------------
# functions/scripts called
#   load_debug_and_config_parameters() - turns the raw debug
#                                        values into its sub-
#                                        list
#   read_and_validate_parameter_csv() - reads a configuration
#                                       file and validates
#                                       every value
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 16_Debug_and_config.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$debug_and_config_file, "16_Debug_and_config.csv", validation_config
  )

  # load_debug_and_config_parameters is called to turn the raw
  # key/value pairs into the structured debug/config parameter list.
  parameters$debug_and_config <- load_debug_and_config_parameters(raw_values)
  rm(raw_values)

  cat("Debug and config parameters loaded\n")
}
