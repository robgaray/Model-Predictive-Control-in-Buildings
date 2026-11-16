# -------------------------------------------------------------
# Function: insert_row.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Inserts a row into a table at a given position, clamped to the
# ends of the table.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame. The table the function works
#                      on (see above).
#   index            : Integer. Position the row is inserted at.
#   template_row     : Data frame of one row. The row to insert.
# -------------------------------------------------------------
# Outputs
#   Data frame: the table with the row inserted.
# -------------------------------------------------------------
# Code outline
# 1. Clamp the position.
# 2. Bind the row before, after or in the middle.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   insert_row(df, index, template_row)
# -------------------------------------------------------------

insert_row <- function(df, index, template_row) {
  if (nrow(df) == 0) {
    return(template_row)
  }

  index <- max(1, min(index, nrow(df) + 1))

  if (index == 1) {
    return(rbind(template_row, df))
  }

  if (index == nrow(df) + 1) {
    return(rbind(df, template_row))
  }

  rbind(
    df[1:(index - 1), , drop = FALSE],
    template_row,
    df[index:nrow(df), , drop = FALSE]
  )
}
