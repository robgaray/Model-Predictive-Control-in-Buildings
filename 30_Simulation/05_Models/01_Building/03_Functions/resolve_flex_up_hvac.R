# -------------------------------------------------------------
# Function: resolve_flex_up_hvac.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Decides which of the two HVAC systems, heating or cooling, may be
# used to offer upward flexibility from a given start row.
# -------------------------------------------------------------
# Why a system has to be fixed at all
# Downward flexibility is symmetric between the two systems: whatever
# is running gets switched off. Upward flexibility is not, because it
# means running a system harder, and running the wrong one would heat
# a building that needs cooling. On top of that, the regulation of
# HVAC systems does not allow energy management through the
# alternating use of heating and cooling, so the building has to
# commit to one system and stay with it - see
# build_hvac_lock_caps() for the restriction that enforces this
# during the Recovery Phase.
# The system is therefore fixed in advance, and only when the
# situation is unambiguous. If it is not, no upward flexibility can
# be committed at that start row.
# -------------------------------------------------------------
# The dominance criterion
# The planned electricity of each system is accumulated over two
# horizons, one medium-term and one short-term. Electricity, and not
# heat, is the quantity the market trades and the one the technical
# feasibility rule (flex_window_is_feasible()) measures, so both rules
# judge the two systems on the same footing:
#
#   S_heat(H) = sum of Elec_heat_plan over the rows in [t0, t0 + H)
#   S_cool(H) = sum of Elec_cool_plan over the same rows
#
# The dominance index is measured over the LARGER of the two, in
# absolute value:
#
#   D(H) = | S_heat(H) - S_cool(H) | / max( |S_heat(H)| , |S_cool(H)| )
#
# It is bounded in [0, 1]: it is 1 when one of the systems is not used
# at all, and 0 when both are used equally. It is undefined only when
# neither system is used, which is treated as "no dominant system".
#
# A system dominates a horizon when D(H) exceeds the threshold, and
# the system is fixed only when both horizons agree:
#
#   s* = dominant(H_long)  if dominant(H_long) == dominant(H_short)
#                          and neither is "none"
#   s* = "none"            otherwise
#
# Requiring both horizons to agree is what filters out the shoulder
# seasons, where the building alternates between heating and cooling
# within the same day and committing to either would be wrong.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. Planning-period data. Must contain the
#                  columns time (POSIXct), Elec_heat_plan and
#                  Elec_cool_plan (Numeric, kWh per timestep, as produced by
#                  period_calculation() with calculation_context =
#                  "plan").
#   i_flex       : Integer scalar. Row of period_chunk at which the
#                  candidate upward flexibility event would start.
#   parameters   : Named list. Must contain:
#                    parameters$control$flex_up_horizon_long  : Numeric (h).
#                    parameters$control$flex_up_horizon_short : Numeric (h).
#                    parameters$control$flex_up_dominance_threshold :
#                      Numeric (%), 0 to 100.
# -------------------------------------------------------------
# Outputs
#   Character scalar, one of:
#     "heat" - heating dominates both horizons; upward flexibility may
#              be offered by running the heating system harder.
#     "cool" - cooling dominates both horizons.
#     "none" - no clear system; no upward flexibility can be committed
#              from this start row.
# -------------------------------------------------------------
# Code outline
# 1. Validate inputs
# 2. Accumulate the planned electricity of each system over the two horizons
# 3. Resolve the dominant system of each horizon
# 4. Fix the system only if both horizons agree
# -------------------------------------------------------------
# Usage instructions
# hvac_up <- resolve_flex_up_hvac(period_chunk, i_flex, parameters)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - The horizon window is half-open, [t0, t0 + H), the same form as
#     the Commitment Phase of system_flex_window(), [t0, t0 + L). It
#     sums "the next H hours" and does not count the boundary row
#     twice if windows are ever chained.
#   - A window truncated by the end of period_chunk is evaluated over
#     the rows that are actually available, down to a single row: the
#     window is [t0, t0 + H) and always contains the start row itself,
#     so it is never empty and this function always returns a verdict.
#     A verdict based on one row is not meaningful on its own, but it
#     is harmless, because the candidate is rejected downstream anyway:
#     system_flex_window() returns the piece untouched when there is
#     not enough room for the full Commitment plus Neutral plus
#     Recovery Phase. Keeping the guard in one place, where the
#     window length is actually known, avoids two different definitions
#     of "too close to the end".
#   - If both systems accumulate zero electricity over a horizon, that
#     horizon has no dominant system and the result is "none".
#   - An exact tie between the two systems also yields "none",
#     because D(H) is then 0 and cannot exceed a threshold that is
#     itself >= 0. A threshold of 0 would still reject a tie, which is
#     the intended behaviour.
# -------------------------------------------------------------
resolve_flex_up_hvac <- function(period_chunk, i_flex, parameters) {

  # 1. Validate inputs
  # -------------------------------------------------------------
  {
    stopifnot(is.numeric(i_flex), length(i_flex) == 1,
              i_flex >= 1, i_flex <= nrow(period_chunk))

    required_cols <- c("time", "Elec_heat_plan", "Elec_cool_plan")
    missing_cols  <- required_cols[!required_cols %in% names(period_chunk)]
    if (length(missing_cols) > 0) {
      stop("resolve_flex_up_hvac: period_chunk is missing required columns: ",
           paste(missing_cols, collapse = ", "))
    }
    rm(list = c("required_cols", "missing_cols"))

    horizon_long_h  <- parameters$control$flex_up_horizon_long
    horizon_short_h <- parameters$control$flex_up_horizon_short
    threshold_pct   <- parameters$control$flex_up_dominance_threshold

    threshold <- threshold_pct / 100
  }

  # 2. Accumulate the planned electricity of each system over a horizon
  # -------------------------------------------------------------
  # The window is half-open: it starts at the candidate's own row and
  # stops before t0 + H. Elec_* columns hold energy per timestep (kWh),
  # so a plain sum is the electricity planned over the horizon.
  # -------------------------------------------------------------
  {
    time_at_i_flex <- period_chunk$time[i_flex]

    dominant_system_of_horizon <- function(horizon_h) {
      end_time    <- time_at_i_flex + horizon_h * 3600
      window_rows <- which(period_chunk$time >= time_at_i_flex &
                             period_chunk$time <  end_time)

      if (length(window_rows) == 0) {
        return("none")
      }

      S_heat <- sum(period_chunk$Elec_heat_plan[window_rows])
      S_cool <- sum(period_chunk$Elec_cool_plan[window_rows])

      # 3. Resolve the dominant system of this horizon
      # -----------------------------------------------------------
      # The index is undefined when neither system is used, which is
      # the "no dominant system" case rather than an error.
      # -----------------------------------------------------------
      scale <- max(abs(S_heat), abs(S_cool))
      if (scale <= 0) {
        return("none")
      }

      D <- abs(S_heat - S_cool) / scale
      if (D <= threshold) {
        return("none")
      }

      if (S_heat > S_cool) "heat" else "cool"
    }

    dominant_long  <- dominant_system_of_horizon(horizon_long_h)
    dominant_short <- dominant_system_of_horizon(horizon_short_h)
  }

  # 4. Fix the system only if both horizons agree
  # -------------------------------------------------------------
  # Disagreement between the two horizons means the situation is not
  # clear enough to commit to a system, which is exactly the case the
  # shoulder seasons produce.
  # -------------------------------------------------------------
  {
    if (dominant_long != "none" && dominant_long == dominant_short) {
      hvac_up <- dominant_long
    } else {
      hvac_up <- "none"
    }
  }

  rm(list = intersect(
    c("horizon_long_h", "horizon_short_h", "threshold_pct", "threshold",
      "time_at_i_flex",
      "dominant_system_of_horizon", "dominant_long", "dominant_short"),
    ls()
  ))

  return(hvac_up)
}
