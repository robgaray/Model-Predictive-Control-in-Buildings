# -------------------------------------------------------------
# Script: load_08_flexibility_event_configuration.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads 08_Flexibility_Event_Configuration.csv, validates every value against
# Parameter_config.csv, and structures it with
# load_flexibility_event_parameters() into parameters$control.
# These are the parameters that define how a flexibility event is built
# and committed.
# -------------------------------------------------------------
# Inputs
#   paths$flexibility_events_file : path of 08_Flexibility_Event_Configuration.csv, resolved by
#     01_initialization.R.
#   parameters : the list being assembled.
# -------------------------------------------------------------
# Outputs
#   parameters$control, with these parameters added to it.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value.
# 2. Structure it with load_flexibility_event_parameters() and store it in parameters$control.
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
#   - load_flexibility_event_parameters() - structures the values
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 08_Flexibility_Event_Configuration.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$flexibility_events_file, "08_Flexibility_Event_Configuration.csv", validation_config
  )

  # load_flexibility_event_parameters is called to turn the raw key/value pairs into
  # the structured values the rest of the simulation reads from
  # parameters$control.
  parameters$control <- c(parameters$control, load_flexibility_event_parameters(raw_values))
  rm(raw_values)

  cat("08_Flexibility_Event_Configuration.csv loaded\n")
}
