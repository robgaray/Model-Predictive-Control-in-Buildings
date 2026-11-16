# -------------------------------------------------------------
# Function: validation_options.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Returns the allowed options of a closed-list parameter, as the
# parameter catalogue declares them (type Options), so the GUI
# never keeps a second copy of the list. It is what feeds the
# dropdowns of closed-list parameters.
# When the parameter has no Options rule, or the catalogue could
# not be read, it returns NULL: the caller then shows a text
# input, the same limited validation the app already announces
# when the catalogue is missing.
# -------------------------------------------------------------
# Inputs
#   validation_config: Named list. The rules of the catalogue and
#                      the integer tolerance, as load_gui_catalogue()
#                      returns them.
#   file_name        : Character. File name of the configuration
#                      file, as the catalogue names it.
#   param_name       : Character. Name of the parameter.
# -------------------------------------------------------------
# Outputs
#   Character vector of the allowed options, or NULL.
# -------------------------------------------------------------
# Code outline
# 1. Find the Options rule of the parameter.
# 2. Split its options, or return NULL when there is none.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   validation_options(validation_config, file_name, param_name)
# -------------------------------------------------------------

validation_options <- function(validation_config, file_name, param_name) {
  rules <- validation_config$rules[
    validation_config$rules$file == file_name &
      validation_config$rules$parameter == param_name &
      validation_config$rules$type == "Options", ,
    drop = FALSE
  ]
  if (nrow(rules) == 0) {
    return(NULL)
  }
  trimws(strsplit(rules$options[1], ",")[[1]])
}
