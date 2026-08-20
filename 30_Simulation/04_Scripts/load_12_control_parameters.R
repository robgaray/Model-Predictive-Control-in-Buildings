# -------------------------------------------------------------
# Script: load_12_control_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads control parameters from 12_Control_parameters.csv,
# validates raw values against Parameter_config.csv, calls
# load_control_parameters() for structured loading, and stores
# the result in parameters$control.
# control_type is read as text ("modes" or "setpoints"); its
# validity is already enforced by Parameter_config.csv (Options
# type, Error level, "modes,setpoints") inside
# read_and_validate_parameter_csv(), so it is not re-checked here.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 12_Control_parameters.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$control_file, "12_Control_parameters.csv", validation_config
  )

  # load_control_parameters is called to turn the raw key/value pairs
  # into the structured control parameter list expected by the rest
  # of the simulation.
  parameters$control <- load_control_parameters(raw_values)
  rm(raw_values)

  if (is.null(parameters$control$Deadband)) {
    stop("Deadband not found in control parameters")
  }

  cat("Control parameters loaded\n")
}
