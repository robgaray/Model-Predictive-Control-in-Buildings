# -------------------------------------------------------------
# Function: market_table_row_valid.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Says whether one row of a market table
# (04_Market_config_scheduling.csv or
# 05_Market_config_piloting.csv) is valid: each of its five
# columns is valid against its rule of the parameter catalogue for
# that file, which is:
#   - closure, begin, end and end_optimization: a number inside the
#     range of the rule
#   - aim: one of the options of the rule
# It reads validation_config, which GUI_config.R loads once at
# start. When the catalogue could not be read, any non-empty value
# is accepted: the limited validation the app already announces.
# -------------------------------------------------------------
# Inputs
#   closure          : Value of the closure column of the market
#                      row [h].
#   begin            : Value of the begin column of the market
#                      row [h].
#   end              : Value of the end column of the market row
#                      [h].
#   end_optimization : Value of the end_optimization column of
#                      the market row [h].
#   aim              : Character. The optimization aim of the
#                      market row.
#   file_label       : Character. File name of the market table, as
#                      the catalogue names it.
# -------------------------------------------------------------
# Outputs
#   Logical scalar: TRUE when the row is valid.
# -------------------------------------------------------------
# Code outline
# 1. Check each column against its rule of the catalogue.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   market_table_row_valid(
#     closure,
#     begin,
#     end,
#     end_optimization,
#     aim,
#     file_label)
# -------------------------------------------------------------

market_table_row_valid <- function(closure, begin, end, end_optimization, aim,
                                   file_label) {
  values <- list(closure = closure, begin = begin, end = end,
                 end_optimization = end_optimization, aim = aim)

  for (CONT_001 in names(values)) {
    # check_param_valid is called to check the column against its rule
    # of the catalogue, the same one the simulation applies to it.
    column_ok <- check_param_valid(
      value             = values[[CONT_001]],
      file_name         = file_label,
      param_name        = CONT_001,
      validation_config = validation_config
    )
    if (!column_ok) {
      return(FALSE)
    }
  }

  TRUE
}
