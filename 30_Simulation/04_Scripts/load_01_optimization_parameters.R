# -------------------------------------------------------------
# Script: load_01_optimization_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads optimization parameters from 01_Optimization_parameters.csv,
# validates raw values against Parameter_config.csv, calls
# load_optimization_parameters() for structured loading with
# internal clamping logic, and stores the result in
# parameters$optimization.
# Sourced from 02_load_all_parameters.R.
# -------------------------------------------------------------
# Inputs
#   paths$optimization_file : path of 01_Optimization_parameters.csv, resolved by
#     01_initialization.R.
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$optimization, populated. Nothing else is
#     modified.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value.
# 2. Turn the raw values into the optimization sub-list.
# 3. Store the result in parameters$optimization.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by 02_load_all_parameters.R, which supplies
#   paths and parameters and takes the updated parameters back.
# -------------------------------------------------------------
# Where this function/script is used
# Sourced by 02_load_all_parameters.R.
# -------------------------------------------------------------
# functions/scripts called
#   load_optimization_parameters() - turns the raw
#                                    optimization values into
#                                    its sub-list
#   read_and_validate_parameter_csv() - reads a configuration
#                                       file and validates
#                                       every value
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 01_Optimization_parameters.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$optimization_file, "01_Optimization_parameters.csv", validation_config
  )

  # load_optimization_parameters is called to turn the raw key/value
  # pairs into the structured optimization parameter list, applying
  # its internal clamping logic.
  parameters$optimization <- load_optimization_parameters(raw_values)
  rm(raw_values)

  cat("Optimization parameters loaded\n")
}
