# -------------------------------------------------------------
# Function: type_parameter_values.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives each raw value read from a parameter/value configuration
# file the type of its rule in the parameter catalogue. The type of
# each value follows its rule:
#   - Integer and Real : a number
#   - Options          : a number when every allowed option is a
#                        number (a 0/1 switch, for example), and text
#                        otherwise (an aim code, for example)
#   - Text             : text
# Text values are returned without surrounding spaces.
# -------------------------------------------------------------
# Inputs
#   raw_values : Named list. parameter name -> raw value, already
#                validated.
#   rules      : Data frame. The rows of the parameter catalogue of
#                the file the values come from (columns parameter,
#                type and options).
# -------------------------------------------------------------
# Outputs
#   Named list. One element per raw value, in its order, in the type
#   of its rule.
# -------------------------------------------------------------
# Code outline
# 1. Convert each value by the type of its rule
# -------------------------------------------------------------
# Usage instructions
# values <- type_parameter_values(raw_values, rules)
# -------------------------------------------------------------

type_parameter_values <- function(raw_values, rules) {

  # 1. Convert each value by the type of its rule
  # -------------------------------------------------------------
  {
    values <- lapply(names(raw_values), function(name) {
      rule  <- rules[rules$parameter == name, ]
      value <- trimws(as.character(raw_values[[name]]))
      if (rule$type %in% c("Integer", "Real")) {
        return(as.numeric(value))
      }
      if (rule$type == "Options") {
        options <- trimws(strsplit(rule$options, ",")[[1]])
        if (!anyNA(suppressWarnings(as.numeric(options)))) {
          return(as.numeric(value))
        }
      }
      value
    })
    names(values) <- names(raw_values)
  }

  return(values)
}
