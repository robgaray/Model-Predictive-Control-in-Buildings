# -------------------------------------------------------------
# Function: building_restate_systems.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Says with which systems a building may redraw a flexibility window
# already sold, when it cannot redraw it as it would sell it. It is
# the operation restate_systems of the type of model Building
# (model_type_contract()).
# -------------------------------------------------------------
# The system of a standing upward window
# Which system serves a standing upward window is not stored: only
# the energy of the window is. It is found again over the new plan.
# When the prudence rule of resolve_flex_up_hvac() names a system, the
# window is redrawn with it, as it would be sold, and there is nothing
# to choose. When the rule is undecided, the window is not refused
# for that: the rule decides whether a NEW window is sold, and this
# one was already sold. Both systems are then candidates, and the
# caller (derive_flex_itineraries()) keeps the one that delivers more
# of what was sold. When both deliver all of it, the preferred one is
# the system that uses more electricity in the plan over the long
# horizon of the rule (flex_up_horizon_long).
# A downward window switches off whatever runs, so it has no system
# to choose.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. The view of the building, with the plan
#                  simulated. Reads what resolve_flex_up_hvac() reads.
#   leg          : Character scalar, "down" or "up".
#   i_flex       : Integer scalar. The first row of the Commitment
#                  Phase of the window.
#   parameters   : Named list. Reads what resolve_flex_up_hvac() reads:
#                  the horizons and the threshold of the prudence rule.
#   asset        : Named list. The parameters of the building, its
#                  entry of parameters$assets. Not read: the rule is
#                  measured on the plan of the chunk.
# -------------------------------------------------------------
# Outputs
#   NULL when the building redraws the window as it would sell it.
#   Otherwise a named list:
#     candidates : Character vector, c("heat", "cool"), the systems
#                  the window may be redrawn with, in the order they
#                  are tried.
#     preferred  : Character scalar, "heat", "cool" or "none", the
#                  system that uses more electricity in the plan over
#                  the long horizon of the rule.
# -------------------------------------------------------------
# Code outline
# 1. Check the leg
# 2. The candidates of an undecided upward window
# -------------------------------------------------------------
# Usage instructions
# options <- building_restate_systems(period_chunk = period_chunk,
#                                     leg          = "up",
#                                     i_flex       = i_flex,
#                                     parameters   = parameters,
#                                     asset        = asset)
# -------------------------------------------------------------

building_restate_systems <- function(period_chunk,
                                     leg,
                                     i_flex,
                                     parameters,
                                     asset) {

  # -------------------------------------------------------------
  # 1. Check the leg
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("building_restate_systems: leg must be 'down' or 'up'")
    }
    if (leg == "down") {
      return(NULL)
    }
  }

  # -------------------------------------------------------------
  # 2. The candidates of an undecided upward window
  # -------------------------------------------------------------
  {
    # resolve_flex_up_hvac is called to know whether the prudence
    # rule names a system for this window.
    if (resolve_flex_up_hvac(period_chunk, i_flex, parameters) != "none") {
      return(NULL)
    }

    # resolve_flex_up_hvac is called over the long horizon alone, at a
    # threshold of zero, for the system that uses more electricity in
    # the plan there.
    long_rule <- parameters
    long_rule$control$flex_up_horizon_short <-
      parameters$control$flex_up_horizon_long
    long_rule$control$flex_up_dominance_threshold <- 0
    preferred <- resolve_flex_up_hvac(period_chunk, i_flex, long_rule)
    rm(list = "long_rule")
  }

  return(list(candidates = c("heat", "cool"), preferred = preferred))
}
