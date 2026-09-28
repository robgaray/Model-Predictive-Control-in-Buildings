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
#                      file, as Parameter_config.csv and the
#                      messages name it.
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
# Where this function/script is used
# GUI_config.R
# -------------------------------------------------------------
# functions/scripts called
# market_table_row_valid()
# -------------------------------------------------------------

validate_market_table_df_gui <- function(df, file_label) {
  errors <- character(0)
  for (CONT_103 in seq_len(nrow(df))) {
    if (!market_table_row_valid(df$closure[CONT_103], df$begin[CONT_103],
                                df$end[CONT_103], df$end_optimization[CONT_103],
                                df$aim[CONT_103])) {
      errors <- c(errors, sprintf(
        "%s: the row for market '%s' has invalid values.",
        file_label, df$Market[CONT_103]
      ))
    }
  }
  errors
}
