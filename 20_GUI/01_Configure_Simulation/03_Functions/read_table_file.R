# -------------------------------------------------------------
# Function: read_table_file.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads a table configuration file (modes or markets), skipping
# comment lines and dropping the units row ("text" in the label
# column) that follows the header.
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
# 1. Read the CSV, skipping comment lines.
# 2. Drop the units row when present.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   read_table_file(filename)
# -------------------------------------------------------------
# Where this function/script is used
# load_market_table_file_safe(), load_modes_file_safe()
# -------------------------------------------------------------
# functions/scripts called
# None of this app; base R and shiny only.
# -------------------------------------------------------------

read_table_file <- function(filename) {
  df <- read.csv(
    file.path(config_path, filename),
    comment.char     = "#",
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )
  label_col <- intersect(c("Market", "mode"), names(df))[1]
  if (nrow(df) > 0 && !is.na(label_col)) {
    first_label_value <- tolower(trimws(as.character(df[[label_col]][1])))
    if (identical(first_label_value, "text")) {
      df <- df[-1, , drop = FALSE]
    }
  }
  df
}
