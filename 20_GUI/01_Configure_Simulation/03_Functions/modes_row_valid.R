# -------------------------------------------------------------
# Function: modes_row_valid.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Says whether one row of the modes table
# (13_Modes_setpoints.csv) holds numbers in its three columns.
# -------------------------------------------------------------
# Inputs
#   mode_val         : Value of the mode column of the mode row.
#   heating_val      : Value of the heating column of the mode
#                      row [degC].
#   cooling_val      : Value of the cooling column of the mode
#                      row [degC].
# -------------------------------------------------------------
# Outputs
#   Logical scalar: TRUE when mode, heating and cooling are all
#   numbers.
# -------------------------------------------------------------
# Code outline
# 1. Convert the three values to numbers and check none is NA.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   modes_row_valid(mode_val, heating_val, cooling_val)
# -------------------------------------------------------------
# Where this function/script is used
# load_modes_file_safe()
# -------------------------------------------------------------
# functions/scripts called
# None of this app; base R and shiny only.
# -------------------------------------------------------------

modes_row_valid <- function(mode_val, heating_val, cooling_val) {
  !is.na(suppressWarnings(as.numeric(mode_val))) &&
    !is.na(suppressWarnings(as.numeric(heating_val))) &&
    !is.na(suppressWarnings(as.numeric(cooling_val)))
}
