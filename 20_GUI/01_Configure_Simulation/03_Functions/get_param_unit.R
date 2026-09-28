# -------------------------------------------------------------
# Function: get_param_unit.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Looks up the unit of a configuration parameter in
# 90_Structure/Parameter_Units.csv, so that every label can show
# it in square brackets.
# It reads param_units_table, which GUI_config.R loads once at
# start (block 2.1). A dimensionless unit ("-") and an unknown
# parameter both return an empty string, so no brackets are
# shown.
# -------------------------------------------------------------
# Inputs
#   file_key         : Character. File name of the configuration
#                      file, as Parameter_Units.csv names it;
#                      NULL shows no units.
#   param_name       : Character. Name of the parameter.
# -------------------------------------------------------------
# Outputs
#   Character scalar: the unit, or "" when there is none to show.
# -------------------------------------------------------------
# Code outline
# 1. Find the row of the parameter in param_units_table.
# 2. Return its unit, or "" when it is missing or dimensionless.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   get_param_unit(file_key, param_name)
# -------------------------------------------------------------
# Where this function/script is used
# GUI_config.R, label_with_unit()
# -------------------------------------------------------------
# functions/scripts called
# None of this app; base R and shiny only.
# -------------------------------------------------------------

get_param_unit <- function(file_key, param_name) {
  if (is.null(param_units_table)) {
    return("")
  }
  match_row <- param_units_table[
    param_units_table$file == file_key & param_units_table$parameter == param_name,
  ]
  if (nrow(match_row) != 1) {
    return("")
  }
  unit <- trimws(match_row$proposed_unit[1])
  if (unit == "-" || !nzchar(unit)) {
    return("")
  }
  unit
}
