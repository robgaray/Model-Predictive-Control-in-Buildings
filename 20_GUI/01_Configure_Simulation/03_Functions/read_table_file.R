# -------------------------------------------------------------
# Function: read_table_file.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads a table configuration file (modes or markets), skipping
# comment lines and dropping the units row that follows the header.
# When the file starts with a block of parameters (the modes file),
# only the table below the block is read.
# The units row is the first row under the header, by position, and
# is recognized by holding a unit, not a number, in a column that
# holds numbers (is_units_row()). A file written without it keeps
# that row as data, and the units row is written back when the file
# is saved.
# It reads config_path, the configuration folder GUI_config.R
# resolves at start.
# -------------------------------------------------------------
# Inputs
#   filename         : Character. Path of the configuration file,
#                      relative to config_path.
# -------------------------------------------------------------
# Outputs
#   Data frame of the table, without its units row.
# -------------------------------------------------------------
# Code outline
# 1. Read the table of the file, skipping comment lines.
# 2. Drop the first row under the header when it is the units row.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   read_table_file(filename)
# -------------------------------------------------------------

read_table_file <- function(filename) {
  lines <- readLines(file.path(config_path, filename), warn = FALSE)

  # config_file_sections is called to find the lines of the table: all
  # of them when the file has no block, those below the block when it
  # has one.
  sections <- config_file_sections(lines)
  df <- read.csv(
    text             = paste(lines[sections$table], collapse = "\n"),
    comment.char     = "#",
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )
  rm(lines, sections)
  numeric_cols <- intersect(c("heating", "cooling", "closure", "begin",
                               "end", "end_optimization"), names(df))
  # is_units_row is called on the first row under the header, in the
  # columns that hold numbers, to tell the units row from data.
  if (nrow(df) > 0 && length(numeric_cols) > 0 &&
      is_units_row(df[1, numeric_cols])) {
    df <- df[-1, , drop = FALSE]
  }
  df
}
