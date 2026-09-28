# -------------------------------------------------------------
# Script: load_02_control.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads 02_Control.csv, validates every value against
# Parameter_config.csv, and structures it with
# load_control_parameters() into parameters$control.
# These are the control parameters that apply whatever control_type is
# chosen; control_type is read as text, and its validity is enforced
# by Parameter_config.csv (Options "modes,setpoints").
# -------------------------------------------------------------
# Inputs
#   paths$control_file : path of 02_Control.csv, resolved by
#     01_initialization.R.
#   parameters : the list being assembled.
# -------------------------------------------------------------
# Outputs
#   parameters$control, created with the global control parameters.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value.
# 2. Structure it with load_control_parameters() and store it in parameters$control.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by 02_load_all_parameters.R, which supplies
#   paths and parameters and takes the updated parameters back.
# -------------------------------------------------------------
# Where this function/script is used
# Sourced by 02_load_all_parameters.R.
# -------------------------------------------------------------
# functions/scripts called
#   - read_and_validate_parameter_csv() - reads a configuration file and
#     validates every value
#   - load_control_parameters() - structures the values
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 02_Control.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$control_file, "02_Control.csv", validation_config
  )

  # load_control_parameters is called to turn the raw key/value pairs into
  # the structured values the rest of the simulation reads from
  # parameters$control.
  parameters$control <- load_control_parameters(raw_values)
  rm(raw_values)

  if (is.null(parameters$control$Deadband)) {
    stop("Deadband not found in 02_Control.csv")
  }

  cat("02_Control.csv loaded\n")
}
