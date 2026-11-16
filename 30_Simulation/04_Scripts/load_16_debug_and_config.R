# -------------------------------------------------------------
# Script: load_16_debug_and_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads debug and configuration parameters from
# 16_Debug_and_config.csv, validates them against the parameter
# catalogue, turns verbose into a logical switch, and stores the
# result in parameters$debug_and_config.
# Sourced from load_all_parameters().
# -------------------------------------------------------------
# Inputs
#   paths$debug_and_config_file : path of 16_Debug_and_config.csv, resolved by
#     initialize_simulator().
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$debug_and_config, populated. Nothing else is
#     modified.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value.
# 2. Turn verbose into a logical switch.
# 3. Store the result in parameters$debug_and_config.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by load_all_parameters(), which supplies
#   paths and parameters and takes the updated parameters back.
# -------------------------------------------------------------

{
  # load_parameter_file is called to read 16_Debug_and_config.csv,
  # check every value against the parameter catalogue and return each
  # one in the type of its rule.
  parameters$debug_and_config <- load_parameter_file(
    paths$debug_and_config_file,
    validation_config
  )

  # verbose is a 0/1 option in the file and a logical switch in the
  # code that prints the trace.
  parameters$debug_and_config$verbose <- parameters$debug_and_config$verbose == 1
}
