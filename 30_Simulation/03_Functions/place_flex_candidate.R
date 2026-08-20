# -------------------------------------------------------------
# Function: place_flex_candidate.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Draws one flexibility event candidate (start + duration), both
# discretized to the market_resolution grid (see
# 01_Agent_Comments/20260723_Plan_Generacion_Flexibilidad.md, Parte
# B.0): duration is an integer number of slots (>= 1, up to
# max_duration_hours/slot), and the start is a slot-aligned position
# within one of the given available segments, chosen so the candidate
# fits entirely inside it. Used identically for Scheduling candidates
# (segments = Available_m, with forbidden zones already removed),
# Piloting candidates (segments = the market's own full horizon, no
# forbidden zones), and basic-mode per-day candidates (segments = the
# day's [0, 24h) window). Returns NULL whenever no candidate can be
# placed (max_duration_hours shorter than one slot, or no segment long
# enough) - a silent, no-error outcome by design (see Parte B.7).
# -------------------------------------------------------------
# Inputs
# available_segments  : Data frame with columns start, end (numeric,
#                       seconds). May have zero rows.
# market_resolution_sec : Numeric scalar. Slot length, in seconds.
# max_duration_hours    : Numeric scalar. Max_flex_period_duration (or
#                       equivalent), in hours.
# -------------------------------------------------------------
# Outputs
# List with t_start_sec, duration_sec (both numeric, seconds), or NULL
# if no candidate could be placed.
# -------------------------------------------------------------
# Usage instructions
# place_flex_candidate(available_segments, market_resolution_sec = 900,
#   max_duration_hours = 2)
# -------------------------------------------------------------
# Where this function/script is used
# Called by generate_flexibility_events.R (complex mode) and directly
# by flexibility_generation.R (basic mode).
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

place_flex_candidate <- function(available_segments, market_resolution_sec, max_duration_hours) {

  if (nrow(available_segments) == 0) {
    return(NULL)
  }

  max_slots <- floor(max_duration_hours * 3600 / market_resolution_sec)
  if (max_slots < 1) {
    return(NULL)
  }

  n_slots      <- 1 + round(runif(1) * (max_slots - 1))
  duration_sec <- n_slots * market_resolution_sec

  seg_lengths <- available_segments$end - available_segments$start
  valid_idx   <- which(seg_lengths >= duration_sec)
  if (length(valid_idx) == 0) {
    return(NULL)
  }

  chosen_idx <- valid_idx[sample.int(length(valid_idx), 1, prob = seg_lengths[valid_idx])]
  seg_start  <- available_segments$start[chosen_idx]
  seg_end    <- available_segments$end[chosen_idx]

  max_k <- floor((seg_end - seg_start - duration_sec) / market_resolution_sec)
  k     <- if (max_k < 1) 0 else sample.int(max_k + 1, 1) - 1

  t_start_sec <- seg_start + k * market_resolution_sec

  list(t_start_sec = t_start_sec, duration_sec = duration_sec)
}
