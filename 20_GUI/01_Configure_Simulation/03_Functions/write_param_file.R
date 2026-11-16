# -------------------------------------------------------------
# Function: write_param_file.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Writes the values the user edited into a flat parameter,value,unit
# configuration file, changing nothing else. The lines are built by
# build_param_lines(): the file keeps its header, block headers,
# order and unit column, only the value field of each parameter line
# is replaced, a parameter the file does not hold is added at the end
# with the unit of the catalogue, and a missing file is created from
# the given header, with the blocks of the catalogue.
# It writes into config_path, the configuration folder GUI_config.R
# resolves at start.
# -------------------------------------------------------------
# Inputs
#   filename : Character. Path of the configuration file, relative to
#              config_path.
#   header   : Character vector. Comment lines to start the file with,
#              used only when the file does not exist yet.
#   df       : Data frame (parameter, value). The values to write.
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
#   write_param_file(filename, header, df)
# -------------------------------------------------------------

write_param_file <- function(filename, header, df) {

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
    # build_param_lines is called to replace the values in the lines of
    # the file, or to build them from the header and the catalogue when
    # the file does not exist yet.
    new_lines <- build_param_lines(
      filename = filename,
      header   = header,
      df       = df,
      lines    = source_lines
    )
    writeLines(new_lines, path)
    rm(source_lines, new_lines)
  }
}
