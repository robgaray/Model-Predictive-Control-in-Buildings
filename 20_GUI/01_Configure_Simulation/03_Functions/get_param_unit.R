# -------------------------------------------------------------
# Function: get_param_unit.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Looks up the unit of a configuration parameter in the parameter
# catalogue, so that every label can show it in square brackets.
# It reads validation_config, which GUI_config.R loads once at
# start. A dimensionless parameter returns "-", which is shown in
# brackets too; an unknown parameter returns an empty string.
# -------------------------------------------------------------
# Inputs
#   file_key         : Character. File name of the configuration
#                      file, as the catalogue names it.
#   param_name       : Character. Name of the parameter.
# -------------------------------------------------------------
# Outputs
#   Character scalar: the unit, or "" when there is none to show.
# -------------------------------------------------------------
# Code outline
# 1. Find the row of the parameter in the catalogue.
# 2. Return its unit, or "" when it is missing.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   get_param_unit(file_key, param_name)
# -------------------------------------------------------------

get_param_unit <- function(file_key, param_name) {
  rules     <- validation_config$rules
  match_row <- rules[rules$file == file_key & rules$parameter == param_name, ,
                     drop = FALSE]
  if (nrow(match_row) != 1) {
    return("")
  }
  unit <- trimws(match_row$unit[1])
  if (!nzchar(unit)) {
    return("")
  }
  unit
}
