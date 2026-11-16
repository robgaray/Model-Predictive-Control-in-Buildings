# -------------------------------------------------------------
# Function: prepare_occupancy.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Generates the Occupancy of a building, in its table, from its use
# patterns.
# A row holds the state of the building at its instant and the
# energy of the time step that ends at that instant, so its
# occupancy is the one of that time step: it is read at the start of
# the step, one step before the instant of the row, as the prices
# and the flexibility events are.
# The start of each step is mapped to a MONTH row, a weekday column
# and an hourly TYPE value, in UTC. The column Hnn of a day type is
# the hour that ends at nn:00 of its date: H01 is the hour from
# 00:00 to 01:00 and H24 the hour from 23:00 to 24:00. With a step
# of 5 minutes, the row at 07:00 (the step from 06:55 to 07:00)
# reads H07, and the row at 07:05 reads H08.
# The time step is the interval between the rows of the table, which
# shall be regular.
# The result is needed before the scheduling profile and the
# reference temperature profiles can be computed.
# -------------------------------------------------------------
# Inputs
#   asset_df     : data frame, the table of the building, with its
#                  time column, at least two rows and a regular time
#                  step.
#   use_patterns : List, the use_patterns of the building (its entry
#                  of parameters$assets). The occupancy table, by
#                  month, weekday and hour:
#                  - day_types: one row per TYPE, one column per hour
#                  - month_profiles: one row per MONTH, one column per
#                    weekday
# -------------------------------------------------------------
# Outputs
#   asset_df, as received, with the column Occupancy added: one
#   integer value (0 or 1) per row.
# -------------------------------------------------------------
# Code outline
# 1. Map the start of the step of each row to its month row,
#    weekday column and hour.
# 2. Read the occupancy of that cell.
# 3. Check the occupancy and write it into asset_df.
# -------------------------------------------------------------
# Usage instructions
# asset_df <- prepare_occupancy(
#   asset_df     = asset_df,
#   use_patterns = parameters$assets[[1]]$use_patterns
# )
# -------------------------------------------------------------
prepare_occupancy <- function(asset_df,
                              use_patterns
                              ) {

  # -------------------------------------------------------------
  # 1. Map the start of the step of each row
  # The time step is read from the time column, which shall be
  # regular. The start of the step of each row gives its month row,
  # its weekday column and its hour.
  # -------------------------------------------------------------
  {
    use_type_df  <- use_patterns$day_types
    use_month_df <- use_patterns$month_profiles

    if (is.null(use_type_df) || is.null(use_month_df)) {
      stop("use_patterns must contain day_types and month_profiles")
    }

    step_sec <- unique(diff(as.numeric(asset_df$time)))
    if (length(step_sec) != 1L || step_sec <= 0) {
      stop("prepare_occupancy: the time of the table of the building ",
           "shall have at least two rows and a regular time step")
    }
    step_start <- as.POSIXlt(asset_df$time - step_sec, tz = "UTC")

    month_keys    <- paste0("MONTH", sprintf("%02d", step_start$mon + 1L))
    month_row_idx <- match(month_keys, use_month_df$MONTH)
    if (any(is.na(month_row_idx))) {
      stop("Could not map one or more timestamps to MONTH profiles")
    }

    weekday_idx  <- ((step_start$wday + 6) %% 7) + 1
    weekday_cols <- paste0("D", sprintf("%02d", weekday_idx))
  }

  # -------------------------------------------------------------
  # 2. Read the occupancy of that cell
  # The MONTH block gives the day type of the start of each step and
  # the TYPE block the value of its hour.
  # -------------------------------------------------------------
  {
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

    # The step that starts in hour hh (00 to 23) belongs to the
    # column of the hour that ends at hh + 1.
    hour_cols <- paste0("H", sprintf("%02d", step_start$hour + 1L))

    occupancy_values <- as.numeric(
      mapply(
        function(CONT_003, CONT_004) use_type_df[CONT_003, CONT_004],
        type_row_idx,
        hour_cols,
        USE.NAMES = FALSE
      )
    )

    rm(list = c("use_type_df", "use_month_df", "step_sec", "step_start",
                "month_keys", "month_row_idx", "weekday_idx", "weekday_cols",
                "selected_types", "type_row_idx", "hour_cols"))
  }

  # -------------------------------------------------------------
  # 3. Check the occupancy and write it into asset_df
  # -------------------------------------------------------------
  {
    if (any(is.na(occupancy_values))) {
      stop("Generated Occupancy contains NA values")
    }
    if (any(occupancy_values %% 1 != 0)) {
      stop("Generated Occupancy must contain integer values only")
    }
    if (any(!occupancy_values %in% c(0, 1))) {
      stop("Generated Occupancy must contain only 0 or 1 values")
    }

    asset_df$Occupancy <- as.integer(occupancy_values)

    rm(list = "occupancy_values")
  }

  return(asset_df)
}
