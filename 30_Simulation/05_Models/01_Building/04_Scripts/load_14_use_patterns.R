# -------------------------------------------------------------
# Script: load_14_use_patterns.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads occupancy use patterns from 14_Use_Patterns.csv,
# validates both tables (TYPE and MONTH blocks), and stores them
# in parameters$use_patterns.
# Sourced from load_building_parameters(), which supplies the paths
# of the asset.
# -------------------------------------------------------------
# Inputs
#   paths$use_patterns_file : path of
#     14_Use_Patterns.csv, in the configuration
#     folder of the asset, as build_asset_paths() gives it.
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$use_patterns, populated. Nothing else is
#     modified.
#   load_building_parameters() gathers the group into the groups of
#   the building.
# -------------------------------------------------------------
# Code outline
# 1. Read the two tables, dropping the units row of each with
#    drop_unit_row().
# 2. Check the required columns are there.
# 3. Store the table in parameters$use_patterns.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by load_building_parameters(), which
#   supplies paths, the paths of the asset, and parameters, and
#   takes the updated parameters back.
# -------------------------------------------------------------

{
  raw_lines <- readLines(paths$use_patterns_file, warn = FALSE)
  raw_lines <- raw_lines[
    !grepl("^\\s*#", raw_lines) & nzchar(trimws(raw_lines))
  ]

  type_header_idx <- which(grepl("^\\s*TYPE\\s*,", raw_lines, ignore.case = TRUE))[1]
  month_header_idx <- which(grepl("^\\s*MONTH\\s*,", raw_lines, ignore.case = TRUE))[1]

  if (is.na(type_header_idx) || is.na(month_header_idx)) {
    stop("14_Use_Patterns.csv must contain TYPE and MONTH table headers")
  }
  if (month_header_idx <= type_header_idx) {
    stop("14_Use_Patterns.csv MONTH table must be located after TYPE table")
  }

  type_lines <- raw_lines[type_header_idx:(month_header_idx - 1)]
  month_lines <- raw_lines[month_header_idx:length(raw_lines)]
  rm(list = c("raw_lines", "type_header_idx", "month_header_idx"))

  use_type_df <- read.csv(
    text             = paste(type_lines, collapse = "\n"),
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )
  use_month_df <- read.csv(
    text             = paste(month_lines, collapse = "\n"),
    stringsAsFactors = FALSE,
    strip.white      = TRUE
  )
  rm(list = c("type_lines", "month_lines"))

  # drop_unit_row is called on each table to remove its units row, the
  # first row under its header. A TYPE data row holds numbers in its
  # hour columns; a MONTH data row names day types in its day columns.
  use_type_df <- drop_unit_row(
    table             = use_type_df,
    file_name         = paste0(basename(paths$use_patterns_file), " (TYPE table)"),
    number_columns    = intersect(sprintf("H%02d", 1:24), names(use_type_df)),
    reference_columns = character(0),
    reference_values  = character(0)
  )
  use_month_df <- drop_unit_row(
    table             = use_month_df,
    file_name         = paste0(basename(paths$use_patterns_file), " (MONTH table)"),
    number_columns    = character(0),
    reference_columns = intersect(sprintf("D%02d", 1:7), names(use_month_df)),
    reference_values  = use_type_df$TYPE
  )

  required_type_cols <- c("TYPE", paste0("H", sprintf("%02d", 1:24)))
  required_month_cols <- c("MONTH", paste0("D", sprintf("%02d", 1:7)))

  missing_type_cols <- setdiff(required_type_cols, names(use_type_df))
  if (length(missing_type_cols) > 0) {
    stop("14_Use_Patterns.csv TYPE table missing columns: ",
         paste(missing_type_cols, collapse = ", "))
  }
  rm(list = "missing_type_cols")

  missing_month_cols <- setdiff(required_month_cols, names(use_month_df))
  if (length(missing_month_cols) > 0) {
    stop("14_Use_Patterns.csv MONTH table missing columns: ",
         paste(missing_month_cols, collapse = ", "))
  }
  rm(list = "missing_month_cols")

  if (nrow(use_type_df) == 0 || nrow(use_month_df) == 0) {
    stop("14_Use_Patterns.csv TYPE and MONTH tables must contain data rows")
  }

  use_type_df$TYPE <- trimws(as.character(use_type_df$TYPE))
  use_month_df$MONTH <- trimws(as.character(use_month_df$MONTH))
  for (CONT_001 in required_month_cols[-1]) {
    use_month_df[[CONT_001]] <- trimws(as.character(use_month_df[[CONT_001]]))
  }

  for (CONT_002 in required_type_cols[-1]) {
    use_type_df[[CONT_002]] <- as.numeric(use_type_df[[CONT_002]])
    if (any(is.na(use_type_df[[CONT_002]]))) {
      stop("14_Use_Patterns.csv TYPE table contains non numeric values in ", CONT_002)
    }
    if (any(use_type_df[[CONT_002]] %% 1 != 0)) {
      stop("14_Use_Patterns.csv TYPE table must contain integer values in ", CONT_002)
    }
    if (any(!use_type_df[[CONT_002]] %in% c(0, 1))) {
      stop("14_Use_Patterns.csv TYPE table must contain only 0/1 values in ", CONT_002)
    }
    use_type_df[[CONT_002]] <- as.integer(use_type_df[[CONT_002]])
  }

  required_month_keys <- paste0("MONTH", sprintf("%02d", 1:12))
  missing_month_keys <- setdiff(required_month_keys, use_month_df$MONTH)
  if (length(missing_month_keys) > 0) {
    stop("14_Use_Patterns.csv MONTH table missing rows: ",
         paste(missing_month_keys, collapse = ", "))
  }
  rm(list = c("required_month_keys", "missing_month_keys"))

  referenced_types <- unique(as.vector(as.matrix(use_month_df[, required_month_cols[-1], drop = FALSE])))
  missing_types <- setdiff(referenced_types, use_type_df$TYPE)
  if (length(missing_types) > 0) {
    stop("14_Use_Patterns.csv MONTH table references undefined TYPE values: ",
         paste(missing_types, collapse = ", "))
  }
  rm(list = c("referenced_types", "missing_types"))

  parameters$use_patterns <- list(
    day_types = use_type_df,
    month_profiles = use_month_df
  )

  rm(list = c("required_type_cols", "required_month_cols", "use_type_df",
              "use_month_df", "CONT_001", "CONT_002"))
}
