# -------------------------------------------------------------
# Script: generate_scheduling_profiles.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Generates Main_df$Scheduling from Main_df$Occupancy and the
# anticipation parameters stored in parameters$reward.
# Sourced by Main.R before simulation.
# For each calendar day with at least one occupied row, computes
# one [interval_begin, interval_end] window (first/last occupied
# row's time, shifted by the anticipation parameters) and marks
# Scheduling = 1 over it. Window boundaries are located in the
# sorted Main_df$time vector via findInterval() (O(log rows) per
# day) instead of a per-day full boolean scan of Main_df$time
# (previously O(days x rows), measurably slower over a full year
# at fine time resolution); only the resulting row ranges are then
# written to 1, so the total assignment cost stays O(rows) across
# all days combined instead of being repeated per day. Verified
# against the previous per-day boolean-scan implementation over
# randomized occupancy patterns, including negative/reversed
# anticipation windows, sparse/zero/full occupancy, and windows
# spanning into neighboring days.
# -------------------------------------------------------------

{
  if (!is.integer(Main_df$Occupancy)) {
    stop("Main_df$Occupancy must be integer before generating Scheduling")
  }
  if (any(!Main_df$Occupancy %in% c(0L, 1L))) {
    stop("Main_df$Occupancy must contain only 0 or 1 values")
  }

  anticipation_begin_sec <- as.numeric(parameters$reward$Service_Anticipation_Begin) * 3600
  anticipation_end_sec   <- as.numeric(parameters$reward$Service_Anticipation_End) * 3600
  row_dates              <- as.Date(Main_df$time, tz = "UTC")
  times                  <- as.numeric(Main_df$time)

  Main_df$Scheduling <- 0L

  occ_idx <- which(Main_df$Occupancy == 1L)

  if (length(occ_idx) > 0) {
    occ_day  <- row_dates[occ_idx]
    occ_time <- Main_df$time[occ_idx]

    min_time_by_day <- tapply(occ_time, occ_day, min)
    max_time_by_day <- tapply(occ_time, occ_day, max)

    interval_begin <- min_time_by_day - anticipation_begin_sec
    interval_end   <- max_time_by_day - anticipation_end_sec

    # eps is smaller than Main_df's time resolution, so that
    # findInterval(interval_begin - eps, times) locates the first row
    # with time >= interval_begin without an exact-match ambiguity.
    eps       <- 1
    idx_begin <- findInterval(as.numeric(interval_begin) - eps, times) + 1L
    idx_end   <- findInterval(as.numeric(interval_end), times)

    all_idx <- unlist(Map(
      function(a, b) if (b >= a) seq.int(a, b) else integer(0),
      idx_begin, idx_end
    ))
    if (length(all_idx) > 0) {
      Main_df$Scheduling[unique(all_idx)] <- 1L
    }

    rm(occ_day, occ_time, min_time_by_day, max_time_by_day, interval_begin,
       interval_end, eps, idx_begin, idx_end, all_idx)
  }

  rm(occ_idx)

  if (!is.integer(Main_df$Scheduling)) {
    stop("Main_df$Scheduling must be integer")
  }
  if (any(!Main_df$Scheduling %in% c(0L, 1L))) {
    stop("Main_df$Scheduling must contain only 0 or 1 values")
  }

  rm(anticipation_begin_sec, anticipation_end_sec, row_dates, times)

  cat("Main_df$Scheduling generated\n")
}
