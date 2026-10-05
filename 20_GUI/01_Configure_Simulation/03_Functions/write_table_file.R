# -------------------------------------------------------------
# Function: write_table_file.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Writes a table configuration file (modes or markets) from the rows
# the user edited. The file keeps its own comment header and its
# units row (the "text,..." line under the column names); the rows
# below them are replaced.
# When the file does not exist, the given header and the units row of
# its Default_ file are used.
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
# 1. Take the comment header and the units row from the existing
#    file, or from the header given and the Default_ file.
# 2. Write the header, the column names, the units row and the rows.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   write_table_file(filename, header, df)
# -------------------------------------------------------------
# Where this function/script is used
# GUI_config.R
# -------------------------------------------------------------
# functions/scripts called
# default_file_for()
# -------------------------------------------------------------
write_table_file <- function(filename, header, df) {

  path <- file.path(config_path, filename)

  # -------------------------------------------------------------
  # 1. Take the comment header and the units row from the existing
  # file, or from the header given and the Default_ file
  # -------------------------------------------------------------
  {
    units_row_of <- function(lines) {
      data_lines <- lines[!grepl("^\\s*#", lines) & nzchar(trimws(lines))]
      if (length(data_lines) >= 2 && grepl("^\\s*text\\s*,", data_lines[2], ignore.case = TRUE)) {
        return(data_lines[2])
      }
      return(NULL)
    }

    source_lines <- if (file.exists(path)) readLines(path, warn = FALSE) else character(0)
    top_comments <- if (length(source_lines) > 0) {
      first_data <- which(!grepl("^\\s*#", source_lines) & nzchar(trimws(source_lines)))[1]
      if (is.na(first_data)) source_lines else source_lines[seq_len(first_data - 1)]
    } else {
      header
    }
    units_row <- units_row_of(source_lines)
    if (is.null(units_row)) {
      default_path <- file.path(config_path, default_file_for(filename))
      if (file.exists(default_path)) {
        units_row <- units_row_of(readLines(default_path, warn = FALSE))
      }
    }
  }

  # -------------------------------------------------------------
  # 2. Write the header, the column names, the units row and the rows
  # -------------------------------------------------------------
  {
    con <- file(path, open = "wt")
    on.exit(close(con), add = TRUE)
    writeLines(top_comments, con)
    writeLines(paste(names(df), collapse = ","), con)
    if (!is.null(units_row)) {
      writeLines(units_row, con)
    }
    write.table(df, con, sep = ",", row.names = FALSE, col.names = FALSE, quote = FALSE)
  }
}
