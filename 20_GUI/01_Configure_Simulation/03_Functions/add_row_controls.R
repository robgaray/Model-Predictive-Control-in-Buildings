# -------------------------------------------------------------
# Function: add_row_controls.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Adds three link columns to an editable table - Add above, Add
# below and Delete - each sending the row number to the server as
# a Shiny input named after the table's prefix.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame. The table the function works
#                      on (see above).
#   prefix           : Character. Prefix of the input ids of the
#                      table or tab.
# -------------------------------------------------------------
# Outputs
#   Data frame: the table with the three link columns.
# -------------------------------------------------------------
# Code outline
# 1. Build the three links of each row.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   add_row_controls(df, prefix)
# -------------------------------------------------------------
# Where this function/script is used
# build_table_cell_inputs()
# -------------------------------------------------------------
# functions/scripts called
# None of this app; base R and shiny only.
# -------------------------------------------------------------

add_row_controls <- function(df, prefix) {
  if (nrow(df) == 0) {
    df <- data.frame(stringsAsFactors = FALSE)
  }

  n_rows <- nrow(df)
  if (n_rows > 0) {
    df$`Add above` <- sprintf(
      "<a href='#' onclick=\"Shiny.setInputValue('%s_add_above', %d, {priority: 'event'});\">Add above</a>",
      prefix,
      seq_len(n_rows)
    )
    df$`Add below` <- sprintf(
      "<a href='#' onclick=\"Shiny.setInputValue('%s_add_below', %d, {priority: 'event'});\">Add below</a>",
      prefix,
      seq_len(n_rows)
    )
    df$`Delete` <- sprintf(
      "<a href='#' onclick=\"Shiny.setInputValue('%s_delete', %d, {priority: 'event'});\">Delete</a>",
      prefix,
      seq_len(n_rows)
    )
  }

  df
}
