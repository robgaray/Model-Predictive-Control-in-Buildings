# -------------------------------------------------------------
# Function: load_default_param_list.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Takes the default values of the parameters of a file from the
# parameter catalogue, into a named vector of values, in the order
# of the catalogue. For a file that holds a table below a block of
# parameters, these are the parameters of the block: the rows of the
# catalogue that have a default value, since the columns of the
# table have - instead. It returns NULL when the catalogue holds
# no such row for the file, so the caller can say that no defaults
# are available.
# -------------------------------------------------------------
# Inputs
#   validation_config: Named list. The rules of the catalogue and
#                      the integer tolerance, as load_gui_catalogue()
#                      returns them.
#   file_label       : Character. File name of the configuration
#                      file, as the catalogue names it.
# -------------------------------------------------------------
# Outputs
#   Named character vector (parameter -> value), or NULL.
# -------------------------------------------------------------
# Code outline
# 1. Take the catalogue rows of the file that have a default.
# 2. Return their defaults named by parameter, or NULL.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   load_default_param_list(validation_config, file_label)
# -------------------------------------------------------------

load_default_param_list <- function(validation_config, file_label) {

  # 1. Take the catalogue rows of the file that have a default
  # -------------------------------------------------------------
  {
    rules <- validation_config$rules
    rows  <- rules[rules$file == file_label & rules$default != "-", ,
                   drop = FALSE]
    if (nrow(rows) == 0) {
      return(NULL)
    }
  }

  # 2. Return their defaults named by parameter
  # -------------------------------------------------------------
  {
    defaults <- setNames(rows$default, rows$parameter)
    rm(rules, rows)
  }

  return(defaults)
}
