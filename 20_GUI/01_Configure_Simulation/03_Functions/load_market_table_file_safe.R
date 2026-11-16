# -------------------------------------------------------------
# Function: load_market_table_file_safe.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads a market table (scheduling or piloting) without ever
# stopping the app. An invalid row takes the defaults of its
# market; a market with no default takes a generic configuration
# with the aim given by the caller. The markets are the ones of
# the file: a market of the defaults that the file does not hold
# is not added, because the user may run fewer markets than the
# defaults. A message is collected for each replaced row.
# The generic row is read from 02_Config/GUI_fallback_values.csv
# (gui_fallback, loaded by GUI_config.R).
# -------------------------------------------------------------
# Inputs
#   filename         : Character. Path of the configuration file,
#                      relative to config_path.
#   default_filename : Character. Path of the Default_ file,
#                      relative to config_path.
#   fallback_aim     : Character. Aim of the generic row used for
#                      a market with no default.
# -------------------------------------------------------------
# Outputs
#   Named list with the elements:
#     - df, with the columns:
#         - Market
#         - closure
#         - begin
#         - end
#         - end_optimization
#         - aim
#     - defaulted_rows
#     - messages
# -------------------------------------------------------------
# Code outline
# 1. Read the file and its defaults.
# 2. When the file is unusable, return the defaults.
# 3. Take each market from the file when valid, from the defaults
#    otherwise.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   load_market_table_file_safe(
#     filename,
#     default_filename,
#     fallback_aim)
# -------------------------------------------------------------

load_market_table_file_safe <- function(filename, default_filename, fallback_aim) {
  messages <- character(0)
  req_cols <- c("Market", "closure", "begin", "end", "end_optimization", "aim")
  df <- tryCatch(suppressWarnings(read_table_file(filename)), error = function(e) NULL)

  defaults_df <- tryCatch(suppressWarnings(read_table_file(default_filename)), error = function(e) NULL)
  defaults_ok <- !is.null(defaults_df) && all(req_cols %in% names(defaults_df)) &&
    nrow(defaults_df) > 0
  if (!defaults_ok) {
    messages <- c(messages, sprintf(
      "Default markets file '%s' could not be read; no defaults are available for '%s'.",
      default_filename, filename
    ))
  }

  file_ok <- !is.null(df) && all(req_cols %in% names(df)) && nrow(df) > 0
  if (!file_ok) {
    messages <- c(messages, sprintf(
      "Could not read '%s' (missing, empty file, or invalid columns).%s",
      filename,
      if (defaults_ok) " Loading the default markets instead." else ""
    ))
    if (defaults_ok) {
      return(list(df = defaults_df, defaulted_rows = seq_len(nrow(defaults_df)),
                  messages = messages))
    }
    return(list(
      df = data.frame(Market = character(0), closure = character(0),
                      begin = character(0), end = character(0),
                      end_optimization = character(0), aim = character(0),
                      stringsAsFactors = FALSE),
      defaulted_rows = integer(0), messages = messages
    ))
  }

  if (!defaults_ok) {
    return(list(df = df, defaulted_rows = integer(0), messages = messages))
  }

  df$Market <- trimws(as.character(df$Market))

  result_rows        <- list()
  defaulted_markets   <- character(0)

  for (CONT_203 in seq_len(nrow(df))) {
    market_name <- df$Market[CONT_203]
    # market_table_row_valid is called to check the row against the
    # catalogue rules of this table, found by the file name.
    row_ok <- market_table_row_valid(
      closure          = df$closure[CONT_203],
      begin            = df$begin[CONT_203],
      end              = df$end[CONT_203],
      end_optimization = df$end_optimization[CONT_203],
      aim              = df$aim[CONT_203],
      file_label       = basename(filename)
    )
    if (row_ok) {
      result_rows[[market_name]] <- df[CONT_203, req_cols]
    } else {
      default_match <- defaults_df[defaults_df$Market == market_name, ]
      if (nrow(default_match) == 1) {
        result_rows[[market_name]] <- default_match
        messages <- c(messages, sprintf(
          "%s: the row for market '%s' is invalid. Using its default value.",
          filename, market_name
        ))
      } else {
        result_rows[[market_name]] <- data.frame(
          Market           = market_name,
          closure          = gui_fallback$market_closure,
          begin            = gui_fallback$market_begin,
          end              = gui_fallback$market_end,
          end_optimization = gui_fallback$market_end_optimization,
          aim              = fallback_aim,
          stringsAsFactors = FALSE
        )
        messages <- c(messages, sprintf(
          "%s: the row for market '%s' is invalid and has no known default. Using a generic configuration instead.",
          filename, market_name
        ))
      }
      defaulted_markets <- c(defaulted_markets, market_name)
    }
  }

  result_df <- do.call(rbind, result_rows)
  rownames(result_df) <- NULL
  defaulted_rows <- which(result_df$Market %in% defaulted_markets)

  list(df = result_df, defaulted_rows = defaulted_rows, messages = messages)
}
