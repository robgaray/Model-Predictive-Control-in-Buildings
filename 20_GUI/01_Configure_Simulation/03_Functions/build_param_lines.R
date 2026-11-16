# -------------------------------------------------------------
# Function: build_param_lines.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the lines of a block of parameters, or of a flat parameter,
# value,unit configuration file, from the values the user edited,
# changing nothing else. Given the lines of the existing file, it
# keeps its:
#   - header
#   - block headers
#   - order
#   - unit column
# and replaces only the value field of each parameter line.
# A parameter the lines do not hold is added at the end, with the
# unit the parameter catalogue declares.
# Given no lines (a file that does not exist yet), it builds them
# from the given header, followed by the parameters in the order of
# the catalogue. Each block of the catalogue gets its header, a
# comment line with the block title after a "#" line, and each
# parameter line carries the unit of the catalogue.
# It reads the units and blocks from validation_config, the
# catalogue the app reads each time its page is opened (with no
# rows when it could not be read, in which case the units of a new
# line are "-" and the new file has no blocks). It writes nothing:
# the writers of the files do.
# -------------------------------------------------------------
# Inputs
#   filename : Character. Path of the configuration file, relative to
#              config_path. Its base name is the one the catalogue
#              files its parameters under.
#   header   : Character vector. Comment lines to start the lines
#              with, used only when there are no lines to start from.
#   df       : Data frame (parameter, value). The values to write.
#   lines    : Character vector, or NULL. The lines of the existing
#              file, or its block, with no blank line and no table.
#              NULL when the file does not exist yet.
# -------------------------------------------------------------
# Outputs
#   Character vector. The lines of the file, or of its block.
# -------------------------------------------------------------
# Code outline
# 1. Take the units and the blocks of the catalogue.
# 2. Replace the value of every parameter line of the existing
#    lines, or start from the header when there are none.
# 3. Add the parameters the lines do not hold.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   build_param_lines(filename, header, df, lines)
# -------------------------------------------------------------

build_param_lines <- function(filename, header, df, lines) {

  values <- setNames(as.character(df$value), trimws(as.character(df$parameter)))

  # -------------------------------------------------------------
  # 1. Take the units and the blocks of the catalogue
  # -------------------------------------------------------------
  {
    rules  <- validation_config$rules
    rows   <- rules[rules$file == basename(filename), , drop = FALSE]
    units  <- setNames(rows$unit, rows$parameter)
    blocks <- setNames(rows$block, rows$parameter)
    unit_of <- function(name) if (is.na(units[name])) "-" else units[[name]]
    rm(rules, rows)
  }

  # -------------------------------------------------------------
  # 2. Replace the value of every parameter line of the existing
  # lines, or start from the header when there are none
  # -------------------------------------------------------------
  {
    new_file <- is.null(lines)
    if (new_file) {
      lines <- c(header, "parameter,value,unit")
    }
    written <- character(0)
    for (CONT_001 in seq_along(lines)) {
      line <- lines[CONT_001]
      if (grepl("^\\s*#", line) || !nzchar(trimws(line)) ||
          grepl("^\\s*parameter\\s*,", line)) {
        next
      }
      name <- trimws(sub(",.*$", "", line))
      if (name %in% names(values)) {
        rest <- sub("^[^,]*,[^,]*", "", line)
        lines[CONT_001] <- paste0(name, ",", values[[name]], rest)
        written <- c(written, name)
      }
    }
  }

  # -------------------------------------------------------------
  # 3. Add the parameters the lines do not hold
  # New lines get their blocks: a "#" line and the block title before
  # the first parameter of each block. The parameters the catalogue
  # lists come first, in its order.
  # -------------------------------------------------------------
  {
    pending <- setdiff(names(values), written)
    if (new_file) {
      pending <- c(intersect(names(units), pending),
                   setdiff(pending, names(units)))
    }
    current_block <- "-"
    for (name in pending) {
      block <- if (new_file && !is.na(blocks[name])) blocks[[name]] else "-"
      if (block != current_block && block != "-") {
        lines <- c(lines, "#", paste("#", block))
      }
      current_block <- block
      lines <- c(lines, paste(name, values[[name]], unit_of(name), sep = ","))
    }
    rm(values, units, blocks, unit_of, written, pending, current_block)
  }

  return(lines)
}
