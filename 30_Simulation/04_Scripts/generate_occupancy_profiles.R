# -------------------------------------------------------------
# Script: generate_occupancy_profiles.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Generates Main_df$Occupancy from parameters$use_patterns.
# Each timestamp is mapped to a MONTH row, weekday column and
# hourly TYPE value. Hour 00 is mapped to H24.
# Sourced by Main.R before simulation.
# -------------------------------------------------------------

{
  use_type_df  <- parameters$use_patterns$day_types
  use_month_df <- parameters$use_patterns$month_profiles

  if (is.null(use_type_df) || is.null(use_month_df)) {
    stop("parameters$use_patterns must contain day_types and month_profiles")
  }

  month_keys   <- paste0("MONTH", sprintf("%02d", as.integer(format(Main_df$time, "%m"))))
  month_row_idx <- match(month_keys, use_month_df$MONTH)
  if (any(is.na(month_row_idx))) {
    stop("Could not map one or more timestamps to MONTH profiles")
  }

  weekday_idx  <- ((as.POSIXlt(Main_df$time, tz = "UTC")$wday + 6) %% 7) + 1
  weekday_cols <- paste0("D", sprintf("%02d", weekday_idx))
  selected_types <- mapply(
    function(CONT_001, CONT_002) use_month_df[CONT_001, CONT_002],
    month_row_idx,
    weekday_cols,
    USE.NAMES = FALSE
  )

  type_row_idx <- match(selected_types, use_type_df$TYPE)
  if (any(is.na(type_row_idx))) {
    stop("Could not map one or more timestamps to TYPE profiles")
  }

  hour_values <- as.integer(format(Main_df$time, "%H"))
  hour_values[hour_values == 0L] <- 24L
  hour_cols <- paste0("H", sprintf("%02d", hour_values))

  occupancy_values <- as.numeric(
    mapply(
      function(CONT_003, CONT_004) use_type_df[CONT_003, CONT_004],
      type_row_idx,
      hour_cols,
      USE.NAMES = FALSE
    )
  )

  if (any(is.na(occupancy_values))) {
    stop("Generated Occupancy contains NA values")
  }
  if (any(occupancy_values %% 1 != 0)) {
    stop("Generated Occupancy must contain integer values only")
  }
  if (any(!occupancy_values %in% c(0, 1))) {
    stop("Generated Occupancy must contain only 0 or 1 values")
  }

  Main_df$Occupancy <- as.integer(occupancy_values)

  rm(use_type_df, use_month_df, month_keys, month_row_idx, weekday_idx,
     weekday_cols, selected_types, type_row_idx, hour_values, hour_cols,
     occupancy_values)

  cat("Main_df$Occupancy generated\n")
}
