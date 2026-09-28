# -------------------------------------------------------------
# Function: check_param_valid.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Checks one parameter value against the rules of
# Parameter_config.csv, the same rules the simulation applies:
#   - type:
#       - Integer
#       - Real
#       - Options
#   - range or list of options
# It is used when loading, to decide what counts as valid, and again
# right before saving.
# An empty value is never valid. A parameter with no rule is
# accepted.
# The tolerance of the Integer check is integer_tolerance, read from
# 02_Config/GUI_fallback_values.csv into gui_fallback by GUI_config.R.
# -------------------------------------------------------------
# Inputs
#   value            : The value to check or escape.
#   file_name        : Character. File name of the configuration
#                      file, as Parameter_config.csv names it.
#   param_name       : Character. Name of the parameter.
#   validation_config: Data frame. The rules of
#                      Parameter_config.csv.
# -------------------------------------------------------------
# Outputs
#   Logical scalar: TRUE when the value is valid.
# -------------------------------------------------------------
# Code outline
# 1. Find the rule of the parameter.
# 2. Refuse an empty value; accept a parameter with no rule.
# 3. Check a number against its type and range, or a text against
#    its options.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   check_param_valid(
#     value,
#     file_name,
#     param_name,
#     validation_config)
# -------------------------------------------------------------
# Where this function/script is used
# load_param_file_safe(), validate_param_df_gui()
# -------------------------------------------------------------
# functions/scripts called
# None of this app; base R and shiny only.
# -------------------------------------------------------------

check_param_valid <- function(value, file_name, param_name, validation_config) {
  rules <- validation_config[
    trimws(as.character(validation_config$file_name)) == file_name &
      trimws(as.character(validation_config$parameter_name)) == param_name,
  ]

  value_char <- trimws(as.character(value))
  if (length(value_char) == 0 || is.na(value_char) || !nzchar(value_char)) {
    return(FALSE)
  }

  if (nrow(rules) == 0) {
    return(TRUE)
  }

  type        <- trimws(as.character(rules$type[1]))
  options_str <- trimws(as.character(rules$options[1]))

  if (type %in% c("Integer", "Real")) {
    value_num <- suppressWarnings(as.numeric(value_char))
    if (is.na(value_num)) return(FALSE)
    if (type == "Integer" && abs(value_num - round(value_num)) > gui_fallback$integer_tolerance) return(FALSE)
    if (nzchar(options_str)) {
      range_vals <- suppressWarnings(as.numeric(trimws(strsplit(options_str, ",")[[1]])))
      if (length(range_vals) == 2 && !anyNA(range_vals) &&
          (value_num < range_vals[1] || value_num > range_vals[2])) {
        return(FALSE)
      }
    }
    return(TRUE)
  }

  if (type == "Options") {
    opts <- trimws(strsplit(options_str, ",")[[1]])
    return(value_char %in% opts)
  }

  TRUE
}
