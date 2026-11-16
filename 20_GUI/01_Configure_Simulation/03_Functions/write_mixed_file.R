# -------------------------------------------------------------
# Function: write_mixed_file.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Writes a configuration file that holds a block of parameters above
# a table (the modes file). The file is written as its block, one
# blank line that closes the block, and its table. Each part is built
# by the function that builds the same part of the other files, so
# no logic is repeated:
#   - build_param_lines() for the block, whose values are replaced in
#     place, and a parameter the file lacks is inserted at the end of
#     the block, before the blank line, never after the table
#   - build_table_lines() for the table, with its own comments, header,
#     units row and rows
# A file that does not exist yet gets its block from the catalogue and
# the comment lines and units row of the Default_ file for its table.
# A file that holds no block is given one, and keeps its table.
# It writes into config_path, the configuration folder GUI_config.R
# resolves at start.
# -------------------------------------------------------------
# Inputs
#   filename : Character. Path of the configuration file, relative to
#              config_path.
#   header   : Character vector. Comment lines to start the file with,
#              used only when the file has no block yet.
#   block_df : Data frame (parameter, value). The values of the block.
#   table_df : Data frame. The rows of the table, without its units
#              row.
# -------------------------------------------------------------
# Outputs
#   None; the file is written.
# -------------------------------------------------------------
# Code outline
# 1. Split the existing file into its block and its table.
# 2. Build the block and the table.
# 3. Join them with one blank line, and write the file.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   write_mixed_file(filename, header, block_df, table_df)
# -------------------------------------------------------------

write_mixed_file <- function(filename, header, block_df, table_df) {

  path <- file.path(config_path, filename)

  # -------------------------------------------------------------
  # 1. Split the existing file into its block and its table
  # The block part runs from the top of the file to the line before
  # the blank line that closes the block, and the table part starts
  # after it. A file with no block keeps all its lines for the table.
  # -------------------------------------------------------------
  {
    block_lines_in <- NULL
    table_lines_in <- NULL

    if (file.exists(path)) {
      source_lines <- readLines(path, warn = FALSE)

      # config_file_sections is called to find where the block and the
      # table of the file are.
      sections <- config_file_sections(source_lines)

      if (length(sections$block) > 0 && length(sections$table) > 0) {
        closing        <- which(!nzchar(trimws(source_lines)) &
                                  seq_along(source_lines) > max(sections$block))[1]
        block_lines_in <- source_lines[seq_len(closing - 1)]
        table_lines_in <- source_lines[seq_along(source_lines) > closing]
      } else if (length(sections$table) > 0) {
        table_lines_in <- source_lines
      }
      rm(source_lines, sections)
    }

    # A table that the file does not hold takes the comment lines and
    # the units row of its Default_ file.
    if (is.null(table_lines_in)) {
      default_path <- file.path(config_path, default_file_for(filename))
      if (file.exists(default_path)) {
        table_lines_in <- readLines(default_path, warn = FALSE)
      }
    }
  }

  # -------------------------------------------------------------
  # 2. Build the block and the table
  # -------------------------------------------------------------
  {
    # build_param_lines is called to replace the values of the block in
    # its lines, or to build the block from the header and the
    # catalogue when the file holds none.
    block_lines <- build_param_lines(
      filename = filename,
      header   = header,
      df       = block_df,
      lines    = block_lines_in
    )

    # build_table_lines is called to keep the comments and the units
    # row of the table and replace its rows.
    table_lines <- build_table_lines(
      filename = filename,
      header   = character(0),
      df       = table_df,
      lines    = table_lines_in
    )
  }

  # -------------------------------------------------------------
  # 3. Join them with one blank line, and write the file
  # -------------------------------------------------------------
  {
    writeLines(c(block_lines, "", table_lines), path)
    rm(block_lines_in, table_lines_in, block_lines, table_lines)
  }
}
