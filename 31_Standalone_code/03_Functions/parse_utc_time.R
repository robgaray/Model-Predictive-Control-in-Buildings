# -------------------------------------------------------------
# Function: parse_utc_time.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads one or more instants as UTC times. An instant may come as a
# POSIXct value, or as text in one of these forms:
#   - 2024-01-15T12:00:00Z (ISO 8601, as written by the JSON examples)
#   - 2024-01-15T12:00:00
#   - 2024-01-15 12:00:00
# Any value that cannot be read stops execution, naming the field.
# -------------------------------------------------------------
# Inputs
#   values     : POSIXct or character vector.
#   field_name : Character. Name of the field, for error messages.
# -------------------------------------------------------------
# Outputs
#   POSIXct vector, in UTC.
# -------------------------------------------------------------
# Code outline
# 1. Return POSIXct values as they are, in UTC
# 2. Read text values with each accepted format in turn
# -------------------------------------------------------------
# Usage instructions
# parse_utc_time("2024-01-15T12:00:00Z", "i0")
# -------------------------------------------------------------
# Where this function/script is used
#   - validate_inputs(): reads the four instants and the time vector
#     of every block.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

parse_utc_time <- function(values,
                           field_name
                           ) {

  # -------------------------------------------------------------
  # 1. Return POSIXct values as they are, in UTC
  # -------------------------------------------------------------
  {
    if (inherits(values, "POSIXct")) {
      return(as.POSIXct(as.numeric(values), origin = "1970-01-01", tz = "UTC"))
    }
  }

  # -------------------------------------------------------------
  # 2. Read text values with each accepted format in turn
  # -------------------------------------------------------------
  {
    text_values <- trimws(as.character(values))
    parsed      <- rep(as.POSIXct(NA, tz = "UTC"), length(text_values))
    formats     <- c("%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S")

    for (CONT_001 in formats) {
      pending <- is.na(parsed)
      if (!any(pending)) break
      parsed[pending] <- as.POSIXct(text_values[pending], format = CONT_001, tz = "UTC")
    }

    if (any(is.na(parsed))) {
      stop("Input '", field_name, "' contains a time that cannot be read: '",
           text_values[which(is.na(parsed))[1]],
           "'. Use ISO 8601 UTC, e.g. 2024-01-15T12:00:00Z")
    }

    rm(text_values, formats, CONT_001, pending)
  }

  return(parsed)
}
