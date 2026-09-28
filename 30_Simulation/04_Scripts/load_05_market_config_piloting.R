# -------------------------------------------------------------
# Script: load_05_market_config_piloting.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the piloting market configuration table from
# 05_Market_config_piloting.csv, validates required columns
# and non-empty content, and stores the data frame in
# parameters$market_config_piloting.
# Sourced from 02_load_all_parameters.R.
# -------------------------------------------------------------
# Inputs
#   paths$market_config_piloting_file : path of 05_Market_config_piloting.csv, resolved by
#     01_initialization.R.
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$market_config_piloting, populated. Nothing else is
#     modified.
# -------------------------------------------------------------
# Code outline
# 1. Read the table with the shared market table reader.
# 2. Check the required columns and that it is not empty.
# 3. Store the table in parameters$market_config_piloting.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by 02_load_all_parameters.R, which supplies
#   paths and parameters and takes the updated parameters back.
# -------------------------------------------------------------
# Where this function/script is used
# Sourced by 02_load_all_parameters.R.
# -------------------------------------------------------------
# functions/scripts called
#   load_market_config_table() - reads one market
#                                configuration table
# -------------------------------------------------------------

{
  # load_market_config_table is called to read
  # 05_Market_config_piloting.csv, validate its required columns,
  # its non-empty content and that no two Piloting markets clear in
  # the same market slot, and return it as a data frame.
  parameters$market_config_piloting <- load_market_config_table(
    paths$market_config_piloting_file, "05_Market_config_piloting.csv",
    parameters$market$market_resolution
  )

  cat("Market config piloting loaded\n")
}
