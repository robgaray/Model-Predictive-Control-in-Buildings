# -------------------------------------------------------------
# Function: load_occupancy_file_safe.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads 14_Use_Patterns.csv without ever stopping the app. An
# invalid hourly profile takes its default; a month that
# references a profile that does not exist takes its default
# mapping; a month missing from the file is added from the
# defaults, because every month of the year needs a mapping. The
# hourly profiles are the ones of the file: a profile of the
# defaults that the file does not hold is not added, because the
# user may define fewer profiles than the defaults. A message is
# collected for each case.
# A profile with no default takes occupancy_hour_value for every hour,
# from 02_Config/GUI_fallback_values.csv (gui_fallback, loaded by
# GUI_config.R); a month with no default maps every weekday to the
# first valid profile.
# -------------------------------------------------------------
# Inputs
#   filename         : Character. Path of the configuration file,
#                      relative to config_path.
#   default_filename : Character. Path of the Default_ file,
#                      relative to config_path.
# -------------------------------------------------------------
# Outputs
#   Named list with the elements:
#     - day_types
#     - month_profiles
#     - defaulted_type_rows
#     - defaulted_month_rows
#     - messages
# -------------------------------------------------------------
# Code outline
# 1. Read the file and its defaults.
# 2. When the file is unusable, return the defaults.
# 3. Resolve the hourly profiles.
# 4. Resolve the monthly mapping against those profiles.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   load_occupancy_file_safe(filename, default_filename)
# -------------------------------------------------------------

load_occupancy_file_safe <- function(filename, default_filename) {
  messages     <- character(0)
  hour_cols    <- paste0("H", sprintf("%02d", 1:24))
  weekday_cols <- paste0("D", sprintf("%02d", 1:7))

  default_dfs <- tryCatch(suppressWarnings(read_use_patterns_file(default_filename)), error = function(e) NULL)
  defaults_ok <- !is.null(default_dfs) && !is.null(default_dfs$day_types) &&
    !is.null(default_dfs$month_profiles) &&
    all(c("TYPE", hour_cols) %in% names(default_dfs$day_types)) &&
    all(c("MONTH", weekday_cols) %in% names(default_dfs$month_profiles))
  if (!defaults_ok) {
    messages <- c(messages, sprintf(
      "Default occupancy file '%s' could not be read; no defaults are available for '%s'.",
      default_filename, filename
    ))
  }

  dfs <- tryCatch(suppressWarnings(read_use_patterns_file(filename)), error = function(e) NULL)
  file_ok <- !is.null(dfs) && !is.null(dfs$day_types) && !is.null(dfs$month_profiles) &&
    all(c("TYPE", hour_cols) %in% names(dfs$day_types)) &&
    all(c("MONTH", weekday_cols) %in% names(dfs$month_profiles))

  if (!file_ok) {
    messages <- c(messages, sprintf(
      "Could not read '%s' (missing file or invalid format).%s",
      filename,
      if (defaults_ok) " Loading the default occupancy profiles instead." else ""
    ))
    if (defaults_ok) {
      return(list(
        day_types = default_dfs$day_types,
        month_profiles = default_dfs$month_profiles,
        defaulted_type_rows = seq_len(nrow(default_dfs$day_types)),
        defaulted_month_rows = seq_len(nrow(default_dfs$month_profiles)),
        messages = messages
      ))
    }
    return(list(
      day_types = data.frame(TYPE = character(0), stringsAsFactors = FALSE),
      month_profiles = data.frame(MONTH = character(0), stringsAsFactors = FALSE),
      defaulted_type_rows = integer(0),
      defaulted_month_rows = integer(0),
      messages = messages
    ))
  }

  if (!defaults_ok) {
    return(list(
      day_types = dfs$day_types,
      month_profiles = dfs$month_profiles,
      defaulted_type_rows = integer(0),
      defaulted_month_rows = integer(0),
      messages = messages
    ))
  }

  default_day_types      <- default_dfs$day_types
  default_month_profiles <- default_dfs$month_profiles

  # ---- TYPE table ----
  day_df <- dfs$day_types
  day_df$TYPE <- trimws(as.character(day_df$TYPE))

  type_rows       <- list()
  defaulted_types <- character(0)
  for (CONT_204 in seq_len(nrow(day_df))) {
    type_name <- day_df$TYPE[CONT_204]
    if (day_type_row_valid(day_df[CONT_204, hour_cols])) {
      type_rows[[type_name]] <- day_df[CONT_204, c("TYPE", hour_cols)]
    } else {
      default_match <- default_day_types[default_day_types$TYPE == type_name, ]
      if (nrow(default_match) == 1) {
        type_rows[[type_name]] <- default_match
      } else {
        type_rows[[type_name]] <- data.frame(
          TYPE = type_name,
          as.list(setNames(rep(as.character(gui_fallback$occupancy_hour_value), 24), hour_cols)),
          stringsAsFactors = FALSE
        )
      }
      defaulted_types <- c(defaulted_types, type_name)
      messages <- c(messages, sprintf(
        "%s: hourly profile '%s' is invalid (values other than 0/1). Using its default value.",
        filename, type_name
      ))
    }
  }
  day_types_result <- do.call(rbind, type_rows)
  rownames(day_types_result) <- NULL
  defaulted_type_rows <- which(day_types_result$TYPE %in% defaulted_types)

  # ---- MONTH table (validated against the just-resolved TYPE set) ----
  month_df <- dfs$month_profiles
  month_df$MONTH <- trimws(as.character(month_df$MONTH))
  valid_types <- day_types_result$TYPE

  month_rows       <- list()
  defaulted_months <- character(0)
  for (CONT_205 in seq_len(nrow(month_df))) {
    month_name <- month_df$MONTH[CONT_205]
    refs <- trimws(as.character(unlist(month_df[CONT_205, weekday_cols])))
    if (all(refs %in% valid_types)) {
      month_rows[[month_name]] <- month_df[CONT_205, c("MONTH", weekday_cols)]
    } else {
      default_match <- default_month_profiles[default_month_profiles$MONTH == month_name, ]
      if (nrow(default_match) == 1) {
        month_rows[[month_name]] <- default_match
      } else {
        month_rows[[month_name]] <- data.frame(
          MONTH = month_name,
          as.list(setNames(rep(valid_types[1], 7), weekday_cols)),
          stringsAsFactors = FALSE
        )
      }
      defaulted_months <- c(defaulted_months, month_name)
      messages <- c(messages, sprintf(
        "%s: monthly mapping '%s' references a nonexistent hourly profile. Using its default value.",
        filename, month_name
      ))
    }
  }
  missing_months <- setdiff(default_month_profiles$MONTH, names(month_rows))
  for (month_name in missing_months) {
    month_rows[[month_name]] <- default_month_profiles[default_month_profiles$MONTH == month_name, ]
    defaulted_months <- c(defaulted_months, month_name)
    messages <- c(messages, sprintf(
      "%s: month '%s' is missing. Adding it with its default value.",
      filename, month_name
    ))
  }
  month_profiles_result <- do.call(rbind, month_rows)
  rownames(month_profiles_result) <- NULL
  defaulted_month_rows <- which(month_profiles_result$MONTH %in% defaulted_months)

  list(
    day_types = day_types_result,
    month_profiles = month_profiles_result,
    defaulted_type_rows = defaulted_type_rows,
    defaulted_month_rows = defaulted_month_rows,
    messages = messages
  )
}
