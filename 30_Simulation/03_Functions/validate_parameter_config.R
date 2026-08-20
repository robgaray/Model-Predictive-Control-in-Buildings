# -------------------------------------------------------------
# Function: validate_parameter_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Validates a named list of parameter values against the rules
# defined in Parameter_config.csv for a given file name.
# For each matching rule the function checks:
#   - Integer : value is numeric, whole number, and within [min, max]
#   - Real    : value is numeric and within [min, max] (when options set)
#   - Options : as.character(value) is one of the allowed options
#   - Text    : no additional constraint beyond existence
# Validation failures trigger stop() for output == "Error" or
# warning() for output == "Warning".
# -------------------------------------------------------------
# Arguments
#   values            Named list. parameter_name -> raw value (character
#                     or numeric) as read from the CSV file.
#   file_name         Character. Base name of the config file
#                     (e.g. "11_Model_parameters.csv").
#   validation_config Data frame. Content of Parameter_config.csv.
# -------------------------------------------------------------
# Returns
#   invisible(TRUE) on success; stops on first Error-class failure.
# -------------------------------------------------------------
# Where this function/script is used
# Called by read_and_validate_parameter_csv().
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

validate_parameter_config <- function(values, file_name, validation_config) {

  rules <- validation_config[trimws(as.character(validation_config$file_name)) == file_name, ]

  if (nrow(rules) == 0) {
    return(invisible(TRUE))
  }

  for (CONT_001 in seq_len(nrow(rules))) {

    param_name  <- trimws(as.character(rules$parameter_name[CONT_001]))
    type        <- trimws(as.character(rules$type[CONT_001]))
    output      <- trimws(as.character(rules$output[CONT_001]))
    options_str <- trimws(as.character(rules$options[CONT_001]))

    value <- values[[param_name]]

    if (is.null(value) || (length(value) == 1 && is.na(value))) {
      msg <- paste0("Parameter '", param_name, "' not found in ", file_name)
      if (output == "Error") stop(msg) else warning(msg)
      next
    }

    value_char <- trimws(as.character(value))
    value_num  <- suppressWarnings(as.numeric(value_char))

    if (type == "Integer") {

      if (is.na(value_num)) {
        msg <- paste0("Parameter '", param_name, "' must be numeric in ",
                      file_name, ". Got: '", value_char, "'")
        if (output == "Error") stop(msg) else warning(msg)
      } else {
        if (abs(value_num - round(value_num)) > 1e-9) {
          msg <- paste0("Parameter '", param_name, "' = ", value_num,
                        " must be an integer in ", file_name)
          if (output == "Error") stop(msg) else warning(msg)
        }
        if (!is.na(options_str) && nzchar(options_str)) {
          range_vals <- as.numeric(trimws(strsplit(options_str, ",")[[1]]))
          if (length(range_vals) == 2 &&
              (value_num < range_vals[1] || value_num > range_vals[2])) {
            msg <- paste0("Parameter '", param_name, "' = ", value_num,
                          " is outside [", range_vals[1], ", ", range_vals[2],
                          "] in ", file_name)
            if (output == "Error") stop(msg) else warning(msg)
          }
        }
      }

    } else if (type == "Real") {

      if (is.na(value_num)) {
        msg <- paste0("Parameter '", param_name, "' must be numeric in ",
                      file_name, ". Got: '", value_char, "'")
        if (output == "Error") stop(msg) else warning(msg)
      } else if (!is.na(options_str) && nzchar(options_str)) {
        range_vals <- as.numeric(trimws(strsplit(options_str, ",")[[1]]))
        if (length(range_vals) == 2 &&
            (value_num < range_vals[1] || value_num > range_vals[2])) {
          msg <- paste0("Parameter '", param_name, "' = ", value_num,
                        " is outside [", range_vals[1], ", ", range_vals[2],
                        "] in ", file_name)
          if (output == "Error") stop(msg) else warning(msg)
        }
      }

    } else if (type == "Options") {

      opt_vals <- trimws(strsplit(options_str, ",")[[1]])
      if (!value_char %in% opt_vals) {
        msg <- paste0("Parameter '", param_name, "' = '", value_char,
                      "' is not a valid option in ", file_name,
                      ". Valid options: ", paste(opt_vals, collapse = ", "))
        if (output == "Error") stop(msg) else warning(msg)
      }

    }
    # type == "Text": existence already confirmed above; no further constraint.
  }

  rm(CONT_001)
  invisible(TRUE)
}
