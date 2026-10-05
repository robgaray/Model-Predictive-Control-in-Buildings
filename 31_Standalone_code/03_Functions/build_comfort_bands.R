# -------------------------------------------------------------
# Function: build_comfort_bands.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Adds to the working table the comfort bands the reward compares the
# indoor temperature with. It follows the same two steps as the full
# simulation:
#   1. Scheduling: for each calendar day with occupied rows, the rows
#      from the first occupied one, brought forward by
#      Service_Anticipation_Begin, to the last occupied one, moved by
#      Service_Anticipation_End, are marked as Scheduling = 1.
#   2. Bands: the service band (Service_T_*) applies where the building
#      is occupied and the setback band (Setback_T_*) elsewhere. The
#      scheduling band (Scheduling_T_*) is the service band where
#      Scheduling is 1, narrowed by the seasonal corrections of the
#      climate season, and the service band elsewhere. The plan band
#      kept in Scheduling_T_* is the more restrictive of this band and
#      the occupancy band (Service_T_*). The call stops if it is empty
#      on any row.
# The climate season is a single value for the whole call.
# Only the days covered by the working table are seen, so a day cut
# by i0 or i_end_horizon is scheduled from its visible rows.
# -------------------------------------------------------------
# Inputs
#   period_chunk    : Data frame. Working table with time and
#                     Occupancy.
#   parameters      : Named list. Uses:
#                     - reward$Service_T_Low/High
#                     - reward$Setback_T_Low/High
#                     - operational_temperature_corrections$
#                       Service_Anticipation_Begin/End
#                     - operational_temperature_corrections$
#                       Service_AT_Low_Sched_HDD and
#                       Service_AT_High_Sched_CDD
#   Overall_Climate : Character. "Heating", "Cooling" or
#                     "Intermediate".
# -------------------------------------------------------------
# Outputs
#   period_chunk with the columns:
#     - Scheduling
#     - Service_T_Low, Service_T_High
#     - Scheduling_T_Low, Scheduling_T_High
# -------------------------------------------------------------
# Code outline
# 1. Scheduling profile
# 2. Service and scheduling bands
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- build_comfort_bands(period_chunk, parameters, "Heating")
# -------------------------------------------------------------
# Where this function/script is used
#   - optimize_market(): after the working table is built.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

build_comfort_bands <- function(period_chunk,
                                parameters,
                                Overall_Climate
                                ) {

  # -------------------------------------------------------------
  # 1. Scheduling profile
  # -------------------------------------------------------------
  {
    corrections            <- parameters$operational_temperature_corrections
    anticipation_begin_sec <- corrections$Service_Anticipation_Begin * 3600
    anticipation_end_sec   <- corrections$Service_Anticipation_End * 3600
    times                  <- as.numeric(period_chunk$time)

    period_chunk$Scheduling <- 0L
    occupied_rows <- which(period_chunk$Occupancy == 1L)

    if (length(occupied_rows) > 0) {
      occupied_day  <- as.Date(period_chunk$time[occupied_rows], tz = "UTC")
      occupied_time <- times[occupied_rows]

      interval_begin <- tapply(occupied_time, occupied_day, min) - anticipation_begin_sec
      interval_end   <- tapply(occupied_time, occupied_day, max) - anticipation_end_sec

      # findInterval() places each window edge on the sorted time grid;
      # the offset of one second keeps a begin edge that falls exactly
      # on a row inside the window.
      row_begin <- findInterval(interval_begin - 1, times) + 1L
      row_end   <- findInterval(interval_end, times)

      scheduled_rows <- unlist(Map(
        function(a, b) if (b >= a) seq.int(a, b) else integer(0),
        row_begin, row_end
      ))
      period_chunk$Scheduling[unique(scheduled_rows)] <- 1L

      rm(occupied_day, occupied_time, interval_begin, interval_end,
         row_begin, row_end, scheduled_rows)
    }

    rm(anticipation_begin_sec, anticipation_end_sec, times, occupied_rows)
  }

  # -------------------------------------------------------------
  # 2. Service and scheduling bands
  # -------------------------------------------------------------
  {
    occupied     <- period_chunk$Occupancy == 1L
    scheduled    <- period_chunk$Scheduling == 1L
    heating_like <- Overall_Climate %in% c("Heating", "Intermediate")
    cooling_like <- Overall_Climate %in% c("Cooling", "Intermediate")

    period_chunk$Service_T_Low  <- ifelse(occupied,
                                          parameters$reward$Service_T_Low,
                                          parameters$reward$Setback_T_Low)
    period_chunk$Service_T_High <- ifelse(occupied,
                                          parameters$reward$Service_T_High,
                                          parameters$reward$Setback_T_High)

    scheduling_low <- ifelse(
      scheduled,
      parameters$reward$Service_T_Low +
        if (heating_like) corrections$Service_AT_Low_Sched_HDD else 0,
      period_chunk$Service_T_Low
    )
    scheduling_high <- ifelse(
      scheduled,
      parameters$reward$Service_T_High -
        if (cooling_like) corrections$Service_AT_High_Sched_CDD else 0,
      period_chunk$Service_T_High
    )

    # The band the plan is measured against is the more restrictive of
    # the scheduling band and the occupancy band. The scheduling
    # corrections may be negative, which would make the scheduling band
    # wider than the occupancy band; the intersection keeps the
    # occupancy band as a floor in that case.
    period_chunk$Scheduling_T_Low  <- pmax(period_chunk$Service_T_Low,  scheduling_low)
    period_chunk$Scheduling_T_High <- pmin(period_chunk$Service_T_High, scheduling_high)

    empty_band <- period_chunk$Scheduling_T_Low >= period_chunk$Scheduling_T_High
    if (any(empty_band)) {
      stop("The comfort band is empty (Scheduling_T_Low >= Scheduling_T_High) on ",
           sum(empty_band), " rows. Check Service_T_Low/High and Setback_T_Low/High",
           " in 09_Reward_parameters.csv and Service_AT_Low_Sched_HDD/",
           "Service_AT_High_Sched_CDD in 10_Operational_temperature_corrections.csv")
    }

    rm(occupied, scheduled, heating_like, cooling_like, corrections,
       scheduling_low, scheduling_high, empty_band)
  }

  return(period_chunk)
}
