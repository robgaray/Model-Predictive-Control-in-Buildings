# -------------------------------------------------------------
# Function: build_table_lines.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the lines of a table configuration file (modes or markets),
# or of the table of a file that holds a block of parameters above
# it, from the rows the user edited. The lines keep their own comment
# header and their units row (the "text,..." line under the column
# names); the rows below them are replaced.
# When there are no lines to start from, the given header and the
# units row of the Default_ file of the table are used. When no units
# row is found in either (a table whose columns hold no numbers, such
# as the asset registry, has none the function can recognize), the
# units are taken from the parameter catalogue, one per column.
# It reads config_path, the configuration folder GUI_config.R
# resolves at start. It writes nothing: the writers of the files do.
# -------------------------------------------------------------
# Inputs
#   filename : Character. Path of the configuration file, relative to
#              config_path.
#   header   : Character vector. Comment lines to start the lines
#              with, used only when there are no lines to start from.
#   df       : Data frame. The rows to write, without the units row.
#   lines    : Character vector, or NULL. The lines of the existing
#              file, or of its table: its comment header, its column
#              names, its units row and its rows. NULL when the file
#              does not exist yet.
# -------------------------------------------------------------
# Outputs
#   Character vector. The lines of the table: the comment header, the
#   column names, the units row and the rows.
# -------------------------------------------------------------
# Code outline
# 1. Take the comment header and the units row from the lines, or
#    from the header given and the Default_ file, or from the
#    catalogue.
# 2. Build the header, the column names, the units row and the rows.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   build_table_lines(filename, header, df, lines)
# -------------------------------------------------------------

build_table_lines <- function(filename, header, df, lines) {

  # -------------------------------------------------------------
  # 1. Take the comment header and the units row from the lines, or
  # from the header given and the Default_ file, or from the catalogue
  # -------------------------------------------------------------
  {
    # The units row is the first row under the header. is_units_row is
    # called on it, in the columns that hold numbers, to make sure it
    # is not a data row of a file written without its units row.
    units_row_of <- function(lines) {
      data_lines <- lines[!grepl("^\\s*#", lines) & nzchar(trimws(lines))]
      if (length(data_lines) < 2) {
        return(NULL)
      }
      header_fields <- trimws(strsplit(data_lines[1], ",")[[1]])
      row_fields    <- trimws(strsplit(data_lines[2], ",")[[1]])
      numeric_cols  <- which(header_fields %in% c("heating", "cooling", "closure",
                                                  "begin", "end", "end_optimization"))
      if (length(numeric_cols) > 0 && is_units_row(row_fields[numeric_cols])) {
        return(data_lines[2])
      }
      return(NULL)
    }

    source_lines <- if (is.null(lines)) character(0) else lines
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
    if (is.null(units_row)) {
      # get_param_unit is called for each column to take its unit from
      # the catalogue; a dimensionless column takes "-".
      column_units <- vapply(
        names(df),
        function(column) {
          unit <- get_param_unit(basename(filename), column)
          if (nzchar(unit)) unit else "-"
        },
        character(1)
      )
      units_row <- paste(column_units, collapse = ",")
      rm(column_units)
    }
  }

  # -------------------------------------------------------------
  # 2. Build the header, the column names, the units row and the rows
  # -------------------------------------------------------------
  {
    row_lines <- capture.output(
      write.table(df, sep = ",", row.names = FALSE, col.names = FALSE,
                  quote = FALSE)
    )
    table_lines <- c(top_comments, paste(names(df), collapse = ","),
                     units_row, row_lines)
    rm(units_row_of, source_lines, top_comments, units_row, row_lines)
  }

  return(table_lines)
}
