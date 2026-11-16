# -------------------------------------------------------------
# Function: comfort_term.R
# Part of the Model Predictive Control in buildings repository
# <https://github.com/robgaray/Model-Predictive-Control-in-Buildings>
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Computes the comfort part of the reward, row by row, over the
# three itineraries of a candidate: the plan and the two
# flexibility legs. It is the asset side of the reward: it reads
# the comfort flags the building simulation wrote, and nothing of
# the energy, the prices or the commitments.
# A row is penalized when ANY of the three itineraries is out of
# its own comfort band at that row. Committing to a service that
# leaves the building outside comfort in the itinerary that would
# actually be flown is not an acceptable commitment, whichever of
# the two legs it belongs to. Where nothing is committed, and
# outside the flexibility windows, both flex comfort columns are
# the copy of Comfort_plan that derive_flex_itineraries() made,
# so the "or" adds no false penalty there.
# Every time step counts, occupied or not: each itinerary carries
# its own band (the plan band, or the occupancy band inside a
# flexibility window), and outside occupancy and the scheduling
# window that band is the setback band.
# The penalty is the length of the row in hours, with a negative
# sign, times alpha_comfort (1/h), so the term is dimensionless,
# like alpha_cost (1/EUR) times each economic term (EUR).
# alpha_comfort is a parameter of the building, in its comfort
# group: each building weighs its own comfort, and the reward adds
# the comfort terms of all of them.
# Comfort is never discounted: prudence is about what the
# building expects to earn, not about whether people are
# comfortable.
# -------------------------------------------------------------
# Inputs
#   period_chunk  : Data frame. Planning-period data with the
#                   columns:
#                     - time: POSIXct. Simulation timestamps.
#                     - Comfort_plan: Numeric (0/1).
#                     - Comfort_plan_flex_down: Numeric (0/1).
#                     - Comfort_plan_flex_up: Numeric (0/1).
#   asset         : Named list. The parameters of the building, its
#                   entry of parameters$assets. Every operation of the
#                   type of model receives them (model_type_contract()).
#                   The comfort of a building reads the weight of its
#                   comfort term, asset$comfort$alpha_comfort (1/h).
#                   The comfort flags are already in period_chunk.
# -------------------------------------------------------------
# Outputs
#   Numeric vector, one value per row of period_chunk: the
#   weighted comfort term of the row (dimensionless, 0 in
#   comfort, negative out of it).
# -------------------------------------------------------------
# Code outline
# 0. The weight of the comfort term of the building
# 1. Time step of each row
# 2. Hours out of comfort, weighted
# -------------------------------------------------------------
# Usage instructions
# comfort <- comfort_term(period_chunk, parameters$assets[[1]])
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If asset$comfort$alpha_comfort is NULL, stop() is called
#     immediately (no default value is used).
# -------------------------------------------------------------
comfort_term <- function(period_chunk,
                         asset
                         ) {

  # -------------------------------------------------------------
  # 0. The weight of the comfort term of the building
  # -------------------------------------------------------------
  {
    alpha_comfort <- asset$comfort$alpha_comfort
    if (is.null(alpha_comfort)) {
      stop("alpha_comfort was not found in the comfort group of ",
           asset$asset_id)
    }
  }

  # -------------------------------------------------------------
  # 1. Time step of each row
  # Hours is the project-wide reference unit for time, the same one
  # period_simulation_cpp.cpp uses. The first row is the initial
  # condition of the chunk and gets 0.
  # period_chunk$time must be POSIXct. as.numeric() is applied before
  # diff(), not after: diff() on a POSIXct vector returns a difftime
  # with an automatically chosen unit (seconds, minutes, hours or
  # days, picked from the series' own spacing), so
  # as.numeric(diff(...)) would silently pick up whatever unit R
  # chose instead of always being seconds. Converting to numeric
  # first fixes the unit to seconds before diff() ever runs, so the
  # /3600 below always yields hours regardless of Main_df's
  # resolution.
  # -------------------------------------------------------------
  {
    delta_t_h <- c(0, diff(as.numeric(period_chunk$time)) / 3600)
  }

  # -------------------------------------------------------------
  # 2. Hours out of comfort, weighted
  # -------------------------------------------------------------
  {
    Performance <- ifelse(period_chunk$Comfort_plan == 0 |
                          period_chunk$Comfort_plan_flex_down == 0 |
                          period_chunk$Comfort_plan_flex_up == 0,
                          -1, 0) * delta_t_h

    comfort <- alpha_comfort * Performance

    rm(list = c("alpha_comfort", "delta_t_h", "Performance"))
  }

  return(comfort)
}
