# -------------------------------------------------------------
# Function: hold_standing_window.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Keeps a standing flexibility commitment that the builder would not
# rebuild, by writing it straight onto the electricity itinerary of the
# leg and marking its Commitment Phase.
# -------------------------------------------------------------
# Why it exists
# A market that does not trade flexibility has to carry the standing
# commitment forward untouched. Until this function existed, a window
# the builder refused was simply dropped: the market bought the
# commitment back and re-issued nothing, so the energy left the books
# with no counterpart. In a run whose Piloting markets did not trade
# flexibility, that happened on 88 of every 100 rebuys. See
# 01_Agent_Comments/20260920b_Diagnostico_Compromiso_Vigente.md.
# -------------------------------------------------------------
# What it does and does not do
# reward_function() recomputes the committed energy as the difference
# between the plan and the leg's itinerary over the Commitment Phase,
# so writing that difference is what preserves the commitment exactly.
# The THERMAL columns of the itinerary are left as the plan's. The
# window this is used on is one whose tail falls outside the control
# horizon, so its thermal trajectory is not executed inside this
# market's horizon anyway, and the next market rebuilds it in full.
# Holding the commitment with an approximate thermal itinerary is worth
# more than losing the commitment, which is the alternative.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. The chunk being derived.
#   leg          : Character scalar, "down" or "up".
#   window_rows  : Integer vector. Rows of the standing Commitment
#                  Phase.
#   standing     : Numeric vector as long as period_chunk has rows. The
#                  committed energy of the leg, in kWh, as the previous
#                  market left it.
# -------------------------------------------------------------
# Outputs
#   The chunk with Elec_total_plan_flex_<leg> carrying the standing
#   commitment over window_rows and Flex_phase_<leg>_plan set to 1
#   there.
# -------------------------------------------------------------
# Code outline
# 1. The rows worth holding
# 2. Impose the commitment on the electricity itinerary
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- hold_standing_window(period_chunk, "down", rows, standing)
# -------------------------------------------------------------
# Where this function/script is used
# Called by derive_flex_itineraries() when the builder refuses a
# standing window for any reason other than opposed systems.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
hold_standing_window <- function(period_chunk, leg, window_rows, standing) {

  # 1. The rows worth holding
  # -------------------------------------------------------------
  {
    if (!leg %in% c("down", "up")) {
      stop("hold_standing_window: leg must be 'down' or 'up'")
    }

    window_rows <- window_rows[window_rows >= 1 & window_rows <= nrow(period_chunk)]
    if (length(window_rows) == 0) {
      return(period_chunk)
    }

    held <- standing[window_rows]
    held[is.na(held)] <- 0
  }

  # 2. Impose the commitment on the electricity itinerary
  # -------------------------------------------------------------
  # Downward flexibility takes electricity away from the plan and
  # upward flexibility adds it, which is the sign convention
  # reward_function() reads the two legs with.
  {
    itinerary_col <- paste0("Elec_total_plan_flex_", leg)
    phase_col     <- paste0("Flex_phase_", leg, "_plan")

    period_chunk[[itinerary_col]][window_rows] <-
      if (leg == "down") {
        period_chunk$Elec_total_plan[window_rows] - held
      } else {
        period_chunk$Elec_total_plan[window_rows] + held
      }

    period_chunk[[phase_col]][window_rows] <- 1L
  }

  return(period_chunk)
}
