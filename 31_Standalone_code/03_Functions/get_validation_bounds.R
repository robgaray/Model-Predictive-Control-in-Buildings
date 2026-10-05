# -------------------------------------------------------------
# Function: get_validation_bounds.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads the admissible bounds of one magnitude out of a validation
# configuration table, so that no numeric limit has to be written in
# the code that applies it.
# -------------------------------------------------------------
# Why the bounds are read instead of written
# A limit written in the code is invisible to whoever configures the
# simulation, and it is duplicated as soon as a second piece of code
# needs the same limit. Every limit therefore lives in a validation
# file under 02_Config/00_Validation/, and the code that
# enforces it asks for it here. A limit that is missing from the file
# is an error, not a silent absence of checking: the caller declares
# that it validates that magnitude, so the file must say how.
# -------------------------------------------------------------
# Inputs
#   validation_config : Data frame. Content of a validation file that
#                       follows Parameter_config.csv's convention,
#                       with the columns:
#                         - file_name
#                         - parameter_name
#                         - type
#                         - output
#                         - options
#   file_name         : Character. Value of the file_name column that
#                       identifies the parameter file or dataframe the
#                       magnitude belongs to (e.g. "11_Model_parameters.csv").
#   parameter_name    : Character. Name of the parameter or column
#                       whose bounds are requested.
# -------------------------------------------------------------
# Outputs
#   Named list with:
#     min    : Numeric. Lower bound, NA if the magnitude is unbounded
#              below.
#     max    : Numeric. Upper bound, NA if the magnitude is unbounded
#              above.
#     output : Character. "Error" or "Warning", the severity the
#              validation file assigns to this magnitude.
# -------------------------------------------------------------
# Code outline
# 1. Locate the single rule of this magnitude
# 2. Split the options field into its two bounds
# -------------------------------------------------------------
# Usage instructions
# bounds <- get_validation_bounds(bounding_validation_config, "11_Model_parameters.csv", "Volume")
# -------------------------------------------------------------
# Where this function/script is used
#   - validate_model_parameters()
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - An options field with an empty side ("-1," or ",60") means the
#     magnitude is unbounded on that side, and that side is returned
#     as NA. R's strsplit() drops a trailing empty field, so the split
#     result is padded before being read.
#   - A rule whose two sides are both empty is rejected: it would
#     declare a validation that checks nothing.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

get_validation_bounds <- function(validation_config, file_name, parameter_name) {

  # 1. Locate the single rule of this magnitude
  # -------------------------------------------------------------
  {
    rule <- validation_config[
      trimws(as.character(validation_config$file_name)) == file_name &
        trimws(as.character(validation_config$parameter_name)) == parameter_name,
    ]

    if (nrow(rule) != 1) {
      stop("get_validation_bounds(): '", parameter_name, "' of '", file_name,
           "' must have exactly one validation rule, found ", nrow(rule))
    }
  }

  # 2. Split the options field into its two bounds
  # -------------------------------------------------------------
  {
    options_str <- trimws(as.character(rule$options[1]))
    parts       <- strsplit(options_str, ",", fixed = TRUE)[[1]]

    if (length(parts) < 2) {
      parts <- c(parts, "")
    }

    bounds <- suppressWarnings(as.numeric(trimws(parts[1:2])))

    if (all(is.na(bounds))) {
      stop("get_validation_bounds(): '", parameter_name, "' of '", file_name,
           "' has no bound in its options field ('", options_str, "')")
    }

    result <- list(
      min    = bounds[1],
      max    = bounds[2],
      output = trimws(as.character(rule$output[1]))
    )
  }

  rm(rule, options_str, parts, bounds)

  return(result)
}
