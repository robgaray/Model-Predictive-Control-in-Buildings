# -------------------------------------------------------------
# Script: load_14_optimization_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
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
  # read_and_validate_parameter_csv is called to read
  # 14_Optimization_parameters.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$optimization_file, "14_Optimization_parameters.csv", validation_config
  )

  # load_optimization_parameters is called to turn the raw key/value
  # pairs into the structured optimization parameter list, applying
  # its internal clamping logic.
  parameters$optimization <- load_optimization_parameters(raw_values)
  rm(raw_values)

  cat("Optimization parameters loaded\n")
}
