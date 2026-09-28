# -------------------------------------------------------------
# Function: validate_param_df_gui.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Checks every parameter of a flat parameter,value table with
# check_param_valid(), and collects a readable message for each
# invalid one.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame. The table the function works
#                      on (see above).
#   file_label       : Character. File name of the configuration
#                      file, as Parameter_config.csv and the
#                      messages name it.
#   validation_config: Data frame. The rules of
#                      Parameter_config.csv.
# -------------------------------------------------------------
# Outputs
#   Character vector: one message per invalid value, empty when all
#   are valid.
# -------------------------------------------------------------
# Code outline
# 1. Check each row, and collect a message for each failure.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   validate_param_df_gui(df, file_label, validation_config)
# -------------------------------------------------------------
# Where this function/script is used
# GUI_config.R
# -------------------------------------------------------------
# functions/scripts called
# check_param_valid()
# -------------------------------------------------------------

validate_param_df_gui <- function(df, file_label, validation_config) {
  errors <- character(0)
  for (CONT_101 in seq_len(nrow(df))) {
    pname <- trimws(as.character(df$parameter[CONT_101]))
    pval  <- trimws(as.character(df$value[CONT_101]))
    if (!check_param_valid(pval, file_label, pname, validation_config)) {
      errors <- c(errors, sprintf(
        "%s: the value of '%s' ('%s') is not valid.", file_label, pname, pval
      ))
    }
  }
  errors
}
