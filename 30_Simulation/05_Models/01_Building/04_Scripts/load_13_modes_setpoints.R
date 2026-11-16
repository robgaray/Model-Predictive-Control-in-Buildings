# -------------------------------------------------------------
# Script: load_13_modes_setpoints.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the setpoint-modes table from 13_Modes_setpoints.csv
# and stores it in parameters$setpoint_modes. The table is the whole
# file, or the part of it that follows a block of parameters above
# it, which another reader loads. Drops the units row,
# the first row under the header, with drop_unit_row(), which stops
# when that row holds data. Validates:
#   - the required columns
#   - the absence of NA values
#   - integer mode codes
#   - consecutive mode numbering starting at 1
# Sourced from load_building_parameters(), which supplies the paths
# of the asset.
# -------------------------------------------------------------
# Inputs
#   paths$setpoint_mode_file : path of
#     13_Modes_setpoints.csv, in the configuration
#     folder of the asset, as build_asset_paths() gives it.
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$setpoint_modes, populated. Nothing else is
#     modified.
#   load_building_parameters() gathers the group into the groups of
#   the building.
# -------------------------------------------------------------
# Code outline
# 1. Read the table of the file, dropping the unit placeholder row.
# 2. Check the columns, the absence of NA, and that the mode
#    codes are consecutive integers from one.
# 3. Store the table in parameters$setpoint_modes.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by load_building_parameters(), which
#   supplies paths, the paths of the asset, and parameters, and
#   takes the updated parameters back.
# -------------------------------------------------------------

{
  # split_config_sections is called to find the lines of the table,
  # which is the whole file when the file holds no block of
  # parameters above it.
  mode_lines <- readLines(paths$setpoint_mode_file)
  sections   <- split_config_sections(mode_lines)

  parameters$setpoint_modes <- read.csv(
    text         = paste(mode_lines[sections$table], collapse = "\n"),
    comment.char = "#"
  )
  rm(list = c("mode_lines", "sections"))

  req_cols     <- c("mode", "heating", "cooling")
  missing_cols <- req_cols[!req_cols %in% names(parameters$setpoint_modes)]
  if (length(missing_cols) > 0) {
    stop("13_Modes_setpoints.csv is missing required columns: ",
         paste(missing_cols, collapse = ", "))
  }

  # drop_unit_row is called to remove the units row, the first row
  # under the header, after checking it is not a mode.
  parameters$setpoint_modes <- drop_unit_row(
    table             = parameters$setpoint_modes,
    file_name         = basename(paths$setpoint_mode_file),
    number_columns    = c("heating", "cooling"),
    reference_columns = character(0),
    reference_values  = character(0)
  )

  if (nrow(parameters$setpoint_modes) == 0) {
    stop("13_Modes_setpoints.csv does not contain any mode definitions")
  }

  # The units row makes read.csv() type mode/heating/cooling as
  # character (mixed with non-numeric text); coerce back to
  # numeric now that the row is gone, so downstream setpoint arithmetic
  # (e.g. convert_modes_to_setpoints()) does not fail on character data.
  for (CONT_001 in req_cols) {
    parameters$setpoint_modes[[CONT_001]] <- suppressWarnings(as.numeric(parameters$setpoint_modes[[CONT_001]]))
  }
  rm(list = "CONT_001")

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

  rm(list = c("req_cols", "missing_cols", "mode_values", "expected_modes"))
}
