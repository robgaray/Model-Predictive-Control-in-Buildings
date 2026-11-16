# -------------------------------------------------------------
# Function: read_param_block.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads the block of parameters of a configuration file that holds a
# table below it (the modes file): the lines from the header
# parameter,value,unit to the first blank line, with comment lines
# skipped. A file with no block gives a data frame with no rows, so
# that the safe loader takes the defaults of the block and says so.
# It adds no error handling and no defaults: the safe loader that
# calls it adds both.
# It reads config_path, the configuration folder GUI_config.R
# resolves at start.
# -------------------------------------------------------------
# Inputs
#   filename         : Character. Path of the configuration file,
#                      relative to config_path.
# -------------------------------------------------------------
# Outputs
#   Data frame with the columns parameter, value and unit, one row
#   per parameter of the block.
# -------------------------------------------------------------
# Code outline
# 1. Read the lines of the file and find those of its block.
# 2. Read them as a parameter,value,unit table.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   read_param_block(filename)
# -------------------------------------------------------------

read_param_block <- function(filename) {

  # 1. Read the lines of the file and find those of its block
  # -------------------------------------------------------------
  {
    lines <- readLines(file.path(config_path, filename), warn = FALSE)

    # config_file_sections is called to find the lines of the block of
    # parameters, which are none when the file does not start with it.
    sections <- config_file_sections(lines)
    block_lines <- if (length(sections$block) > 0) {
      lines[sections$block]
    } else {
      "parameter,value,unit"
    }
  }

  # 2. Read them as a parameter,value,unit table
  # -------------------------------------------------------------
  {
    df <- read.csv(
      text             = paste(block_lines, collapse = "\n"),
      comment.char     = "#",
      stringsAsFactors = FALSE,
      strip.white      = TRUE
    )
    rm(lines, sections, block_lines)
  }

  return(df)
}
