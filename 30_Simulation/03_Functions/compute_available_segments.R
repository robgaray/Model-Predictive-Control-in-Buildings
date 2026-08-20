# -------------------------------------------------------------
# Function: compute_available_segments.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Generic interval arithmetic: given a horizon [horizon_begin,
# horizon_end] (numeric, seconds since epoch) and a list of forbidden
# intervals (each a length-2 numeric vector c(lo, hi), in the same
# units), returns the free segments of the horizon once every
# forbidden interval has been clipped to the horizon and merged. Makes
# no assumption about how many forbidden intervals there are, whether
# they overlap each other, or how they relate to any particular market
# configuration - see 01_Agent_Comments/20260723_Plan_Generacion_Flexibilidad.md,
# Parte A / B.3.
# -------------------------------------------------------------
# Inputs
# horizon_begin       : Numeric scalar. Start of the horizon (seconds).
# horizon_end         : Numeric scalar. End of the horizon (seconds).
# forbidden_intervals : List of length-2 numeric vectors c(lo, hi).
#                       May be empty (list()).
# -------------------------------------------------------------
# Outputs
# Data frame with columns start, end (numeric, seconds): the free
# segments within [horizon_begin, horizon_end], in ascending order.
# Zero rows if the whole horizon is forbidden or horizon_end <=
# horizon_begin.
# -------------------------------------------------------------
# Usage instructions
# compute_available_segments(horizon_begin, horizon_end,
#   list(c(lo1, hi1), c(lo2, hi2)))
# -------------------------------------------------------------
# Where this function/script is used
# Called by generate_flexibility_events.R and try_flex_echo.R.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

compute_available_segments <- function(horizon_begin, horizon_end, forbidden_intervals) {

  if (!is.finite(horizon_begin) || !is.finite(horizon_end) || horizon_end <= horizon_begin) {
    return(data.frame(start = numeric(0), end = numeric(0)))
  }

  if (length(forbidden_intervals) == 0) {
    return(data.frame(start = horizon_begin, end = horizon_end))
  }

  clipped <- lapply(forbidden_intervals, function(iv) {
    lo <- max(iv[1], horizon_begin)
    hi <- min(iv[2], horizon_end)
    if (hi > lo) c(lo, hi) else NULL
  })
  clipped <- clipped[!vapply(clipped, is.null, logical(1))]

  if (length(clipped) == 0) {
    return(data.frame(start = horizon_begin, end = horizon_end))
  }

  mat <- do.call(rbind, clipped)
  mat <- mat[order(mat[, 1]), , drop = FALSE]

  merged <- mat[1, , drop = FALSE]
  if (nrow(mat) > 1) {
    for (CONT_001 in 2:nrow(mat)) {
      last_row <- nrow(merged)
      if (mat[CONT_001, 1] <= merged[last_row, 2]) {
        merged[last_row, 2] <- max(merged[last_row, 2], mat[CONT_001, 2])
      } else {
        merged <- rbind(merged, mat[CONT_001, , drop = FALSE])
      }
    }
  }

  starts <- c(horizon_begin, merged[, 2])
  ends   <- c(merged[, 1], horizon_end)
  keep   <- ends > starts

  data.frame(start = starts[keep], end = ends[keep])
}
