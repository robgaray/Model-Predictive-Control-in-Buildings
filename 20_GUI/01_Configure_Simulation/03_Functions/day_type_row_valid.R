# -------------------------------------------------------------
# Function: day_type_row_valid.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Says whether one hourly occupancy profile of
# 14_Use_Patterns.csv holds only 0 and 1.
# -------------------------------------------------------------
# Inputs
#   row_values       : The 24 hourly values of one profile row.
# -------------------------------------------------------------
# Outputs
#   Logical scalar: TRUE when every hour is 0 or 1.
# -------------------------------------------------------------
# Code outline
# 1. Convert the hours to numbers and check each is 0 or 1.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   day_type_row_valid(row_values)
# -------------------------------------------------------------

day_type_row_valid <- function(row_values) {
  nums <- suppressWarnings(as.numeric(unlist(row_values)))
  !anyNA(nums) && all(nums %in% c(0, 1))
}
