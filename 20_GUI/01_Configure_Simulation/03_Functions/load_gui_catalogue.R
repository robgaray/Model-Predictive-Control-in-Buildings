# -------------------------------------------------------------
# Function: load_gui_catalogue.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads, without ever stopping the app, everything the GUI takes
# from the parameter catalogue and from the tolerances of the
# validation:
#   - the rules of every parameter: its file, its block, its type,
#     its range or options, what a breach does, its unit and its
#     default value
#   - the integer tolerance
# The same catalogue feeds the labels and units, the groups of each
# tab, the dropdowns, the checks of a value and the default values.
# When the catalogue cannot be read, the rules are an empty table
# and a message says what the app can then not do. When the
# tolerance cannot be read, or is not valid, it is NA and a message
# says that an Integer must then be exactly a whole number.
# -------------------------------------------------------------
# Inputs
#   catalogue_filename: Character. Path of the parameter catalogue,
#                       relative to config_path.
#   tolerances_filename: Character. Path of the file of the
#                       tolerances of the validation, relative to
#                       config_path.
# -------------------------------------------------------------
# Outputs
#   Named list, the validation configuration of the app:
#     - rules             : data frame with the text columns file,
#                           parameter, block, type, min, max,
#                           options, output, unit and default,
#                           without the units row of the catalogue;
#                           it has no rows when the catalogue could
#                           not be read
#     - integer_tolerance : numeric, the largest distance to a
#                           whole number an Integer may have, or NA
#     - messages          : character vector, one message per
#                           problem found while reading
# -------------------------------------------------------------
# Code outline
# 1. Read the catalogue and drop its units row
# 2. Read the integer tolerance
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   load_gui_catalogue(
#     catalogue_filename,
#     tolerances_filename)
# -------------------------------------------------------------

load_gui_catalogue <- function(catalogue_filename, tolerances_filename) {

  messages <- character(0)

  # 1. Read the catalogue and drop its units row
  # -------------------------------------------------------------
  {
    needed <- c("file", "parameter", "block", "type", "min", "max",
                "options", "output", "unit", "default")

    rules <- tryCatch(
      suppressWarnings(read.csv(
        file.path(config_path, catalogue_filename),
        comment.char     = "#",
        stringsAsFactors = FALSE,
        strip.white      = TRUE,
        colClasses       = "character"
      )),
      error = function(e) NULL
    )

    if (is.null(rules) || !all(needed %in% names(rules)) ||
        nrow(rules) == 0) {
      messages <- c(messages, sprintf(
        paste("Could not read '%s'. Values are only checked for not being",
              "empty, no units or dropdowns are shown, nothing can be",
              "replaced by its default, and new files are written with no",
              "units."),
        catalogue_filename
      ))
      rules <- as.data.frame(
        setNames(rep(list(character(0)), length(needed)), needed),
        stringsAsFactors = FALSE
      )
    } else {
      rules <- rules[!(rules$file == "text" & rules$parameter == "text"),
                     needed, drop = FALSE]
      rules[is.na(rules)] <- ""
      rownames(rules) <- NULL
    }

    rm(needed)
  }

  # 2. Read the integer tolerance
  # The value is checked against its own rule of the catalogue.
  # -------------------------------------------------------------
  {
    integer_tolerance <- NA_real_

    tolerances <- tryCatch(
      suppressWarnings(read.csv(
        file.path(config_path, tolerances_filename),
        comment.char     = "#",
        stringsAsFactors = FALSE,
        strip.white      = TRUE,
        colClasses       = "character"
      )),
      error = function(e) NULL
    )

    tolerance_value <- NULL
    if (!is.null(tolerances) &&
        all(c("parameter", "value") %in% names(tolerances))) {
      tolerance_value <- tolerances$value[
        trimws(tolerances$parameter) == "integer_tolerance"
      ]
    }

    if (length(tolerance_value) == 1) {
      # check_param_valid is called to check the tolerance against its
      # own rule of the catalogue, before it is used to check anything.
      tolerance_ok <- check_param_valid(
        value             = tolerance_value,
        file_name         = basename(tolerances_filename),
        param_name        = "integer_tolerance",
        validation_config = list(rules = rules, integer_tolerance = NA_real_)
      )
      if (tolerance_ok) {
        integer_tolerance <- as.numeric(tolerance_value)
      }
      rm(tolerance_ok)
    }

    if (is.na(integer_tolerance)) {
      messages <- c(messages, sprintf(
        paste("Could not read a valid 'integer_tolerance' from '%s'. An",
              "Integer value must then be exactly a whole number."),
        tolerances_filename
      ))
    }

    rm(tolerances, tolerance_value)
  }

  return(list(
    rules             = rules,
    integer_tolerance = integer_tolerance,
    messages          = messages
  ))
}
