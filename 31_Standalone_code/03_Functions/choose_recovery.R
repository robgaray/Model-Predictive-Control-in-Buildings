# -------------------------------------------------------------
# Function: choose_recovery.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Chooses, among the pieces drawn with each alternative of the
# Recovery Phase of a window, a tail or a hold, the one with the
# best reward. The alternatives are those of
# build_recovery_valuation(), and the first piece is the one drawn
# with the first alternative, the default one.
# The pieces differ only in the Recovery Phase of the assets that
# offer alternatives: the Commitment Phase, the plan and the
# revenues of the commitment and of the execution are the same. What
# changes is, on the leg:
#   - the cost of the energy that the Recovery Phase buys and sells
#     (the recovery_cost of flex_leg_reward_terms());
#   - the value of the energy the leg leaves stored against the plan
#     (the stored_value of flex_leg_reward_terms()).
# With rc and V those two terms in one piece, and f the discount of
# the revenues of the last interval of the horizon, the gain of the
# piece a over the first one is
#   G_a = (rc_a - rc_1) + discount(V_a - V_1, f)
# where the discount applies to the difference only when it is an
# income (apply_revenue_discount()). The first piece has a gain of 0.
# The criterion does not depend on what is already committed, so a
# window chosen when it is sold is chosen the same way when it is
# restated, and the reward of a candidate that repeats what is
# committed adds nothing for the choice.
# With a probability of 0 of the leg, both terms are 0 in every
# piece and the first one is chosen.
# -------------------------------------------------------------
# Inputs
#   pieces             : List of pieces, at least one, drawn with
#                        each alternative, in the order of
#                        recovery_valuation$choices. Each holds the
#                        table of the system and the table of each
#                        asset.
#   leg                : Character, "down" or "up". The leg of the
#                        window, tail or hold.
#   parameters         : Named list. parameters$assets, the asset
#                        registry.
#   recovery_valuation : Named list, as build_recovery_valuation()
#                        gives it.
# -------------------------------------------------------------
# Outputs
#   Named list with:
#     - index: integer scalar. The piece to keep: the one with the
#       greatest gain, the first one in a tie.
#     - gain: numeric vector, one value per piece (EUR). 0 for the
#       first.
#   The function stops when there is no piece, when there is no
#   valuation, and when no asset of the registry stores energy.
# -------------------------------------------------------------
# Code outline
# 1. Check the inputs
# 2. The terms of each piece
# 3. The gain and the choice
# -------------------------------------------------------------
# Usage instructions
# chosen <- choose_recovery(
#   pieces             = list(piece_minimum, piece_plan),
#   leg                = "down",
#   parameters         = parameters,
#   recovery_valuation = recovery_valuation
# )
# pieces[[chosen$index]]
# -------------------------------------------------------------

choose_recovery <- function(pieces,
                            leg,
                            parameters,
                            recovery_valuation
                            ) {

  # -------------------------------------------------------------
  # 1. Check the inputs
  # -------------------------------------------------------------
  {
    if (!is.list(pieces) || length(pieces) < 1) {
      stop("choose_recovery: at least one piece is needed")
    }
    if (is.null(recovery_valuation)) {
      stop("choose_recovery: there is no valuation of the Recovery ",
           "Phase")
    }
    if (length(pieces) == 1) {
      return(list(index = 1L, gain = 0))
    }
  }

  # -------------------------------------------------------------
  # 2. The terms of each piece
  # The cost of the Recovery Phase and the value of the energy the
  # leg leaves stored, read on the net electricity of the system.
  # -------------------------------------------------------------
  {
    recovery_cost <- numeric(length(pieces))
    stored_value  <- numeric(length(pieces))

    for (CONT_001 in seq_along(pieces)) {
      # system_stored_energy is called to add the change of the
      # energy the assets store in the piece. An alternative of the
      # Recovery Phase exists only for an asset that stores energy.
      stored_energy <- system_stored_energy(
        piece      = pieces[[CONT_001]],
        parameters = parameters
      )
      if (is.null(stored_energy)) {
        stop("choose_recovery: no asset of the registry stores energy")
      }

      # system_energy_rows is called to take from the table of the
      # system the rows the economic side values.
      system_rows <- system_energy_rows(
        period_chunk  = pieces[[CONT_001]]$system,
        stored_energy = stored_energy
      )

      # flex_leg_reward_terms is called to value the leg of this
      # piece: the cost of its Recovery Phase and the energy it
      # leaves stored.
      terms <- flex_leg_reward_terms(
        system_rows      = system_rows,
        leg              = leg,
        marginal_context = recovery_valuation$marginal_context,
        reward_cache     = recovery_valuation$reward_cache
      )

      recovery_cost[CONT_001] <- terms$recovery_cost
      stored_value[CONT_001]  <- terms$stored_value
      rm(list = c("stored_energy", "system_rows", "terms"))
    }
    rm(list = "CONT_001")
  }

  # -------------------------------------------------------------
  # 3. The gain and the choice
  # The gain of each piece is measured against the first one.
  # -------------------------------------------------------------
  {
    # apply_revenue_discount is called to discount the gain of the
    # stored energy as the reward discounts an income.
    gain <- (recovery_cost - recovery_cost[1]) +
      apply_revenue_discount(
        value_by_interval    = stored_value - stored_value[1],
        discount_by_interval =
          recovery_valuation$marginal_context$stored_energy_discount
      )

    index <- which.max(gain)
    rm(list = c("recovery_cost", "stored_value"))
  }

  return(list(index = as.integer(index), gain = gain))
}
