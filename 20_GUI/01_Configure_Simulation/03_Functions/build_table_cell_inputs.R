# -------------------------------------------------------------
# Function: build_table_cell_inputs.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Turns every editable cell of a table into an HTML text input,
# so the table can be edited in place; read-only columns stay as
# text, and rows that came from the defaults are shown in red.
# The row controls are added at the end.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame. The table the function works
#                      on (see above).
#   prefix           : Character. Prefix of the input ids of the
#                      table or tab.
#   defaulted_rows   : Integer vector. Rows whose values came
#                      from the defaults. Default integer(0).
#   readonly_cols    : Character vector. Columns shown as text,
#                      not editable. Default character(0).
# -------------------------------------------------------------
# Outputs
#   Data frame of HTML strings, ready for DT with escape = FALSE.
# -------------------------------------------------------------
# Code outline
# 1. Replace each editable cell with a text input.
# 2. Add the row controls.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   build_table_cell_inputs(
#     df,
#     prefix,
#     defaulted_rows,
#     readonly_cols)
# -------------------------------------------------------------
# Where this function/script is used
# GUI_config.R
# -------------------------------------------------------------
# functions/scripts called
# add_row_controls(), escape_html_attr()
# -------------------------------------------------------------

build_table_cell_inputs <- function(df, prefix, defaulted_rows = integer(0),
                                     readonly_cols = character(0)) {
  if (nrow(df) == 0) {
    return(add_row_controls(df, prefix))
  }

  data_cols <- names(df)
  for (col_name in data_cols) {
    if (col_name %in% readonly_cols) {
      df[[col_name]] <- as.character(df[[col_name]])
      next
    }
    df[[col_name]] <- mapply(
      function(cell_value, row_idx) {
        cell_style <- if (row_idx %in% defaulted_rows) {
          " style=\"color:#c0392b; font-weight:600;\""
        } else {
          ""
        }
        sprintf(
          "<input type='text' class='form-control input-sm table-cell-input' data-prefix='%s' data-row='%d' data-col='%s' value=\"%s\"%s/>",
          prefix,
          row_idx,
          col_name,
          escape_html_attr(cell_value),
          cell_style
        )
      },
      df[[col_name]],
      seq_len(nrow(df)),
      USE.NAMES = FALSE
    )
  }

  add_row_controls(df, prefix)
}
