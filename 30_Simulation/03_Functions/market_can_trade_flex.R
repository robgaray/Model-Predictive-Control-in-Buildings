# -------------------------------------------------------------
# Function: market_can_trade_flex.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Says whether a market may trade flexibility in order to keep every
# itinerary inside the commitment margin.
#
# Every aim may, except the purely operational one. A market that
# optimizes energy, or energy and flexibility, or operation and
# flexibility, can give back the part of a standing commitment that no
# longer fits the margin, and the economic chain books that as a
# re-purchase against the earlier sale. Only a market whose aim is
# operation alone has no flexibility of its own to move.
#
# Why energy markets are included
# -------------------------------------------------------------
# A market whose aim is energy does not place new flexibility windows,
# but it does carry the ones earlier markets sold, and its own
# re-optimization is what most often leaves them unsustainable: it is
# the family that moves the planned itinerary. Denying it the ability
# to unwind what it can no longer hold is what made it break the
# commitment instead of giving it back.
# -------------------------------------------------------------
# Inputs
# optimization_aim : Character, length 1. The aim of the market that is
#                    clearing, as map_optimization_aim() returns it:
#                    "energy", "flexibility", "operation" or
#                    "operationflex".
# -------------------------------------------------------------
# Outputs
# Logical, length 1. TRUE when the market may trade flexibility.
# -------------------------------------------------------------
# Code outline
# 1. Every aim but the purely operational one.
# -------------------------------------------------------------
# Usage instructions
# can_retrade_flex <- market_can_trade_flex(parameters$control$optimization_aim)
# -------------------------------------------------------------
# Where this function/script is used
# 30_Simulation/03_Functions/derive_flex_itineraries.R
# 30_Simulation/03_Functions/flex_evaluation_up.R
# 30_Simulation/03_Functions/flex_evaluation_down.R
# -------------------------------------------------------------
# functions/scripts called
# None.
# -------------------------------------------------------------

market_can_trade_flex <- function(optimization_aim) {

  # -------------------------------------------------------------
  # 1. Every aim but the purely operational one
  # The list is written out rather than negated, so that an aim the
  # mapping does not produce never reads as able to trade.
  # -------------------------------------------------------------

  {
    answer <- identical(as.character(optimization_aim)[1], "energy") ||
      identical(as.character(optimization_aim)[1], "flexibility") ||
      identical(as.character(optimization_aim)[1], "operationflex")
  }

  return(answer)
}
