# -------------------------------------------------------------
# Function: prepare_scheduling.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Generates the Scheduling of a building, in its table, from its
# Occupancy and the anticipation parameters of its operational
# temperature corrections.
# For each calendar day with at least one occupied row, computes
# one [interval_begin, interval_end] window and marks
# Scheduling = 1 over it:
#   - interval_begin is the time of the first occupied row minus
#     Service_Anticipation_Begin;
#   - interval_end is the time of the last occupied row minus
#     Service_Anticipation_End: the window ends before the occupancy
#     does.
# The calendar day of a row is the UTC date of the start of its time
# step, as for its occupancy (prepare_occupancy()): the row at 00:00
# closes the step from 23:55 to 24:00 with a step of 5 minutes, and
# belongs to the day before. The time step is the interval between
# the rows of the table, which shall be regular.
# Window boundaries are located in the sorted asset_df$time vector
# via findInterval() (O(log rows) per day) instead of a per-day full
# boolean scan of asset_df$time, which would be O(days x rows) and
# measurably slower over a full year at fine time resolution; only
# the resulting row ranges are then written to 1, so the total
# assignment cost stays O(rows) across all days combined instead of
# being repeated per day.
# -------------------------------------------------------------
# Inputs
#   asset_df                            : data frame, the table of the
#                                         building, with its time and
#                                         Occupancy columns, at least
#                                         two rows and a regular time
#                                         step.
#   operational_temperature_corrections : List. The anticipation
#     applied to the start and the end of each occupied stretch,
#     those of the building, in its entry of parameters$assets:
#     - Service_Anticipation_Begin [h]
#     - Service_Anticipation_End [h]
# -------------------------------------------------------------
# Outputs
#   asset_df, as received, with the column Scheduling added: one
#   integer flag (0 or 1) per row, marking the window the building
#   is prepared over.
# -------------------------------------------------------------
# Code outline
# 1. Check Occupancy, read the anticipation and find the day of
#    each row.
# 2. Find, for each calendar day, the first and last occupied row,
#    shift that pair by the anticipation parameters, and mark
#    Scheduling over the resulting window.
# 3. Check Scheduling.
# -------------------------------------------------------------
# Usage instructions
# asset_df <- prepare_scheduling(
#   asset_df                            = asset_df,
#   operational_temperature_corrections =
#     parameters$assets[[1]]$operational_temperature_corrections
# )
# -------------------------------------------------------------
prepare_scheduling <- function(asset_df,
                               operational_temperature_corrections
                               ) {

  # -------------------------------------------------------------
  # 1. Check Occupancy and find the day of each row
  # The anticipation is read, and the day of each row is the date of
  # the start of its time step.
  # -------------------------------------------------------------
  {
    if (!is.integer(asset_df$Occupancy)) {
      stop("asset_df$Occupancy must be integer before generating Scheduling")
    }
    if (any(!asset_df$Occupancy %in% c(0L, 1L))) {
      stop("asset_df$Occupancy must contain only 0 or 1 values")
    }

    anticipation_begin_sec <- as.numeric(
      operational_temperature_corrections$Service_Anticipation_Begin
    ) * 3600
    anticipation_end_sec   <- as.numeric(
      operational_temperature_corrections$Service_Anticipation_End
    ) * 3600
    times                  <- as.numeric(asset_df$time)
    step_sec               <- unique(diff(times))
    if (length(step_sec) != 1L || step_sec <= 0) {
      stop("prepare_scheduling: the time of the table of the building ",
           "shall have at least two rows and a regular time step")
    }
    row_dates              <- as.Date(asset_df$time - step_sec, tz = "UTC")

    asset_df$Scheduling <- 0L

    occ_idx <- which(asset_df$Occupancy == 1L)
  }

  # -------------------------------------------------------------
  # 2. Find the windows and mark Scheduling over them
  # Sub-blocks:
  #   2.1. First and last occupied row of each day, shifted by the
  #        anticipation
  #   2.2. Mark the rows of every window
  # Nothing is marked when no row is occupied.
  # -------------------------------------------------------------
  if (length(occ_idx) > 0) {

    # -------------------------------------------------------------
    # 2.1. Window of each day
    # -------------------------------------------------------------
    {
      occ_day  <- row_dates[occ_idx]
      occ_time <- asset_df$time[occ_idx]

      min_time_by_day <- tapply(occ_time, occ_day, min)
      max_time_by_day <- tapply(occ_time, occ_day, max)

      interval_begin <- min_time_by_day - anticipation_begin_sec
      interval_end   <- max_time_by_day - anticipation_end_sec
    }

    # -------------------------------------------------------------
    # 2.2. Mark the rows of every window
    # -------------------------------------------------------------
    {
      # eps is smaller than asset_df's time resolution, so that
      # findInterval(interval_begin - eps, times) locates the first
      # row with time >= interval_begin without an exact-match
      # ambiguity.
      eps       <- 1
      idx_begin <- findInterval(as.numeric(interval_begin) - eps, times) + 1L
      idx_end   <- findInterval(as.numeric(interval_end), times)

      all_idx <- unlist(Map(
        function(a, b) if (b >= a) seq.int(a, b) else integer(0),
        idx_begin, idx_end
      ))
      if (length(all_idx) > 0) {
        asset_df$Scheduling[unique(all_idx)] <- 1L
      }

      rm(list = c("occ_day", "occ_time", "min_time_by_day", "max_time_by_day",
                  "interval_begin", "interval_end", "eps", "idx_begin",
                  "idx_end", "all_idx"))
    }
  }

  # -------------------------------------------------------------
  # 3. Check Scheduling
  # -------------------------------------------------------------
  {
    if (!is.integer(asset_df$Scheduling)) {
      stop("asset_df$Scheduling must be integer")
    }
    if (any(!asset_df$Scheduling %in% c(0L, 1L))) {
      stop("asset_df$Scheduling must contain only 0 or 1 values")
    }

    rm(list = c("occ_idx", "anticipation_begin_sec", "anticipation_end_sec",
                "row_dates", "times", "step_sec"))
  }

  return(asset_df)
}
