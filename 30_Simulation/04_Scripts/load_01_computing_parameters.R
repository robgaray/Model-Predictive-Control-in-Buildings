# -------------------------------------------------------------
# Script: load_01_computing_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the computing parameters from 01_computing_parameters.csv,
# validates them against Validation_01_computing_parameters.csv, and
# stores the result in parameters$computing. These are the numerical
# constants of the simulation engine itself: the resolution of the
# master time grid every dataframe is built on, the tolerance below
# which a market slot's planned energy is treated as zero, and the
# time margin the flexibility event generator keeps between events.
# They are loaded before any other configuration file, because
# assemble_main_df.R needs the master resolution to build Main_df.
# Sourced from 02_load_all_parameters.R.
# -------------------------------------------------------------
# Inputs
#   paths$computing_parameters_file : path of 01_computing_parameters.csv, resolved by
#     01_initialization.R.
#   Its validation table, Validation_01_computing_parameters.csv,
#     read alongside it.
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$computing, populated. Nothing else is
#     modified.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value against its own
#    validation table.
# 2. Store the result in parameters$computing.
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
  # 01_computing_parameters.csv and check every value against the
  # types/ranges defined in Validation_01_computing_parameters.csv,
  # which is this file's own validation table rather than the shared
  # Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$computing_parameters_file,
    "01_computing_parameters.csv",
    computing_validation_config
  )

  parameters$computing <- lapply(raw_values, as.numeric)
  rm(raw_values)

  cat("Computing parameters loaded\n")
}
