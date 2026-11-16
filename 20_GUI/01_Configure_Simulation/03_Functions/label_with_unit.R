# -------------------------------------------------------------
# Function: label_with_unit.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the label of a parameter input as "name [unit]", so that
# every parameter the GUI shows carries its unit.
# -------------------------------------------------------------
# Inputs
#   param_name       : Character. Name of the parameter.
#   file_key         : Character. File name of the configuration
#                      file, as the catalogue names it.
# -------------------------------------------------------------
# Outputs
#   Character scalar: the label, with the unit in brackets when
#   there is one.
# -------------------------------------------------------------
# Code outline
# 1. Ask get_param_unit() for the unit.
# 2. Append it in brackets when it is not empty.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   label_with_unit(param_name, file_key)
# -------------------------------------------------------------

label_with_unit <- function(param_name, file_key) {
  unit <- get_param_unit(file_key, param_name)
  if (nzchar(unit)) {
    paste0(param_name, " [", unit, "]")
  } else {
    param_name
  }
}
