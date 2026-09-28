# -------------------------------------------------------------
# Function: load_default_param_list.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads the Default_ file of a flat parameter file into a named
# vector of values. It returns NULL when the file cannot be read,
# so the caller can say that no defaults are available.
# -------------------------------------------------------------
# Inputs
#   default_filename : Character. Path of the Default_ file,
#                      relative to config_path.
# -------------------------------------------------------------
# Outputs
#   Named character vector (parameter -> value), or NULL.
# -------------------------------------------------------------
# Code outline
# 1. Read the Default_ file.
# 2. Return its values named by parameter, or NULL.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   load_default_param_list(default_filename)
# -------------------------------------------------------------
# Where this function/script is used
# load_param_file_safe()
# -------------------------------------------------------------
# functions/scripts called
# read_param_file()
# -------------------------------------------------------------

load_default_param_list <- function(default_filename) {
  df <- tryCatch(suppressWarnings(read_param_file(default_filename)), error = function(e) NULL)
  if (is.null(df) || !all(c("parameter", "value") %in% names(df)) || nrow(df) == 0) {
    return(NULL)
  }
  setNames(trimws(as.character(df$value)), trimws(as.character(df$parameter)))
}
