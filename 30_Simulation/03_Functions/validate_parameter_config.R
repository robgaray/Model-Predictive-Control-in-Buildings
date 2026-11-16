# -------------------------------------------------------------
# Function: validate_parameter_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Validates a named list of parameter values against the rules of
# the parameter catalogue (Parameter_catalogue.csv) for a given file
# name. For each matching rule the function checks:
#   - Integer : value is numeric, a whole number within the integer
#               tolerance, and within [min, max]
#   - Real    : value is numeric and within [min, max]
#   - Options : as.character(value) is one of the allowed options
#   - Text    : no additional constraint beyond existence
# An empty min or max means no bound on that side.
# A parameter that is missing stops the run (or warns, as the rule
# says), and the message gives its default value from the catalogue:
# the value is never filled in silently.
# Validation failures trigger stop() for output == "Error" or
# warning() for output == "Warning".
# Three things stop the run whatever the output of the rules, because
# they mean the file and its rules do not match:
#   - a file with no rule at all;
#   - a parameter of the file that no rule describes, usually a name
#     written wrong or left over. The message names the closest rule;
#   - a rule whose type is none of the four above.
# -------------------------------------------------------------
# Arguments
#   values            Named list. parameter_name -> raw value (character
#                     or numeric) as read from the CSV file.
#   file_name         Character. Base name of the config file
#                     (e.g. "11_Model_parameters.csv").
#   validation_config Named list, as load_parameter_catalogue()
#                     returns it: the rules of the catalogue and the
#                     integer tolerance.
# -------------------------------------------------------------
# Returns
#   invisible(TRUE) on success; stops on first Error-class failure.
# -------------------------------------------------------------
# Inputs
#   values : the named list of values read from a configuration
#     file.
#   file_name : the name the catalogue files its rules
#     under, e.g. "09_Reward_parameters.csv".
#   validation_config : the parameter catalogue, already read by
#     load_parameter_catalogue().
# -------------------------------------------------------------
# Outputs
#   TRUE, invisibly, when every rule passes. Otherwise it stops,
#     naming:
#       - the parameter
#       - the rule it broke
#       - its value
# -------------------------------------------------------------
# Code outline
# 1. Keep the rules filed under this file name. Stop when there are
#    none, or when the file holds a parameter no rule describes.
# 2. Check each rule against its one value: the type, the range
#    and, for an options rule, the allowed set.
# 3. Stop on the first breach, or warn, as the rule's output says.
# -------------------------------------------------------------
# Usage instructions
#   validate_parameter_config(values, "09_Reward_parameters.csv",
#                             validation_config)
# -------------------------------------------------------------

validate_parameter_config <- function(values, file_name, validation_config) {

  rules <- validation_config$rules[validation_config$rules$file == file_name, ]

  if (nrow(rules) == 0) {
    stop("No rule describes the parameters of ", file_name, ". Every ",
         "parameter of a configuration file needs one rule in the ",
         "parameter catalogue.")
  }

  # A parameter the file holds and no rule describes is reported with
  # the rule name closest to it, which is usually the one meant.
  rule_names <- rules$parameter
  unknown    <- setdiff(names(values), rule_names)
  if (length(unknown) > 0) {
    closest <- vapply(unknown, function(one_name) {
      rule_names[which.min(adist(one_name, rule_names))]
    }, character(1))
    stop("Parameter not described by any rule of ", file_name, ": ",
         paste0("'", unknown, "' (closest rule: '", closest, "')",
                collapse = ", "))
  }
  rm(list = c("rule_names", "unknown"))

  for (CONT_001 in seq_len(nrow(rules))) {

    param_name  <- rules$parameter[CONT_001]
    type        <- rules$type[CONT_001]
    output      <- rules$output[CONT_001]
    options_str <- rules$options[CONT_001]
    default     <- rules$default[CONT_001]
    # An empty end of the range means no bound on that side.
    range_vals  <- suppressWarnings(as.numeric(c(rules$min[CONT_001],
                                                 rules$max[CONT_001])))
    range_vals[is.na(range_vals)] <- c(-Inf, Inf)[is.na(range_vals)]

    value <- values[[param_name]]

    if (is.null(value) || (length(value) == 1 && is.na(value))) {
      msg <- paste0("Parameter '", param_name, "' not found in ", file_name,
                    if (nzchar(default) && default != "-")
                      paste0(". Its default value is ", default) else "")
      if (output == "Error") stop(msg) else warning(msg, call. = FALSE)
      next
    }

    value_char <- trimws(as.character(value))
    value_num  <- suppressWarnings(as.numeric(value_char))

    if (type == "Integer") {

      if (is.na(value_num)) {
        msg <- paste0("Parameter '", param_name, "' must be numeric in ",
                      file_name, ". Got: '", value_char, "'")
        if (output == "Error") stop(msg) else warning(msg, call. = FALSE)
      } else {
        if (abs(value_num - round(value_num)) >
            validation_config$integer_tolerance) {
          msg <- paste0("Parameter '", param_name, "' = ", value_num,
                        " must be an integer in ", file_name)
          if (output == "Error") stop(msg) else warning(msg, call. = FALSE)
        }
        if (value_num < range_vals[1] || value_num > range_vals[2]) {
          msg <- paste0("Parameter '", param_name, "' = ", value_num,
                        " is outside [", range_vals[1], ", ", range_vals[2],
                        "] in ", file_name)
          if (output == "Error") stop(msg) else warning(msg, call. = FALSE)
        }
      }

    } else if (type == "Real") {

      if (is.na(value_num)) {
        msg <- paste0("Parameter '", param_name, "' must be numeric in ",
                      file_name, ". Got: '", value_char, "'")
        if (output == "Error") stop(msg) else warning(msg, call. = FALSE)
      } else if (value_num < range_vals[1] || value_num > range_vals[2]) {
        msg <- paste0("Parameter '", param_name, "' = ", value_num,
                      " is outside [", range_vals[1], ", ", range_vals[2],
                      "] in ", file_name)
        if (output == "Error") stop(msg) else warning(msg, call. = FALSE)
      }

    } else if (type == "Options") {

      opt_vals <- trimws(strsplit(options_str, ",")[[1]])
      if (!value_char %in% opt_vals) {
        msg <- paste0("Parameter '", param_name, "' = '", value_char,
                      "' is not a valid option in ", file_name,
                      ". Valid options: ", paste(opt_vals, collapse = ", "))
        if (output == "Error") stop(msg) else warning(msg, call. = FALSE)
      }

    } else if (type != "Text") {
      stop("Rule of parameter '", param_name, "' in ", file_name,
           " has an unknown type: '", type, "'. Valid types: Integer, ",
           "Real, Options, Text.")
    }
    # type == "Text": existence already confirmed above; no further constraint.
  }

  rm(list = "CONT_001")
  invisible(TRUE)
}
