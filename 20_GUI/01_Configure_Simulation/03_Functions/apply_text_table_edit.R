# -------------------------------------------------------------
# Function: apply_text_table_edit.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Applies one edit of a table cell, as sent by the browser, to the
# table in the app's state. An edit that
# points outside the table is ignored.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame. The table the function works
#                      on (see above).
#   edit_info        : List sent by the browser, or NULL, with:
#                        - row
#                        - col
#                        - value
# -------------------------------------------------------------
# Outputs
#   Data frame: the table with the edit applied.
# -------------------------------------------------------------
# Code outline
# 1. Check the row and column exist.
# 2. Write the new value.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   apply_text_table_edit(df, edit_info)
# -------------------------------------------------------------

apply_text_table_edit <- function(df, edit_info) {
  if (is.null(edit_info)) {
    return(df)
  }

  row_idx  <- as.integer(edit_info$row)
  col_name <- as.character(edit_info$col)

  if (!is.na(row_idx) &&
      row_idx >= 1 &&
      row_idx <= nrow(df) &&
      col_name %in% names(df)) {
    df[row_idx, col_name] <- as.character(edit_info$value)
  }

  df
}
