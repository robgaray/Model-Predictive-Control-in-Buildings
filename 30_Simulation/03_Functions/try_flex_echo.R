# -------------------------------------------------------------
# Function: try_flex_echo.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Implements the Scheduling-only "echo" mechanism (advance/delay) of
# 01_Agent_Comments/20260723_Plan_Generacion_Flexibilidad.md, Parte
# B.4: given a not-yet-displaced Scheduling event whose forbidden zone
# overlaps a new Scheduling market's horizon, independently rolls
# P_advance/P_delay (tie-broken by an extra random number if both
# roll), and - if a direction is chosen - shifts the event by a
# market_resolution-aligned Delta (Parte B.0) and checks whether the
# shifted event still fits entirely within the horizon once every
# *other* Scheduling event's forbidden zone has been removed. Does not
# resample the shifted position: either the single deterministic shift
# fits, or it does not (no second attempt within this call - a later
# market may offer the event another echo, per Part B.4/D "until the
# first success").
# -------------------------------------------------------------
# Inputs
# event                  : List with t_start_sec, duration_sec (the
#                          event being offered an echo).
# horizon_begin, horizon_end : Numeric scalars (seconds). The current
#                          Scheduling market's Horizon(m).
# other_events           : List of lists, each with t_start_sec,
#                          duration_sec - every other currently active
#                          Scheduling event (i.e. E_sched minus
#                          `event` itself).
# P_advance, P_delay     : Numeric scalars in [0,1].
# Max_shift_hours        : Numeric scalar (hours).
# market_resolution_sec  : Numeric scalar (seconds).
# margin_sec             : Numeric scalar (seconds). The exclusion
#                          margin used to build each event's forbidden
#                          zone (3600*3 by default, see Parte B.1).
# -------------------------------------------------------------
# Outputs
# List with `accepted` (logical) and, when TRUE, `t_start_sec`,
# `duration_sec` for the shifted event.
# -------------------------------------------------------------
# Usage instructions
# try_flex_echo(event, horizon_begin, horizon_end, other_events,
#   P_advance, P_delay, Max_shift_hours, market_resolution_sec)
# -------------------------------------------------------------
# Where this function/script is used
# Called by generate_flexibility_events.R.
# -------------------------------------------------------------
# functions/scripts called
#   compute_available_segments()
# -------------------------------------------------------------

try_flex_echo <- function(event, horizon_begin, horizon_end, other_events,
                          P_advance, P_delay, Max_shift_hours,
                          market_resolution_sec, margin_sec = 3 * 3600) {

  roll_advance <- runif(1) < P_advance
  roll_delay   <- runif(1) < P_delay

  direction <- NULL
  if (roll_advance && roll_delay) {
    direction <- if (runif(1) < 0.5) "advance" else "delay"
  } else if (roll_advance) {
    direction <- "advance"
  } else if (roll_delay) {
    direction <- "delay"
  }

  if (is.null(direction)) {
    return(list(accepted = FALSE))
  }

  max_slots <- floor(Max_shift_hours * 3600 / market_resolution_sec)
  if (max_slots < 1) {
    return(list(accepted = FALSE))
  }

  n_slots   <- 1 + round(runif(1) * (max_slots - 1))
  delta_sec <- n_slots * market_resolution_sec

  new_start <- if (direction == "advance") {
    event$t_start_sec - delta_sec
  } else {
    event$t_start_sec + delta_sec
  }
  new_end <- new_start + event$duration_sec

  forbidden <- lapply(other_events, function(f) {
    c(f$t_start_sec - margin_sec, f$t_start_sec + f$duration_sec + margin_sec)
  })

  # compute_available_segments is called to remove every other active
  # event's forbidden zone from the current horizon, so the shifted
  # candidate position can be checked against the space that is
  # actually still free.
  segments <- compute_available_segments(horizon_begin, horizon_end, forbidden)

  if (nrow(segments) == 0) {
    return(list(accepted = FALSE))
  }

  fits <- any(new_start >= segments$start & new_end <= segments$end)
  if (!fits) {
    return(list(accepted = FALSE))
  }

  list(accepted = TRUE, t_start_sec = new_start, duration_sec = event$duration_sec)
}
