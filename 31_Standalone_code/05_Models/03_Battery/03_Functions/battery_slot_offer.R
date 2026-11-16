# -------------------------------------------------------------
# Function: battery_slot_offer.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Says whether a battery may have something to offer on a new
# flexibility window of one leg that starts in a market interval. It
# is the operation slot_offer of the type of model Battery
# (model_type_contract()).
# It is a cheap check made before any simulation, on the itinerary of
# the leg, not on the plan. On any row of the interval:
#   - Downward: the battery has something to give when it is not
#     already discharging at its full power, and it either has energy
#     above its minimum to discharge or is charging, so that it may
#     stop charging.
#   - Upward: the battery has something to take when it is not
#     already charging at its full power, and it either has room
#     under its maximum energy or is discharging, so that it may stop
#     discharging.
# The comparisons have the tolerance of the energy of the
# flexibility.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. The view of the battery, with the
#                  columns time and, for the itinerary of the leg,
#                  Elec_charge_plan_flex_<leg>,
#                  Elec_discharge_plan_flex_<leg> and
#                  Stored_energy_plan_flex_<leg>.
#   leg          : Character scalar, "down" or "up".
#   slot_rows    : Integer vector, not empty. The rows of period_chunk
#                  that belong to the market interval, from row 2 on.
#   parameters   : Named list. Reads
#                  parameters$computing$flex_energy_tol (kWh).
#   asset        : Named list. The parameters of the battery, its
#                  entry of parameters$assets.
# -------------------------------------------------------------
# Outputs
#   Logical scalar. TRUE when the battery may offer on the leg in the
#   interval, FALSE when it has nothing to offer.
# -------------------------------------------------------------
# Code outline
# 1. Check the inputs
# 2. The limits and the verdict
# -------------------------------------------------------------
# Usage instructions
# offered <- battery_slot_offer(period_chunk = period_chunk,
#                               leg          = "down",
#                               slot_rows    = market_slot_rows,
#                               parameters   = parameters,
#                               asset        = asset)
# -------------------------------------------------------------

battery_slot_offer <- function(period_chunk,
                               leg,
                               slot_rows,
                               parameters,
                               asset
                               ) {

  # -------------------------------------------------------------
  # 1. Check the inputs
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("battery_slot_offer: leg must be \"down\" or \"up\"")
    }
    if (!is.numeric(slot_rows) || length(slot_rows) == 0 ||
        anyNA(slot_rows) || any(slot_rows != round(slot_rows)) ||
        any(slot_rows < 2) || any(slot_rows > nrow(period_chunk))) {
      stop("battery_slot_offer: slot_rows must be a non-empty integer ",
           "vector of rows of period_chunk from row 2 on")
    }

    sfx    <- paste0("_plan_flex_", leg)
    needed <- c("time", paste0("Elec_charge", sfx),
                paste0("Elec_discharge", sfx), paste0("Stored_energy", sfx))
    missing_cols <- setdiff(needed, names(period_chunk))
    if (length(missing_cols) > 0) {
      stop("battery_slot_offer: period_chunk is missing required ",
           "columns: ", paste(missing_cols, collapse = ", "))
    }
  }

  # -------------------------------------------------------------
  # 2. The limits and the verdict
  # The energy a row starts from is the one of the row before it, and
  # the hours of a day and the percent are conversions of unit.
  # -------------------------------------------------------------
  {
    battery    <- asset$battery
    tol        <- parameters$computing$flex_energy_tol
    delta_t_h  <- (as.numeric(period_chunk$time[slot_rows]) -
                     as.numeric(period_chunk$time[slot_rows - 1])) / 3600
    request    <- period_chunk[[paste0("Elec_charge", sfx)]][slot_rows] -
      period_chunk[[paste0("Elec_discharge", sfx)]][slot_rows]
    energy_0   <- period_chunk[[paste0("Stored_energy", sfx)]][slot_rows - 1]
    energy_max <- battery$SOC_max * battery$Capacity
    energy_min <- battery$SOC_min * battery$Capacity

    offered <- if (leg == "down") {
      any(request > -battery$Discharge_power_max * delta_t_h + tol &
            (energy_0 > energy_min + tol | request > tol))
    } else {
      any(request < battery$Charge_power_max * delta_t_h - tol &
            (energy_0 < energy_max - tol | request < -tol))
    }

    rm(list = c("sfx", "needed", "missing_cols", "battery", "tol", "delta_t_h",
                "request", "energy_0", "energy_max", "energy_min"))
  }

  return(offered)
}
