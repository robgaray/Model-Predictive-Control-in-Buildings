# -------------------------------------------------------------
# Function: validate_market_table_df_gui.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Checks every row of a market table before saving with
# market_table_row_valid(), and collects a readable message for
# each invalid one.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame. The table the function works
#                      on (see above).
#   file_label       : Character. File name of the configuration
#                      file, as the catalogue and the messages
#                      name it.
# -------------------------------------------------------------
# Outputs
#   Character vector: one message per invalid row, empty when all
#   are valid.
# -------------------------------------------------------------
# Code outline
# 1. Check each row, and collect a message for each failure.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   validate_market_table_df_gui(df, file_label)
# -------------------------------------------------------------

validate_market_table_df_gui <- function(df, file_label) {
  errors <- character(0)
  for (CONT_103 in seq_len(nrow(df))) {
    # market_table_row_valid is called to check the row against the
    # catalogue rules of this table.
    row_ok <- market_table_row_valid(
      closure          = df$closure[CONT_103],
      begin            = df$begin[CONT_103],
      end              = df$end[CONT_103],
      end_optimization = df$end_optimization[CONT_103],
      aim              = df$aim[CONT_103],
      file_label       = file_label
    )
    if (!row_ok) {
      errors <- c(errors, sprintf(
        "%s: the row for market '%s' has invalid values.",
        file_label, df$Market[CONT_103]
      ))
    }
  }
  errors
}
