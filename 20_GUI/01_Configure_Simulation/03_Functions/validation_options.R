# -------------------------------------------------------------
# Function: validation_options.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Returns the allowed options of a closed-list parameter, as
# Parameter_config.csv declares them (type Options), so the GUI
# never keeps a second copy of the list. It is what feeds the
# dropdowns of closed-list parameters and the aim check of the
# market tables.
# When the parameter has no Options rule, or Parameter_config.csv
# could not be read, it returns NULL: the caller then shows a text
# input and skips the options check, the same limited validation
# the app already announces when that file is missing.
# -------------------------------------------------------------
# Inputs
#   validation_config: Data frame. The rules of
#                      Parameter_config.csv.
#   file_name        : Character. File name of the configuration
#                      file, as Parameter_config.csv names it.
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
# Where this function/script is used
# GUI_config.R
# -------------------------------------------------------------
# functions/scripts called
# None of this app; base R only.
# -------------------------------------------------------------
validation_options <- function(validation_config, file_name, param_name) {
  rules <- validation_config[
    trimws(as.character(validation_config$file_name)) == file_name &
      trimws(as.character(validation_config$parameter_name)) == param_name &
      trimws(as.character(validation_config$type)) == "Options",
  ]
  if (nrow(rules) == 0) {
    return(NULL)
  }
  trimws(strsplit(trimws(as.character(rules$options[1])), ",")[[1]])
}
