# -------------------------------------------------------------
# Function: building_slot_offer.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Says whether a building may have something to offer on a new
# flexibility window of one leg that starts in a market interval. It
# is the operation slot_offer of the type of model Building
# (model_type_contract()).
# It is a cheap check made before any simulation, so that the search
# for flexibility windows skips the intervals where nothing can be
# offered.
#   - Downward: the building has something to switch off when it
#     consumes in the interval, that is, when its planned electricity
#     over the interval is above the energy tolerance.
#   - Upward: the building has something to switch on when the
#     prudence rule of resolve_flex_up_hvac() names a system at the
#     first row of the interval.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. Planning-period data, with the plan
#                  simulated. Must hold Elec_total_plan for the
#                  downward leg, and what resolve_flex_up_hvac() reads
#                  for the upward leg.
#   leg          : Character scalar, "down" or "up".
#   slot_rows    : Integer vector, not empty. The rows of period_chunk
#                  that belong to the market interval.
#   parameters   : Named list. Reads
#                  parameters$computing$flex_energy_tol (downward) and
#                  what resolve_flex_up_hvac() reads (upward).
#   asset        : Named list. The parameters of the building, its
#                  entry of parameters$assets. Not read: the check is
#                  made on the plan of the chunk.
# -------------------------------------------------------------
# Outputs
#   Logical scalar. TRUE when the building may offer on the leg in
#   the interval, FALSE when it has nothing to offer.
# -------------------------------------------------------------
# Code outline
# 1. Check the inputs
# 2. Downward leg
# 3. Upward leg
# -------------------------------------------------------------
# Usage instructions
# offered <- building_slot_offer(period_chunk = period_chunk,
#                                leg          = "down",
#                                slot_rows    = market_slot_rows,
#                                parameters   = parameters,
#                                asset        = asset)
# -------------------------------------------------------------

building_slot_offer <- function(period_chunk,
                                leg,
                                slot_rows,
                                parameters,
                                asset) {

  # -------------------------------------------------------------
  # 1. Check the inputs
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("building_slot_offer: leg must be \"down\" or \"up\"")
    }
    if (!is.numeric(slot_rows) || length(slot_rows) == 0 ||
        anyNA(slot_rows) || any(slot_rows != round(slot_rows)) ||
        any(slot_rows < 1) || any(slot_rows > nrow(period_chunk))) {
      stop("building_slot_offer: slot_rows must be a non-empty ",
           "integer vector of rows of period_chunk")
    }
  }

  # -------------------------------------------------------------
  # 2. Downward leg
  # The building consumes in the interval when its planned
  # electricity is above the energy tolerance. The electricity of a
  # building is never negative, so the sum has no sign to take care
  # of.
  # -------------------------------------------------------------
  {
    if (leg == "down") {
      if (!"Elec_total_plan" %in% names(period_chunk)) {
        stop("building_slot_offer: period_chunk has no Elec_total_plan")
      }
      return(sum(period_chunk$Elec_total_plan[slot_rows]) >
               parameters$computing$flex_energy_tol)
    }
  }

  # -------------------------------------------------------------
  # 3. Upward leg
  # The building can raise its electricity from the interval when the
  # prudence rule names a system at its first row.
  # -------------------------------------------------------------
  {
    # resolve_flex_up_hvac is called to find the system that would
    # serve an upward window starting at the first row of the
    # interval, "none" when the rule names no system.
    return(resolve_flex_up_hvac(period_chunk, slot_rows[1], parameters) !=
             "none")
  }
}
