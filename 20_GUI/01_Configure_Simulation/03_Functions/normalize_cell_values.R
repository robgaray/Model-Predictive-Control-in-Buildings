# -------------------------------------------------------------
# Function: normalize_cell_values.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Turns values into a form that can be compared to tell whether the
# user has changed one. A value that reads as a number is written
# as that number, so that 0.50, 0.5 and 5e-1 are the same value,
# and a missing value is written NA. Anything else is trimmed text.
# -------------------------------------------------------------
# Inputs
#   x : Vector. Values of any type, such as the value of an input
#       or a column of a table.
# -------------------------------------------------------------
# Outputs
#   Character vector of the same length.
# -------------------------------------------------------------
# Code outline
# 1. Write the text, and the values that read as numbers as numbers.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   normalize_cell_values(x)
# -------------------------------------------------------------

normalize_cell_values <- function(x) {

  # -------------------------------------------------------------
  # 1. Write the text, and the values that read as numbers as numbers
  # -------------------------------------------------------------
  {
    text              <- trimws(as.character(x))
    text[is.na(text)] <- "NA"
    numbers           <- suppressWarnings(as.numeric(text))
    is_number         <- !is.na(numbers) & nzchar(text)
    text[is_number]   <- as.character(numbers[is_number])
    rm(numbers, is_number)
  }

  return(text)
}
