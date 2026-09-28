# -------------------------------------------------------------
# Function: load_param_file_safe.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads a flat parameter,value file without ever stopping the
# app. Duplicated parameters keep their first value; every
# parameter of the Default_ file that is missing or invalid in
# the file takes its default value; and a message is collected
# for each case, so the app can show it and paint the input in
# red.
# When the Default_ file itself cannot be read, the file is
# loaded as it is and a message says that nothing could be
# reconciled.
# -------------------------------------------------------------
# Inputs
#   filename         : Character. Path of the configuration file,
#                      relative to config_path.
#   file_label       : Character. File name of the configuration
#                      file, as Parameter_config.csv and the
#                      messages name it.
#   default_filename : Character. Path of the Default_ file,
#                      relative to config_path.
#   validation_config: Data frame. The rules of
#                      Parameter_config.csv.
# -------------------------------------------------------------
# Outputs
#   Named list with the elements:
#     - df, with the columns parameter and value
#     - defaulted: parameters that took their default
#     - duplicated: parameters found twice
#     - messages
# -------------------------------------------------------------
# Code outline
# 1. Read the file.
# 2. Flag duplicated parameters, keeping the first value.
# 3. Read the defaults; without them, return the file as it is.
# 4. Take each parameter from the file when valid, from the
#    defaults otherwise.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   load_param_file_safe(
#     filename,
#     file_label,
#     default_filename,
#     validation_config)
# -------------------------------------------------------------
# Where this function/script is used
# GUI_config.R
# -------------------------------------------------------------
# functions/scripts called
# check_param_valid(), read_param_file(), load_default_param_list()
# -------------------------------------------------------------

load_param_file_safe <- function(filename, file_label, default_filename, validation_config) {
  messages <- character(0)
  df <- tryCatch(suppressWarnings(read_param_file(filename)), error = function(e) NULL)
  file_ok <- !is.null(df) && all(c("parameter", "value") %in% names(df))

  if (!file_ok) {
    messages <- c(messages, sprintf(
      "Could not read '%s' (missing file or invalid format).",
      filename
    ))
    df <- data.frame(parameter = character(0), value = character(0),
                     stringsAsFactors = FALSE)
  }

  # ---- Duplicate parameter detection: keep the first occurrence ----
  duplicated_params <- character(0)
  if (nrow(df) > 0) {
    param_col <- trimws(as.character(df$parameter))
    dup_names <- unique(param_col[duplicated(param_col)])
    for (pname in dup_names) {
      duplicated_params <- c(duplicated_params, pname)
      first_val <- trimws(as.character(df$value[param_col == pname]))[1]
      messages <- c(messages, sprintf(
        "%s: parameter '%s' is duplicated in the file. Using its first value ('%s').",
        filename, pname, first_val
      ))
    }
  }

  defaults <- load_default_param_list(default_filename)

  if (is.null(defaults)) {
    messages <- c(messages, sprintf(
      "Default values file '%s' could not be read, so missing or invalid values in '%s' cannot be reconciled. Loading the file contents as-is.",
      default_filename, filename
    ))
    return(list(df = df, defaulted = character(0), duplicated = duplicated_params,
                messages = messages))
  }

  param_names   <- names(defaults)
  final_values  <- character(length(param_names))
  defaulted     <- character(0)

  for (CONT_201 in seq_along(param_names)) {
    pname    <- param_names[CONT_201]
    existing <- df$value[trimws(as.character(df$parameter)) == pname]
    use_default <- TRUE

    if (length(existing) >= 1) {
      candidate <- trimws(as.character(existing[1]))
      if (check_param_valid(candidate, file_label, pname, validation_config)) {
        final_values[CONT_201] <- candidate
        use_default <- FALSE
      }
    }

    if (use_default) {
      final_values[CONT_201] <- defaults[[pname]]
      defaulted <- c(defaulted, pname)
      if (length(existing) == 0) {
        messages <- c(messages, sprintf(
          "%s: parameter '%s' is missing. Using its default value (%s).",
          filename, pname, defaults[[pname]]
        ))
      } else {
        messages <- c(messages, sprintf(
          "%s: parameter '%s' has an invalid value ('%s'). Using its default value (%s).",
          filename, pname, existing[1], defaults[[pname]]
        ))
      }
    }
  }

  list(
    df = data.frame(parameter = param_names, value = final_values,
                    stringsAsFactors = FALSE),
    defaulted = defaulted,
    duplicated = duplicated_params,
    messages  = messages
  )
}
