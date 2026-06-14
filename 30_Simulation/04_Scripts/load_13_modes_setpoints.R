# -------------------------------------------------------------
# Script: load_13_modes_setpoints.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads the setpoint-modes table from 13_Modes_setpoints.csv
# and stores it in parameters$setpoint_modes. Validates the
# required columns, non-NA values, integer mode codes, and
# consecutive mode numbering starting at 1.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  parameters$setpoint_modes <- read.csv(paths$setpoint_mode_file, comment.char = "#")

  req_cols     <- c("mode", "heating", "cooling")
  missing_cols <- req_cols[!req_cols %in% names(parameters$setpoint_modes)]
  if (length(missing_cols) > 0) {
    stop("13_Modes_setpoints.csv is missing required columns: ",
         paste(missing_cols, collapse = ", "))
  }

  if (nrow(parameters$setpoint_modes) == 0) {
    stop("13_Modes_setpoints.csv does not contain any mode definitions")
  }

  if (any(is.na(parameters$setpoint_modes$mode))) {
    stop("13_Modes_setpoints.csv contains NA values in column 'mode'")
  }
  if (any(is.na(parameters$setpoint_modes$heating))) {
    stop("13_Modes_setpoints.csv contains NA values in column 'heating'")
  }
  if (any(is.na(parameters$setpoint_modes$cooling))) {
    stop("13_Modes_setpoints.csv contains NA values in column 'cooling'")
  }

  mode_values <- parameters$setpoint_modes$mode
  if (any(mode_values != as.integer(mode_values))) {
    stop("13_Modes_setpoints.csv column 'mode' must contain integer values")
  }
  if (anyDuplicated(mode_values) > 0) {
    stop("13_Modes_setpoints.csv column 'mode' contains duplicated values")
  }
  expected_modes <- seq_len(nrow(parameters$setpoint_modes))
  if (!identical(as.integer(sort(mode_values)), expected_modes)) {
    stop(
      "13_Modes_setpoints.csv column 'mode' must contain consecutive integers starting at 1. ",
      "Expected: ", paste(expected_modes, collapse = ", "),
      ". Found: ", paste(sort(mode_values), collapse = ", ")
    )
  }

  rm(req_cols, missing_cols, mode_values, expected_modes)

  cat("Setpoint modes loaded\n")
}
