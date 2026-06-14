# -------------------------------------------------------------
# Script: climate_priority.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Generates Main_df$Overall_Climate on a daily basis from
# trailing averages of Main_df$Text and parameters$reward.
# Sourced by Main.R and Main_SCC.R before simulation.
# -------------------------------------------------------------

{
  unique_dates <- sort(unique(as.Date(Main_df$time, tz = "UTC")))
  climate_tags <- character(length(unique_dates))

  for (CONT_001 in seq_along(unique_dates)) {
    day_start <- as.POSIXct(unique_dates[CONT_001], tz = "UTC")

    heating_idx <- Main_df$time >= (day_start - parameters$reward$HDD_period * 86400) &
      Main_df$time < day_start
    cooling_idx <- Main_df$time >= (day_start - parameters$reward$CDD_period * 86400) &
      Main_df$time < day_start

    t_ave_heating <- if (any(heating_idx)) {
      mean(Main_df$Text[heating_idx], na.rm = TRUE)
    } else {
      NA_real_
    }
    t_ave_cooling <- if (any(cooling_idx)) {
      mean(Main_df$Text[cooling_idx], na.rm = TRUE)
    } else {
      NA_real_
    }

    if (!is.na(t_ave_heating) &&
        (t_ave_heating - parameters$reward$HDD_base) < 0) {
      climate_tags[CONT_001] <- "Heating"
    } else if (!is.na(t_ave_cooling) &&
               (t_ave_cooling - parameters$reward$CDD_base) > 0) {
      climate_tags[CONT_001] <- "Cooling"
    } else {
      climate_tags[CONT_001] <- "Intermediate"
    }

    rm(day_start, heating_idx, cooling_idx, t_ave_heating, t_ave_cooling)
  }

  Main_df$Overall_Climate <- climate_tags[
    match(as.Date(Main_df$time, tz = "UTC"), unique_dates)
  ]

  cleanup_vars <- c("unique_dates", "climate_tags", "CONT_001", "day_start",
                    "heating_idx", "cooling_idx", "t_ave_heating", "t_ave_cooling")
  rm(list = intersect(cleanup_vars, ls()))
  rm(cleanup_vars)

  cat("Main_df$Overall_Climate generated\n")
}
