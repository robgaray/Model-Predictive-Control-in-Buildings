# -------------------------------------------------------------
# Function: update_df_from_inputs.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Copies the values the user typed in the inputs of a tab back
# into its parameter,value table. The input of each parameter is
# named prefix + parameter.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame. The table the function works
#                      on (see above).
#   prefix           : Character. Prefix of the input ids of the
#                      table or tab.
#   input            : The Shiny input object of the session.
# -------------------------------------------------------------
# Outputs
#   Data frame: the table with the values of the inputs.
# -------------------------------------------------------------
# Code outline
# 1. For each parameter with an input, take the input's value.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   update_df_from_inputs(df, prefix, input)
# -------------------------------------------------------------

update_df_from_inputs <- function(df, prefix, input) {
  for (CONT_001 in seq_len(nrow(df))) {
    param_name <- as.character(df$parameter[CONT_001])
    input_id   <- paste0(prefix, param_name)
    if (!is.null(input[[input_id]])) {
      df$value[CONT_001] <- as.character(input[[input_id]])
    }
  }
  df
}
