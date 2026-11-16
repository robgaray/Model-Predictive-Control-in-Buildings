# -------------------------------------------------------------
# Function: describe_param_rule.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Describes, in a short text, which values the parameter
# catalogue accepts for a parameter, so that a message about an
# invalid value tells the user what to write instead.
# -------------------------------------------------------------
# Inputs
#   file_name        : Character. File name of the configuration
#                      file, as the catalogue names it.
#   param_name       : Character. Name of the parameter.
#   validation_config: List. Validation configuration of the GUI,
#                      with the catalogue rows in $rules.
# -------------------------------------------------------------
# Outputs
#   Character scalar: for example "type Real, valid range 0.5 to
#   1" or "valid options: yes, no"; "" when the parameter has no
#   rule.
# -------------------------------------------------------------
# Code outline
# 1. Find the rule of the parameter.
# 2. Describe its type and range, or its options.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   describe_param_rule(file_name, param_name, validation_config)
# -------------------------------------------------------------

describe_param_rule <- function(file_name, param_name, validation_config) {

  # 1. Find the rule of the parameter
  # -------------------------------------------------------------
  {
    rules <- validation_config$rules
    rule  <- rules[rules$file == file_name & rules$parameter == param_name, ,
                   drop = FALSE]
    if (nrow(rule) == 0) {
      return("")
    }
  }

  # 2. Describe its type and range, or its options
  # -------------------------------------------------------------
  {
    type <- trimws(rule$type[1])
    if (type == "Options") {
      text <- paste0("valid options: ", trimws(rule$options[1]))
    } else {
      low   <- trimws(rule$min[1])
      high  <- trimws(rule$max[1])
      text  <- paste0("type ", type)
      if (nzchar(low) && nzchar(high)) {
        text <- paste0(text, ", valid range ", low, " to ", high)
      } else if (nzchar(low)) {
        text <- paste0(text, ", minimum ", low)
      } else if (nzchar(high)) {
        text <- paste0(text, ", maximum ", high)
      }
      rm(low, high)
    }
    rm(rules, rule, type)
    text
  }
}
