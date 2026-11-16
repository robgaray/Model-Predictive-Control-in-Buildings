# -------------------------------------------------------------
# Function: is_units_row.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Says whether a row of a configuration table is its units row. The
# configuration format puts the units row right after the header, so
# the row tested is always the first one under it. It is told apart
# from a data row by the columns that hold numbers: a data row has a
# number in all of them, and a units row has a unit (degC, h, text, or
# any text, "-" included) in at least one.
# -------------------------------------------------------------
# Inputs
#   row_values : Character or numeric vector. The values of the row in
#                the columns that hold numbers in a data row.
# -------------------------------------------------------------
# Outputs
#   Logical scalar. TRUE when at least one value is not a number.
# -------------------------------------------------------------
# Code outline
# 1. Test each value as a number
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   is_units_row(df[1, c("heating", "cooling")])
# -------------------------------------------------------------

is_units_row <- function(row_values) {

  # 1. Test each value as a number
  # -------------------------------------------------------------
  {
    values <- trimws(as.character(unlist(row_values)))
    as_number <- suppressWarnings(as.numeric(values))
    answer <- any(nzchar(values) & is.na(as_number))
    rm(values, as_number)
  }

  return(answer)
}
