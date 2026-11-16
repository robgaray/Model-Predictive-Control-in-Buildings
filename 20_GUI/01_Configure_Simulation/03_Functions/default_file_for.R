# -------------------------------------------------------------
# Function: default_file_for.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Names the Default_ file that holds the built-in values of a
# table configuration file. Default values are never written in
# the app: those of a table live in
# 30_Simulation/02_Config/00_Validation/Default_<file>, with the
# same structure as the file they stand for. The defaults of the
# flat parameter files are in the parameter catalogue instead
# (see load_gui_catalogue()).
# -------------------------------------------------------------
# Inputs
#   filename         : Character. Path of the configuration file,
#                      relative to config_path.
# -------------------------------------------------------------
# Outputs
#   Character scalar: the path of the Default_ file, relative to
#   the configuration folder.
# -------------------------------------------------------------
# Code outline
# 1. Prefix the base name with 00_Validation/Default_.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   default_file_for(filename)
# -------------------------------------------------------------

default_file_for <- function(filename) {
  file.path("00_Validation", paste0("Default_", basename(filename)))
}
