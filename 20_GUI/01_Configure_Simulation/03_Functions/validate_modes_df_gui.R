# -------------------------------------------------------------
# Function: validate_modes_df_gui.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Checks every row of the modes table before saving, and collects
# a readable message for each row whose heating or cooling
# setpoint is not a number.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame. The table the function works
#                      on (see above).
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
#   validate_modes_df_gui(df)
# -------------------------------------------------------------
# Where this function/script is used
# GUI_config.R
# -------------------------------------------------------------
# functions/scripts called
# None of this app; base R and shiny only.
# -------------------------------------------------------------

validate_modes_df_gui <- function(df) {
  errors <- character(0)
  for (CONT_102 in seq_len(nrow(df))) {
    heating_num <- suppressWarnings(as.numeric(df$heating[CONT_102]))
    cooling_num <- suppressWarnings(as.numeric(df$cooling[CONT_102]))
    if (is.na(heating_num) || is.na(cooling_num)) {
      errors <- c(errors, sprintf(
        "Modes: row %d has non-numeric values (heating='%s', cooling='%s').",
        CONT_102, df$heating[CONT_102], df$cooling[CONT_102]
      ))
    }
  }
  errors
}
