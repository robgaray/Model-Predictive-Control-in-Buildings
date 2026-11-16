# -------------------------------------------------------------
# Function: system_flex_commitment.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives, row by row, the flexibility that the system commits on one
# leg: the difference between the net electricity of the system in
# the plan and in the itinerary of the leg (system_net_energy()).
#   - Downward, what the itinerary spends below the plan.
#   - Upward, what it spends above the plan, bounded at 0 from below.
# The commitment is that of the net, because the grid only sees the
# net: the contributions of the assets to a window add up, and an
# asset that adds energy can compensate one that sheds it. Upward,
# the bound at 0 is applied to the net, so a row where the assets
# together spend less than the plan sells nothing upward.
# The result is not bounded to the Commitment Phase: the caller keeps
# the rows of the phase it needs.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. A chunk with the net electricity of the
#                  system in the plan and in the itinerary of the leg
#                  (the columns system_net_energy() reads).
#   leg          : Character scalar, "down" or "up".
# -------------------------------------------------------------
# Outputs
#   Numeric vector, one value per row of period_chunk: the
#   electricity committed on the leg, in kWh.
# -------------------------------------------------------------
# Code outline
# 1. Check the leg
# 2. The difference of the net with the plan
# -------------------------------------------------------------
# Usage instructions
# committed <- system_flex_commitment(period_chunk, "down")
# -------------------------------------------------------------

system_flex_commitment <- function(period_chunk,
                                   leg
                                   ) {

  # -------------------------------------------------------------
  # 1. Check the leg
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("system_flex_commitment: leg must be \"down\" or \"up\"")
    }
  }

  # -------------------------------------------------------------
  # 2. The difference of the net with the plan
  # system_net_energy is called for the plan and for the itinerary of
  # the leg, so that the commitment is read from the net electricity
  # of the system and not from the columns of an asset.
  # -------------------------------------------------------------
  {
    net_plan <- system_net_energy(
      itinerary_table = period_chunk,
      itinerary       = "plan"
    )
    net_leg  <- system_net_energy(
      itinerary_table = period_chunk,
      itinerary       = paste0("plan_flex_", leg)
    )

    committed <- if (leg == "down") {
      net_plan - net_leg
    } else {
      pmax(net_leg - net_plan, 0)
    }
    rm(list = c("net_plan", "net_leg"))
  }

  return(committed)
}
