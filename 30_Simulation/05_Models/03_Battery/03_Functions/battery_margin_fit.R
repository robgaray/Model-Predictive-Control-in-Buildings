# -------------------------------------------------------------
# Function: battery_margin_fit.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Fits the margin data of a battery inside the band of the system,
# when it is the only asset that contributes to a flexibility window.
# It is the operation margin_fit of the type of model Battery
# (model_type_contract()).
# The quantity a battery moves is its electricity, and its
# electricity is linear in the share of its departure from the plan
# that the margin leaves. So the rule of system_commitment_margin()
# for a set of assets has a closed form here. In each market interval
# of the band, with P the electricity of the plan and F the
# electricity of the itinerary drawn before the margin, both added
# over the rows of the interval, and with the band bound by the
# limit of the leg and the margin:
#   - if F is inside the band, the share is 1;
#   - if P is outside the band, the share is 0: the interval has no
#     service to offer and the battery keeps its plan;
#   - otherwise the share is (bound - P) / (F - P), between 0 and 1.
# Each row of the interval then takes its plan plus the share of its
# departure. A row that belongs to no interval keeps the itinerary
# as it was drawn.
# -------------------------------------------------------------
# Inputs
#   margin     : Named list. The margin data of the battery, as
#                battery_window_draft() gives it: plan and profile,
#                lists with the vector Elec (kWh), one entry per row
#                of the guard zone.
#   band       : Named list. The band of the set, as
#                commitment_margin_bound() gives it: slot_id, the
#                interval of each row of the guard zone (0 when it has
#                none), and bound, the electricity the interval may
#                reach (kWh).
#   leg        : Character scalar, "down" or "up".
#   parameters : Named list. Not read.
#   asset      : Named list. The parameters of the battery. Not read.
# -------------------------------------------------------------
# Outputs
#   Named list with the vector Elec (kWh): the electricity of each row
#   of the guard zone after the margin.
# -------------------------------------------------------------
# Code outline
# 1. Check the inputs
# 2. Fit each market interval
# -------------------------------------------------------------
# Usage instructions
# fitted <- battery_margin_fit(margin     = draft$margin,
#                              band       = band,
#                              leg        = "down",
#                              parameters = parameters,
#                              asset      = asset)
# -------------------------------------------------------------

battery_margin_fit <- function(margin,
                               band,
                               leg,
                               parameters,
                               asset
                               ) {

  # -------------------------------------------------------------
  # 1. Check the inputs
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("battery_margin_fit: leg must be \"down\" or \"up\"")
    }
    if (length(margin$plan$Elec) != length(margin$profile$Elec) ||
        length(band$slot_id) != length(margin$plan$Elec)) {
      stop("battery_margin_fit: the margin data and the band must have ",
           "one entry per row of the guard zone (", asset$asset_id, ")")
    }

    # Upward the electricity of an interval must stay at or below its
    # bound; downward, at or above it.
    inside <- function(value, bound) {
      return(if (leg == "up") value <= bound else value >= bound)
    }
  }

  # -------------------------------------------------------------
  # 2. Fit each market interval
  # -------------------------------------------------------------
  {
    plan    <- margin$plan$Elec
    profile <- margin$profile$Elec
    fitted  <- profile

    for (CONT_001 in seq_along(band$bound)) {
      rows       <- which(band$slot_id == CONT_001)
      plan_slot  <- sum(plan[rows])
      drawn_slot <- sum(profile[rows])

      share <- if (inside(drawn_slot, band$bound[CONT_001])) {
        1
      } else if (!inside(plan_slot, band$bound[CONT_001])) {
        0
      } else {
        min(max((band$bound[CONT_001] - plan_slot) /
                  (drawn_slot - plan_slot), 0), 1)
      }

      fitted[rows] <- plan[rows] + share * (profile[rows] - plan[rows])
    }

    rm(list = c("inside", "plan", "profile"))
    rm(list = intersect(c("CONT_001", "rows", "plan_slot", "drawn_slot",
                          "share"), ls()))
  }

  return(list(Elec = fitted))
}
