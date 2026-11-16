# -------------------------------------------------------------
# Function: table_pending.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Tells whether an editable table has something pending for the
# user: a row that took a default, or a content that differs from
# the one that was last read from disk or saved, in its values, its
# columns or the number of its rows.
# -------------------------------------------------------------
# Inputs
#   df             : Data frame. The state of the table.
#   baseline_df    : Data frame. The table as last read from disk or
#                    saved.
#   defaulted_rows : Integer vector. The rows that took a default.
# -------------------------------------------------------------
# Outputs
#   Logical. TRUE when something is pending.
# -------------------------------------------------------------
# Code outline
# 1. Look for a row with a default.
# 2. Compare the table with the baseline.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   table_pending(df, baseline_df, defaulted_rows)
# -------------------------------------------------------------

table_pending <- function(df, baseline_df, defaulted_rows) {

  # -------------------------------------------------------------
  # 1. Look for a row with a default
  # -------------------------------------------------------------
  {
    if (length(defaulted_rows) > 0) {
      return(TRUE)
    }
  }

  # -------------------------------------------------------------
  # 2. Compare the table with the baseline
  # -------------------------------------------------------------
  {
    if (!identical(names(df), names(baseline_df)) ||
        nrow(df) != nrow(baseline_df)) {
      return(TRUE)
    }
    # normalize_cell_values is called on each column of both tables
    # so that two ways of writing the same number are not taken as a
    # change.
    current <- lapply(df, normalize_cell_values)
    saved   <- lapply(baseline_df, normalize_cell_values)
  }

  return(!identical(current, saved))
}
