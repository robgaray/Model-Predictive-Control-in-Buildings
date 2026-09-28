# -------------------------------------------------------------
# Script: 04_subset_main_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Cuts Main_df down to the period to simulate, so that a short run
# (for testing or diagnosis) needs no change to the data files.
# Two parameters of parameters$debug_and_config select the period:
#   - month_subset: 0 keeps the whole year; a value from 1 to 12
#     keeps only the rows of that month
#   - period_subset: 0 keeps every remaining row; any other value
#     keeps only that many rows, counted from the start, or all of
#     them if there are fewer
# The month is applied first, then the number of rows.
# It runs after 03_climate_priority.R, which needs the whole year to
# tag the first days of the period.
# -------------------------------------------------------------
# Inputs
#   Main_df, with its time column, still covering the whole year.
#   parameters$debug_and_config : month_subset and period_subset.
# -------------------------------------------------------------
# Outputs
#   Main_df, cut to the selected month and number of rows. Nothing
#     else is modified.
# -------------------------------------------------------------
# Code outline
# 1. Keep the rows of the selected month, if one is selected.
# 2. Keep the first period_subset rows, if a number is set.
# -------------------------------------------------------------
# Usage instructions
# source(file.path("30_Simulation", "04_Scripts", "04_subset_main_df.R"))
#   Not called: sourced by Main.R (step 5), after the climate
#   priority and before the profiles.
# -------------------------------------------------------------
# Where this function/script is used
# Sourced by 30_Simulation/Main.R (step 5).
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

{
  month_subset  <- parameters$debug_and_config$month_subset
  period_subset <- parameters$debug_and_config$period_subset

  # 1. Month
  if (!is.null(month_subset) && month_subset != 0) {
    Main_df <- Main_df[month(Main_df$time) == month_subset, ]
    cat("Month ", month_subset, " selected\n")
  } else {
    cat("Full year selected\n")
  }

  # 2. Number of rows
  if (!is.null(period_subset) && period_subset > nrow(Main_df)) {
    period_subset <- nrow(Main_df)
  }

  if (!is.null(period_subset) && period_subset != 0) {
    Main_df <- Main_df[1:period_subset, ]
  }
  rm(month_subset, period_subset)
}
