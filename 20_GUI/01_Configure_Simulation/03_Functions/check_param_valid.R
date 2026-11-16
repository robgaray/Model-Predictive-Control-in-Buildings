# -------------------------------------------------------------
# Function: check_param_valid.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Checks one parameter value against its rule of the parameter
# catalogue, the same rule the simulation applies:
#   - type:
#       - Integer
#       - Real
#       - Options
#       - Text
#   - range (min and max, an empty end meaning no bound) or list
#     of options
#   - output: only a rule whose output is Error makes a value
#     invalid; a breach of a rule whose output is Warning is
#     accepted, as the simulation only warns about it
# It is used when loading, to decide what counts as valid, and again
# right before saving.
# An empty value is never valid. A parameter with no rule is
# accepted.
# The tolerance of the Integer check is the integer_tolerance of
# validation_config. When it is NA, an Integer must be exactly a
# whole number.
# -------------------------------------------------------------
# Inputs
#   value            : The value to check or escape.
#   file_name        : Character. File name of the configuration
#                      file, as the catalogue names it.
#   param_name       : Character. Name of the parameter.
#   validation_config: Named list. The rules of the catalogue and
#                      the integer tolerance, as load_gui_catalogue()
#                      returns them.
# -------------------------------------------------------------
# Outputs
#   Logical scalar: TRUE when the value is valid.
# -------------------------------------------------------------
# Code outline
# 1. Find the rule of the parameter.
# 2. Refuse an empty value; accept a parameter with no rule.
# 3. Check a number against its type and range, or a text against
#    its options.
# 4. Let a breach invalidate the value only when the rule's output
#    is Error.
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

check_param_valid <- function(value, file_name, param_name, validation_config) {

  # 1. Find the rule of the parameter
  # -------------------------------------------------------------
  {
    rules <- validation_config$rules
    rule  <- rules[rules$file == file_name & rules$parameter == param_name, ,
                   drop = FALSE]
  }

  # 2. Refuse an empty value; accept a parameter with no rule
  # -------------------------------------------------------------
  {
    value_char <- trimws(as.character(value))
    if (length(value_char) == 0 || is.na(value_char) || !nzchar(value_char)) {
      return(FALSE)
    }

    if (nrow(rule) == 0) {
      return(TRUE)
    }
  }

  # 3. Check a number against its type and range, or a text against
  # its options
  # -------------------------------------------------------------
  {
    type   <- rule$type[1]
    breach <- FALSE

    if (type %in% c("Integer", "Real")) {
      value_num <- suppressWarnings(as.numeric(value_char))
      if (is.na(value_num)) {
        breach <- TRUE
      } else {
        tolerance <- validation_config$integer_tolerance
        if (is.null(tolerance) || is.na(tolerance)) {
          tolerance <- 0
        }
        low  <- suppressWarnings(as.numeric(rule$min[1]))
        high <- suppressWarnings(as.numeric(rule$max[1]))
        breach <- (type == "Integer" &&
                     abs(value_num - round(value_num)) > tolerance) ||
          (!is.na(low) && value_num < low) ||
          (!is.na(high) && value_num > high)
        rm(tolerance, low, high)
      }
      rm(value_num)
    } else if (type == "Options") {
      options <- trimws(strsplit(rule$options[1], ",")[[1]])
      breach  <- !value_char %in% options
      rm(options)
    }
  }

  # 4. Let a breach invalidate the value only when the output is Error
  # -------------------------------------------------------------
  {
    return(!(breach && rule$output[1] == "Error"))
  }
}
