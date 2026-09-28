# -------------------------------------------------------------
# Function: load_modes_file_safe.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the modes table (13_Modes_setpoints.csv) without ever
# stopping the app. A row that is missing or invalid takes the
# same row of the Default_ file; when there is none, a generic
# mode (heating 21, cooling 25) is used. A message is collected
# for each case.
# The generic mode is read from 02_Config/GUI_fallback_values.csv
# (gui_fallback, loaded by GUI_config.R).
# -------------------------------------------------------------
# Inputs
#   filename         : Character. Path of the configuration file,
#                      relative to config_path.
#   default_filename : Character. Path of the Default_ file,
#                      relative to config_path.
# -------------------------------------------------------------
# Outputs
#   Named list with the elements:
#     - df, with the columns:
#         - mode
#         - heating
#         - cooling
#     - defaulted_rows
#     - messages
# -------------------------------------------------------------
# Code outline
# 1. Read the file and its defaults.
# 2. When the file is unusable, return the defaults.
# 3. Take each row from the file when valid, from the defaults
#    otherwise.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   load_modes_file_safe(filename, default_filename)
# -------------------------------------------------------------
# Where this function/script is used
# GUI_config.R
# -------------------------------------------------------------
# functions/scripts called
# modes_row_valid(), read_table_file()
# -------------------------------------------------------------

load_modes_file_safe <- function(filename, default_filename) {
  messages <- character(0)
  df <- tryCatch(suppressWarnings(read_table_file(filename)), error = function(e) NULL)

  defaults_df <- tryCatch(suppressWarnings(read_table_file(default_filename)), error = function(e) NULL)
  defaults_ok <- !is.null(defaults_df) &&
    all(c("mode", "heating", "cooling") %in% names(defaults_df)) &&
    nrow(defaults_df) > 0
  if (!defaults_ok) {
    messages <- c(messages, sprintf(
      "Default modes file '%s' could not be read; no defaults are available for '%s'.",
      default_filename, filename
    ))
  }

  file_ok <- !is.null(df) && all(c("mode", "heating", "cooling") %in% names(df)) && nrow(df) > 0
  if (!file_ok) {
    messages <- c(messages, sprintf(
      "Could not read '%s' (missing, empty file, or invalid columns).%s",
      filename,
      if (defaults_ok) " Loading the default modes instead." else ""
    ))
    if (defaults_ok) {
      return(list(df = defaults_df, defaulted_rows = seq_len(nrow(defaults_df)),
                  messages = messages))
    }
    return(list(
      df = data.frame(mode = character(0), heating = character(0),
                      cooling = character(0), stringsAsFactors = FALSE),
      defaulted_rows = integer(0), messages = messages
    ))
  }

  if (!defaults_ok) {
    return(list(df = df, defaulted_rows = integer(0), messages = messages))
  }

  n_rows <- max(nrow(df), nrow(defaults_df))
  result <- data.frame(
    mode = character(n_rows), heating = character(n_rows),
    cooling = character(n_rows), stringsAsFactors = FALSE
  )
  defaulted_rows <- integer(0)

  for (CONT_202 in seq_len(n_rows)) {
    has_loaded  <- CONT_202 <= nrow(df)
    has_default <- CONT_202 <= nrow(defaults_df)

    if (has_loaded && modes_row_valid(df$mode[CONT_202], df$heating[CONT_202],
                                       df$cooling[CONT_202])) {
      result$mode[CONT_202]    <- as.character(df$mode[CONT_202])
      result$heating[CONT_202] <- as.character(df$heating[CONT_202])
      result$cooling[CONT_202] <- as.character(df$cooling[CONT_202])
    } else if (has_default) {
      result$mode[CONT_202]    <- as.character(defaults_df$mode[CONT_202])
      result$heating[CONT_202] <- as.character(defaults_df$heating[CONT_202])
      result$cooling[CONT_202] <- as.character(defaults_df$cooling[CONT_202])
      defaulted_rows <- c(defaulted_rows, CONT_202)
      messages <- c(messages, sprintf(
        "%s: row %d is missing or invalid. Using its default mode (heating=%s, cooling=%s).",
        filename, CONT_202, defaults_df$heating[CONT_202], defaults_df$cooling[CONT_202]
      ))
    } else {
      result$mode[CONT_202]    <- as.character(CONT_202)
      result$heating[CONT_202] <- as.character(gui_fallback$mode_heating_setpoint)
      result$cooling[CONT_202] <- as.character(gui_fallback$mode_cooling_setpoint)
      defaulted_rows <- c(defaulted_rows, CONT_202)
      messages <- c(messages, sprintf(
        "%s: row %d is invalid. Using a generic mode instead (heating=%s, cooling=%s).",
        filename, CONT_202, gui_fallback$mode_heating_setpoint, gui_fallback$mode_cooling_setpoint
      ))
    }
  }

  list(df = result, defaulted_rows = defaulted_rows, messages = messages)
}
