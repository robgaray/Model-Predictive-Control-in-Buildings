# -------------------------------------------------------------
# Function: read_use_patterns_file.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads 14_Use_Patterns.csv, which holds two tables in one file:
# the hourly profiles (TYPE) and the monthly mapping of weekdays
# to profiles (MONTH). Each table's units row, the first row under
# its header, is dropped.
# It reads config_path, the configuration folder GUI_config.R
# resolves at start.
# -------------------------------------------------------------
# Inputs
#   filename         : Character. Path of the configuration file,
#                      relative to config_path.
# -------------------------------------------------------------
# Outputs
#   Named list: day_types and month_profiles, two data frames.
# -------------------------------------------------------------
# Code outline
# 1. Read the lines, dropping comments and blank lines.
# 2. Split them at the TYPE and MONTH headers and read each
#    table.
# 3. Drop the units row of each.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   read_use_patterns_file(filename)
# -------------------------------------------------------------

read_use_patterns_file <- function(filename) {
  full_path <- file.path(config_path, filename)
  raw_lines <- readLines(full_path, warn = FALSE)
  raw_lines <- raw_lines[
    !grepl("^\\s*#", raw_lines) & nzchar(trimws(raw_lines))
  ]

  type_header_idx <- which(grepl("^\\s*TYPE\\s*,",
                                 raw_lines,
                                 ignore.case = TRUE))[1]
  month_header_idx <- which(grepl("^\\s*MONTH\\s*,",
                                  raw_lines,
                                  ignore.case = TRUE))[1]

  if (is.na(type_header_idx) || is.na(month_header_idx)) {
    stop("14_Use_Patterns.csv must contain TYPE and MONTH table headers")
  }

  type_lines  <- raw_lines[type_header_idx:(month_header_idx - 1)]
  month_lines <- raw_lines[month_header_idx:length(raw_lines)]

  day_types <- read.csv(
    text             = paste(type_lines, collapse = "\n"),
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )
  month_profiles <- read.csv(
    text             = paste(month_lines, collapse = "\n"),
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )

  # The units row is the first row under each header. In the TYPE
  # table, is_units_row is called on its hour columns, which hold
  # numbers in a data row. In the MONTH table a data row names day
  # types, so the units row is the one that names something else.
  hour_cols <- intersect(sprintf("H%02d", 1:24), names(day_types))
  day_cols  <- intersect(sprintf("D%02d", 1:7), names(month_profiles))
  if (nrow(day_types) > 0 && length(hour_cols) > 0 &&
      is_units_row(day_types[1, hour_cols])) {
    day_types <- day_types[-1, , drop = FALSE]
  }
  if (nrow(month_profiles) > 0 && length(day_cols) > 0 &&
      !all(trimws(unlist(month_profiles[1, day_cols])) %in%
             trimws(day_types$TYPE))) {
    month_profiles <- month_profiles[-1, , drop = FALSE]
  }
  rm(hour_cols, day_cols)

  list(day_types = day_types, month_profiles = month_profiles)
}
