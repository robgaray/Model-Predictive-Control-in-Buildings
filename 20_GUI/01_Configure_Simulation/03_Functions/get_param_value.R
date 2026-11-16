# -------------------------------------------------------------
# Function: get_param_value.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Returns the value of one parameter of a flat parameter,value
# table, as text.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame. The table the function works
#                      on (see above).
#   param            : Character. Name of the parameter.
# -------------------------------------------------------------
# Outputs
#   Character scalar: the value, or "" when the parameter is not in
#   the table.
# -------------------------------------------------------------
# Code outline
# 1. Find the parameter and return its first value.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   get_param_value(df, param)
# -------------------------------------------------------------

get_param_value <- function(df, param) {
  value <- df$value[df$parameter == param]
  if (length(value) == 0) {
    return("")
  }
  as.character(value[1])
}
