# -------------------------------------------------------------
# Script: load_07_flexibility_price_emulation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the market-aware flexibility generation parameters from
# 07_Flexibility_price_emulation_parameters.csv:
#   - Max_shift_hours
#   - P_advance
#   - P_delay
#   - P_event_base
#   - decay_rate
# validates the values against Parameter_config.csv, and stores the
# result in
# parameters$flexibility_price_emulation. Only consumed by
# 09_flexibility_price_emulation.R when Complex_Market_Config == "yes".
# Sourced from 02_load_all_parameters.R.
# -------------------------------------------------------------
# Inputs
#   paths$flexibility_price_emulation_file : path of 07_Flexibility_price_emulation_parameters.csv, resolved by
#     01_initialization.R.
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$flexibility_price_emulation, populated. Nothing else is
#     modified.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value.
# 2. Store the result in parameters$flexibility_price_emulation.
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
  # 07_Flexibility_price_emulation_parameters.csv and check every value
  # against the types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$flexibility_price_emulation_file, "07_Flexibility_price_emulation_parameters.csv",
    validation_config
  )

  parameters$flexibility_price_emulation <- lapply(raw_values, as.numeric)
  rm(raw_values)

  cat("Flexibility generation parameters loaded\n")
}
