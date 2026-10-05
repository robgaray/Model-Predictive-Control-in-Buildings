# -------------------------------------------------------------
# Function: write_param_file.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Writes the values the user edited into a flat parameter,value,unit
# configuration file, changing nothing else. The file keeps its:
#   - header
#   - block headers
#   - order
#   - unit column
# Only the value field of each parameter line is replaced.
# A parameter the file does not hold is added at the end, with the
# unit its Default_ file declares. A missing file is created from
# the given header, with the units of its Default_ file.
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
# 1. Read the units of the Default_ file.
# 2. Replace the value of every parameter line of the existing file,
#    or build the file from the header when it does not exist.
# 3. Add the parameters the file does not hold, and write it.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   write_param_file(filename, header, df)
# -------------------------------------------------------------
# Where this function/script is used
# GUI_config.R
# -------------------------------------------------------------
# functions/scripts called
# default_file_for()
# -------------------------------------------------------------
write_param_file <- function(filename, header, df) {

  values <- setNames(as.character(df$value), trimws(as.character(df$parameter)))
  path   <- file.path(config_path, filename)

  # -------------------------------------------------------------
  # 1. Read the units of the Default_ file
  # -------------------------------------------------------------
  {
    units <- character(0)
    default_path <- file.path(config_path, default_file_for(filename))
    if (file.exists(default_path)) {
      default_df <- tryCatch(
        read.csv(default_path, comment.char = "#", stringsAsFactors = FALSE,
                 strip.white = TRUE, colClasses = "character"),
        error = function(e) NULL
      )
      if (!is.null(default_df) && all(c("parameter", "unit") %in% names(default_df))) {
        units <- setNames(default_df$unit, trimws(default_df$parameter))
      }
    }
    unit_of <- function(name) if (is.na(units[name])) "-" else units[[name]]
  }

  # -------------------------------------------------------------
  # 2. Replace the value of every parameter line of the existing file,
  # or build the file from the header when it does not exist
  # -------------------------------------------------------------
  {
    if (file.exists(path)) {
      lines <- readLines(path, warn = FALSE)
    } else {
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
  # 3. Add the parameters the file does not hold, and write it
  # -------------------------------------------------------------
  {
    for (name in setdiff(names(values), written)) {
      lines <- c(lines, paste(name, values[[name]], unit_of(name), sep = ","))
    }
    writeLines(lines, path)
  }
}
