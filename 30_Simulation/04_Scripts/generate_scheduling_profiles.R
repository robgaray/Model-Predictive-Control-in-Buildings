# -------------------------------------------------------------
# Script: generate_scheduling_profiles.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Generates Main_df$Scheduling from Main_df$Occupancy and the
# anticipation parameters stored in parameters$reward.
# Sourced by Main.R and Main_SCC.R before simulation.
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

  Main_df$Scheduling <- 0L

  for (CONT_001 in sort(unique(row_dates))) {
    idx_day <- which(row_dates == CONT_001)
    idx_occ <- idx_day[Main_df$Occupancy[idx_day] == 1L]

    if (length(idx_occ) == 0) {
      next
    }

    interval_begin <- Main_df$time[min(idx_occ)] - anticipation_begin_sec
    interval_end   <- Main_df$time[max(idx_occ)] - anticipation_end_sec
    idx_sched <- which(Main_df$time >= interval_begin & Main_df$time <= interval_end)
    Main_df$Scheduling[idx_sched] <- 1L

    rm(idx_day, idx_occ, interval_begin, interval_end, idx_sched)
  }

  if (!is.integer(Main_df$Scheduling)) {
    stop("Main_df$Scheduling must be integer")
  }
  if (any(!Main_df$Scheduling %in% c(0L, 1L))) {
    stop("Main_df$Scheduling must contain only 0 or 1 values")
  }

  cleanup_vars <- c("anticipation_begin_sec", "anticipation_end_sec", "row_dates",
                    "CONT_001", "idx_day", "idx_occ", "interval_begin",
                    "interval_end", "idx_sched")
  rm(list = intersect(cleanup_vars, ls()))
  rm(cleanup_vars)

  cat("Main_df$Scheduling generated\n")
}
