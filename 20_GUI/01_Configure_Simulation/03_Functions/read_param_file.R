# -------------------------------------------------------------
# Function: read_param_file.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads a flat parameter,value configuration file, skipping
# comment lines. It adds no error handling and no defaults: the
# safe loaders that call it add both.
# It reads config_path, the configuration folder GUI_config.R
# resolves at start.
# -------------------------------------------------------------
# Inputs
#   filename         : Character. Path of the configuration file,
#                      relative to config_path.
# -------------------------------------------------------------
# Outputs
#   Data frame with the columns of the file.
# -------------------------------------------------------------
# Code outline
# 1. Read the CSV, skipping comment lines.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   read_param_file(filename)
# -------------------------------------------------------------
# Where this function/script is used
# load_default_param_list(), load_param_file_safe()
# -------------------------------------------------------------
# functions/scripts called
# None of this app; base R and shiny only.
# -------------------------------------------------------------

read_param_file <- function(filename) {
  read.csv(
    file.path(config_path, filename),
    comment.char     = "#",
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )
}
