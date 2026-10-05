# -------------------------------------------------------------
# Script: load_10_operational_temperature_corrections.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the operational temperature corrections from
# 10_Operational_temperature_corrections.csv, validates values
# against Parameter_config.csv, and stores them in
# parameters$operational_temperature_corrections: the parameters that
# shape the reference temperature curves (anticipation of the service
# period, seasonal correction of the comfort band, and detection of
# the heating and cooling seasons).
# Sourced from 02_load_all_parameters.R.
# -------------------------------------------------------------
# Inputs
#   paths$operational_temperature_corrections_file : path of
#     10_Operational_temperature_corrections.csv, resolved by
#     01_initialization.R.
#   parameters : the list being assembled.
# -------------------------------------------------------------
# Outputs
#   parameters$operational_temperature_corrections, with the eight
#     corrections. Nothing else is modified.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value.
# 2. Store the result in
#    parameters$operational_temperature_corrections.
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
  # 10_Operational_temperature_corrections.csv and check every value
  # against the types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$operational_temperature_corrections_file,
    "10_Operational_temperature_corrections.csv",
    validation_config
  )

  parameters$operational_temperature_corrections <- lapply(raw_values, as.numeric)
  rm(raw_values)

  cat("Operational temperature corrections loaded\n")
}
