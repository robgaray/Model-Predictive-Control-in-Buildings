# -------------------------------------------------------------
# Function: write_table_file.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Writes a table configuration file (modes or markets) from the rows
# the user edited. The lines are built by build_table_lines(): the
# file keeps its own comment header and its units row (the
# "text,..." line under the column names); the rows below them are
# replaced. When the file does not exist, the given header and the
# units row of its Default_ file are used.
# It writes into config_path, the configuration folder GUI_config.R
# resolves at start.
# -------------------------------------------------------------
# Inputs
#   filename : Character. Path of the configuration file, relative to
#              config_path.
#   header   : Character vector. Comment lines to start the file with,
#              used only when the file does not exist yet.
#   df       : Data frame. The rows to write, without the units row.
# -------------------------------------------------------------
# Outputs
#   None; the file is written.
# -------------------------------------------------------------
# Code outline
# 1. Read the lines of the existing file, when there is one.
# 2. Build the new lines and write them.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   write_table_file(filename, header, df)
# -------------------------------------------------------------

write_table_file <- function(filename, header, df) {

  path <- file.path(config_path, filename)

  # -------------------------------------------------------------
  # 1. Read the lines of the existing file, when there is one
  # -------------------------------------------------------------
  {
    source_lines <- if (file.exists(path)) readLines(path, warn = FALSE) else NULL
  }

  # -------------------------------------------------------------
  # 2. Build the new lines and write them
  # -------------------------------------------------------------
  {
    # build_table_lines is called to keep the comment header and the
    # units row of the file and replace its rows.
    new_lines <- build_table_lines(
      filename = filename,
      header   = header,
      df       = df,
      lines    = source_lines
    )
    writeLines(new_lines, path)
    rm(source_lines, new_lines)
  }
}
