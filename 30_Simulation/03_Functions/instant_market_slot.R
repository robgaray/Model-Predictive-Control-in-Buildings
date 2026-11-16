# -------------------------------------------------------------
# Function: instant_market_slot.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Returns the market interval in which an instant falls: the
# instant rounded down to the market resolution.
# -------------------------------------------------------------
# Instants and time steps
# A row of Main_df holds the state of the building at its instant
# and the energy of the time step that ends at that instant. The
# energy of a row therefore belongs to the market interval of its
# time step, which is what the column MarketUTC holds (see
# prepare_market_calendar()). For the last row of an interval,
# that is the interval that ends at the row's instant.
# A market clearing is an event at an instant, not a time step.
# It is keyed by the interval that its instant falls in, which is
# the first interval whose energy is still ahead of the clearing.
# This function gives that key, so that every place that locates
# a market event (the price matrices, the commitment matrices,
# the economic analysis, the revenue discount) uses the same one.
# -------------------------------------------------------------
# Inputs
#   time              : POSIXct vector. The instants.
#   market_resolution : Numeric scalar (min). Length of a market
#                       interval, parameters$market$market_resolution.
# -------------------------------------------------------------
# Outputs
#   POSIXct vector (UTC), the same length as time: the start of the
#   market interval in which each instant falls.
# -------------------------------------------------------------
# Code outline
# 1. Check the inputs
# 2. Round each instant down to the market resolution
# -------------------------------------------------------------
# Usage instructions
# event_slot <- instant_market_slot(Main_df$time[row_index],
#                                   parameters$market$market_resolution)
# -------------------------------------------------------------
instant_market_slot <- function(time,
                                market_resolution
                                ) {

  # -------------------------------------------------------------
  # 1. Check the inputs
  # -------------------------------------------------------------
  {
    if (!inherits(time, "POSIXct")) {
      stop("instant_market_slot: time must be a POSIXct vector.")
    }
    if (!is.numeric(market_resolution) || length(market_resolution) != 1 ||
        is.na(market_resolution) || market_resolution <= 0) {
      stop("instant_market_slot: market_resolution must be a positive ",
           "number of minutes.")
    }
  }

  # -------------------------------------------------------------
  # 2. Round each instant down to the market resolution
  # -------------------------------------------------------------
  {
    slot_sec   <- market_resolution * 60
    event_slot <- as.POSIXct(floor(as.numeric(time) / slot_sec) * slot_sec,
                             origin = "1970-01-01",
                             tz     = "UTC")
    rm(list = "slot_sec")
  }

  return(event_slot)
}
