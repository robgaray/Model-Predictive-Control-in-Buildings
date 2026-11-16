# -------------------------------------------------------------
# Function: subset_period.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Cuts a table of the simulation down to the period to simulate, so
# that a short run (for testing or diagnosis) needs no change to the
# data files. It is applied to Main_df and to the table of each asset
# alike: the rows it keeps depend only on the time column, which the
# tables share, so they keep the same rows.
# Two parameters select the period:
#   - month_subset: 0 keeps the whole year; a value from 1 to 12
#     keeps only the rows of that month
#   - period_subset: 0 keeps every remaining row; any other value
#     keeps only that many rows, counted from the start, or all of
#     them if there are fewer
# The month is applied first, then the number of rows.
# It is meant to run after prepare_climate.R, which needs the whole
# year to tag the first days of the period.
# -------------------------------------------------------------
# Inputs
#   simulation_table : data frame, Main_df or the table of an asset,
#                      with its time column, still covering the
#                      whole year.
#   month_subset     : Integer, or NULL. parameters$debug_and_config$
#                      month_subset. 0 or NULL keeps the whole year.
#   period_subset    : Numeric, or NULL. parameters$debug_and_config$
#                      period_subset. 0 or NULL keeps every row.
# -------------------------------------------------------------
# Outputs
#   simulation_table, cut to the selected month and number of rows.
#   Nothing else is modified.
# -------------------------------------------------------------
# Code outline
# 1. Keep the rows of the selected month, if one is selected.
# 2. Keep the first period_subset rows, if a number is set.
# -------------------------------------------------------------
# Usage instructions
# Main_df <- subset_period(
#   simulation_table = Main_df,
#   month_subset     = parameters$debug_and_config$month_subset,
#   period_subset    = parameters$debug_and_config$period_subset
# )
# -------------------------------------------------------------
subset_period <- function(simulation_table,
                          month_subset,
                          period_subset
                          ) {

  # -------------------------------------------------------------
  # 1. Month
  # -------------------------------------------------------------
  {
    if (!is.null(month_subset) && month_subset != 0) {
      simulation_table <- simulation_table[month(simulation_table$time) == month_subset, ]
    }
  }

  # -------------------------------------------------------------
  # 2. Number of rows
  # -------------------------------------------------------------
  {
    if (!is.null(period_subset) && period_subset > nrow(simulation_table)) {
      period_subset <- nrow(simulation_table)
    }

    if (!is.null(period_subset) && period_subset != 0) {
      simulation_table <- simulation_table[1:period_subset, ]
    }
  }

  return(simulation_table)
}
