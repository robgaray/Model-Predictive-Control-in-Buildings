# -------------------------------------------------------------
# Function: validate_param_df_gui.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Checks every parameter of a flat parameter,value table with
# check_param_valid(), and collects a readable message for each
# invalid one, with the values the catalogue accepts for it.
# -------------------------------------------------------------
# Inputs
#   df               : Data frame. The table the function works
#                      on (see above).
#   file_label       : Character. File name of the configuration
#                      file, as the catalogue and the messages
#                      name it.
#   validation_config: Named list. The rules of the catalogue and
#                      the integer tolerance, as load_gui_catalogue()
#                      returns them.
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

validate_param_df_gui <- function(df, file_label, validation_config) {
  errors <- character(0)
  for (CONT_101 in seq_len(nrow(df))) {
    pname <- trimws(as.character(df$parameter[CONT_101]))
    pval  <- trimws(as.character(df$value[CONT_101]))
    if (!check_param_valid(pval, file_label, pname, validation_config)) {
      # describe_param_rule is called so that the message says
      # which values the catalogue accepts for the parameter.
      rule_text <- describe_param_rule(
        file_name         = file_label,
        param_name        = pname,
        validation_config = validation_config
      )
      errors <- c(errors, sprintf(
        "%s: the value of '%s' ('%s') is not valid%s.", file_label, pname,
        pval, if (nzchar(rule_text)) paste0(" (", rule_text, ")") else ""
      ))
      rm(rule_text)
    }
  }
  errors
}
