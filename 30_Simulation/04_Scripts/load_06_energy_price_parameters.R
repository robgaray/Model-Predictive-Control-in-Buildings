# -------------------------------------------------------------
# Script: load_06_energy_price_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads energy market price discount/premium parameters from
# 06_Energy_price_parameters.csv, validates values against
# Parameter_config.csv, and stores the result in
# parameters$energy_price. These parameters apply only to the four
# energy buy/sell price signals (Elec_unit_cost_import_buy/sell,
# _export_buy/sell), not to flexibility. They are read by:
#   - 10_energy_price_signals_setup.R
#   - 11_full_market_information_setup.R
# which derive the four energy signals from them.
# Sourced from 02_load_all_parameters.R.
# -------------------------------------------------------------
# Inputs
#   paths$energy_price_file : path of 06_Energy_price_parameters.csv, resolved by
#     01_initialization.R.
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$energy_price, populated. Nothing else is
#     modified.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value.
# 2. Store the result in parameters$energy_price.
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
  # 06_Energy_price_parameters.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$energy_price_file, "06_Energy_price_parameters.csv", validation_config
  )

  parameters$energy_price <- lapply(raw_values, as.numeric)
  rm(raw_values)

  cat("Energy price parameters loaded\n")
}
