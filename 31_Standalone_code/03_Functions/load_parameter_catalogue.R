# -------------------------------------------------------------
# Function: load_parameter_catalogue.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads the parameter catalogue, Parameter_catalogue.csv, which holds
# one row per parameter of the configuration files and per column of
# their tables: its file, its type, its range or options, what a
# breach of the rule does, its unit, its description and its default
# value. The rules every configuration file is validated against are
# its rows. It also reads the tolerances of that validation, from
# Validation_tolerances.csv, and checks them against their own rows.
# The catalogue is checked before it is used: a rule that cannot be
# applied would let a wrong value through, or stop a right one.
# -------------------------------------------------------------
# Inputs
#   catalogue_path  : Character. Path of Parameter_catalogue.csv.
#   tolerances_path : Character. Path of Validation_tolerances.csv.
# -------------------------------------------------------------
# Outputs
#   Named list, the validation configuration every loader receives:
#     - rules             : data frame, the catalogue without its units
#                           row, every column as text, with the
#                           columns:
#                             - file, parameter, group, block
#                             - type, min, max, options, output
#                             - unit, description, default
#     - integer_tolerance : numeric, the largest distance to a whole
#                           number a value of an Integer parameter may
#                           have.
# -------------------------------------------------------------
# Code outline
# 1. Read the catalogue and drop its units row
# 2. Check its rules
# 3. Read the tolerances
# -------------------------------------------------------------
# Usage instructions
# validation_config <- load_parameter_catalogue(
#   paths$parameter_catalogue_file,
#   paths$tolerances_validation_file
# )
# -------------------------------------------------------------

load_parameter_catalogue <- function(catalogue_path, tolerances_path) {

  # 1. Read the catalogue and drop its units row
  # -------------------------------------------------------------
  {
    rules <- read.csv(
      catalogue_path,
      comment.char     = "#",
      stringsAsFactors = FALSE,
      strip.white      = TRUE,
      colClasses       = "character"
    )

    required_columns <- c("file", "parameter", "group", "block", "type",
                          "min", "max", "options", "output", "unit",
                          "description", "default")
    missing_columns  <- setdiff(required_columns, names(rules))
    if (length(missing_columns) > 0) {
      stop(basename(catalogue_path), " is missing the columns: ",
           paste(missing_columns, collapse = ", "))
    }

    # drop_unit_row is called to remove the units row, after checking
    # that its type is not one a rule can have.
    rules <- drop_unit_row(
      table             = rules,
      file_name         = basename(catalogue_path),
      number_columns    = character(0),
      reference_columns = "type",
      reference_values  = c("Integer", "Real", "Options", "Text")
    )
    rules[is.na(rules)] <- ""
    rownames(rules)     <- NULL

    rm(list = c("required_columns", "missing_columns"))
  }

  # 2. Check its rules
  # Every rule names its file and its parameter, once; has one of the
  # four types and one of the two outputs; a range whose ends are
  # numbers, the low end first; and, for an Options rule, its options.
  # -------------------------------------------------------------
  {
    problems <- character(0)

    keys <- paste(rules$file, rules$parameter, sep = ",")
    if (any(!nzchar(rules$file) | !nzchar(rules$parameter))) {
      problems <- c(problems, "a rule without its file or its parameter")
    }
    if (anyDuplicated(keys) > 0) {
      problems <- c(problems, paste0("rules repeated: ",
                                     paste(unique(keys[duplicated(keys)]),
                                           collapse = "; ")))
    }

    bad_type <- !rules$type %in% c("Integer", "Real", "Options", "Text")
    if (any(bad_type)) {
      problems <- c(problems, paste0("unknown type in: ",
                                     paste(keys[bad_type], collapse = "; ")))
    }

    bad_output <- !rules$output %in% c("Error", "Warning")
    if (any(bad_output)) {
      problems <- c(problems, paste0("unknown output in: ",
                                     paste(keys[bad_output], collapse = "; ")))
    }

    low  <- suppressWarnings(as.numeric(rules$min))
    high <- suppressWarnings(as.numeric(rules$max))
    bad_range <- (nzchar(rules$min) & is.na(low)) |
      (nzchar(rules$max) & is.na(high)) |
      (!is.na(low) & !is.na(high) & low > high)
    if (any(bad_range)) {
      problems <- c(problems, paste0("a range that is not two numbers in ",
                                     "order in: ",
                                     paste(keys[bad_range], collapse = "; ")))
    }

    no_options <- rules$type == "Options" & !nzchar(rules$options)
    if (any(no_options)) {
      problems <- c(problems, paste0("an Options rule without options in: ",
                                     paste(keys[no_options], collapse = "; ")))
    }

    if (length(problems) > 0) {
      stop(basename(catalogue_path), " cannot be used:\n  - ",
           paste(problems, collapse = "\n  - "))
    }

    rm(list = c("problems", "keys", "bad_type", "bad_output", "low", "high",
                "bad_range", "no_options"))
  }

  # 3. Read the tolerances
  # The tolerances are checked against their own rows of the catalogue.
  # They are Real, so their check needs no integer tolerance yet.
  # -------------------------------------------------------------
  {
    validation_config <- list(
      rules             = rules,
      integer_tolerance = NA_real_
    )

    # read_and_validate_parameter_csv is called to read the tolerances
    # and check them against their rows of the catalogue.
    tolerances <- read_and_validate_parameter_csv(
      tolerances_path,
      basename(tolerances_path),
      validation_config
    )
    validation_config$integer_tolerance <- as.numeric(tolerances$integer_tolerance)

    rm(list = c("rules", "tolerances"))
  }

  return(validation_config)
}
