# -------------------------------------------------------------
# Function: market_table_row_valid.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Says whether one row of a market table
# (04_Market_config_scheduling.csv or
# 05_Market_config_piloting.csv) is valid: its four time columns
# are non-negative numbers and its aim is one of:
#   - O
#   - E
#   - O+F
#   - E+F
# The allowed aims are market_aim_options, which GUI_config.R takes
# from Parameter_config.csv (the aims of 03_Market_config.csv). When
# that file could not be read they are NULL, and any non-empty aim is
# accepted: the limited validation the app already announces.
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
# -------------------------------------------------------------
# Outputs
#   Logical scalar: TRUE when the row is valid.
# -------------------------------------------------------------
# Code outline
# 1. Check the four time columns are non-negative numbers.
# 2. Check the aim is one of the four allowed.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   market_table_row_valid(
#     closure,
#     begin,
#     end,
#     end_optimization,
#     aim)
# -------------------------------------------------------------
# Where this function/script is used
# load_market_table_file_safe(), validate_market_table_df_gui()
# -------------------------------------------------------------
# functions/scripts called
# None of this app; base R and shiny only.
# -------------------------------------------------------------

market_table_row_valid <- function(closure, begin, end, end_optimization, aim) {
  nums <- suppressWarnings(as.numeric(c(closure, begin, end, end_optimization)))
  if (anyNA(nums) || any(nums < 0)) return(FALSE)
  if (is.null(market_aim_options)) {
    return(nzchar(trimws(as.character(aim))))
  }
  trimws(as.character(aim)) %in% market_aim_options
}
