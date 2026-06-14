# -------------------------------------------------------------
# Script: load_04_use_patterns.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads occupancy use patterns from 04_Use_Patterns.csv,
# validates both tables (TYPE and MONTH blocks), and stores them
# in parameters$use_patterns.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  raw_lines <- readLines(paths$use_patterns_file, warn = FALSE)
  raw_lines <- raw_lines[
    !grepl("^\\s*#", raw_lines) & nzchar(trimws(raw_lines))
  ]

  type_header_idx <- which(grepl("^\\s*TYPE\\s*,", raw_lines, ignore.case = TRUE))[1]
  month_header_idx <- which(grepl("^\\s*MONTH\\s*,", raw_lines, ignore.case = TRUE))[1]

  if (is.na(type_header_idx) || is.na(month_header_idx)) {
    stop("04_Use_Patterns.csv must contain TYPE and MONTH table headers")
  }
  if (month_header_idx <= type_header_idx) {
    stop("04_Use_Patterns.csv MONTH table must be located after TYPE table")
  }

  type_lines <- raw_lines[type_header_idx:(month_header_idx - 1)]
  month_lines <- raw_lines[month_header_idx:length(raw_lines)]
  rm(raw_lines, type_header_idx, month_header_idx)

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
  rm(type_lines, month_lines)

  if (nrow(use_type_df) > 0 &&
      tolower(trimws(as.character(use_type_df$TYPE[1]))) == "texto") {
    use_type_df <- use_type_df[-1, , drop = FALSE]
  }
  if (nrow(use_month_df) > 0 &&
      tolower(trimws(as.character(use_month_df$MONTH[1]))) == "texto") {
    use_month_df <- use_month_df[-1, , drop = FALSE]
  }

  required_type_cols <- c("TYPE", paste0("H", sprintf("%02d", 1:24)))
  required_month_cols <- c("MONTH", paste0("D", sprintf("%02d", 1:7)))

  missing_type_cols <- setdiff(required_type_cols, names(use_type_df))
  if (length(missing_type_cols) > 0) {
    stop("04_Use_Patterns.csv TYPE table missing columns: ",
         paste(missing_type_cols, collapse = ", "))
  }
  rm(missing_type_cols)

  missing_month_cols <- setdiff(required_month_cols, names(use_month_df))
  if (length(missing_month_cols) > 0) {
    stop("04_Use_Patterns.csv MONTH table missing columns: ",
         paste(missing_month_cols, collapse = ", "))
  }
  rm(missing_month_cols)

  if (nrow(use_type_df) == 0 || nrow(use_month_df) == 0) {
    stop("04_Use_Patterns.csv TYPE and MONTH tables must contain data rows")
  }

  use_type_df$TYPE <- trimws(as.character(use_type_df$TYPE))
  use_month_df$MONTH <- trimws(as.character(use_month_df$MONTH))
  for (CONT_001 in required_month_cols[-1]) {
    use_month_df[[CONT_001]] <- trimws(as.character(use_month_df[[CONT_001]]))
  }

  for (CONT_002 in required_type_cols[-1]) {
    use_type_df[[CONT_002]] <- as.numeric(use_type_df[[CONT_002]])
    if (any(is.na(use_type_df[[CONT_002]]))) {
      stop("04_Use_Patterns.csv TYPE table contains non numeric values in ", CONT_002)
    }
    if (any(use_type_df[[CONT_002]] %% 1 != 0)) {
      stop("04_Use_Patterns.csv TYPE table must contain integer values in ", CONT_002)
    }
    if (any(!use_type_df[[CONT_002]] %in% c(0, 1))) {
      stop("04_Use_Patterns.csv TYPE table must contain only 0/1 values in ", CONT_002)
    }
    use_type_df[[CONT_002]] <- as.integer(use_type_df[[CONT_002]])
  }

  required_month_keys <- paste0("MONTH", sprintf("%02d", 1:12))
  missing_month_keys <- setdiff(required_month_keys, use_month_df$MONTH)
  if (length(missing_month_keys) > 0) {
    stop("04_Use_Patterns.csv MONTH table missing rows: ",
         paste(missing_month_keys, collapse = ", "))
  }
  rm(required_month_keys, missing_month_keys)

  referenced_types <- unique(as.vector(as.matrix(use_month_df[, required_month_cols[-1], drop = FALSE])))
  missing_types <- setdiff(referenced_types, use_type_df$TYPE)
  if (length(missing_types) > 0) {
    stop("04_Use_Patterns.csv MONTH table references undefined TYPE values: ",
         paste(missing_types, collapse = ", "))
  }
  rm(referenced_types, missing_types)

  parameters$use_patterns <- list(
    day_types = use_type_df,
    month_profiles = use_month_df
  )

  rm(required_type_cols, required_month_cols, use_type_df, use_month_df,
     CONT_001, CONT_002)

  cat("Use patterns loaded\n")
}
