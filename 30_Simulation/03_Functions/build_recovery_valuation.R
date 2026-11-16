# -------------------------------------------------------------
# Function: build_recovery_valuation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the valuation with which the system chooses how an asset
# draws the Recovery Phase of a flexibility window, a tail or a
# window it holds, when the asset can draw it in more than one way.
# A battery can recover the least that keeps its leg inside its
# limits, or buy or sell until it is back on the energy of its plan.
# Which one is better depends on the prices of the market, so the
# system chooses with the terms of the reward that differ between
# the alternatives (choose_recovery()): the cost of the energy the
# Recovery Phase moves, and the value of the energy the leg leaves
# stored.
# Each asset says, through the operation recovery_choices of its type
# of model (model_type_contract()), the alternatives it offers, in
# the order they are tried; the first one is the default. The ones
# that offer any are the assets that choose. They have to offer the
# same alternatives, because one alternative is chosen for all of
# them. When no asset offers any, the system has nothing to choose
# and the function returns NULL, so that a system without such an
# asset works as it does with no valuation at all.
# The valuation carries what choose_recovery() needs: the context of
# the market, which has to hold the price and the discount of the
# stored energy, and the cache of the reward, built on the plan of
# the piece. The plan does not change while the windows of the piece
# are built, so the cache is built once for all of them.
# -------------------------------------------------------------
# Inputs
#   piece            : List. The piece of the planning period, with
#                      the plan of every asset simulated.
#   parameters       : Named list. parameters$assets, the asset
#                      registry, and what build_reward_cache() reads.
#   marginal_context : Named list, as returned by
#                      resolve_marginal_context(). It has to hold
#                      stored_energy_price and
#                      stored_energy_discount when an asset offers
#                      alternatives.
# -------------------------------------------------------------
# Outputs
#   NULL when no asset offers alternatives for the Recovery Phase.
#   Otherwise a named list with:
#     - choices: character vector. The alternatives, in the order
#       they are tried.
#     - choosers: character vector. The asset_id of the assets that
#       offer them, in the order of the registry.
#     - marginal_context: the context of the market.
#     - reward_cache: the cache of the reward of the piece, as
#       build_reward_cache() gives it with no leg fixed.
#   The function stops when two assets offer different alternatives
#   and when the context lacks the price or the discount of the
#   stored energy.
# -------------------------------------------------------------
# Code outline
# 1. The alternatives that the assets offer
# 2. The context and the cache
# -------------------------------------------------------------
# Usage instructions
# recovery_valuation <- build_recovery_valuation(
#   piece            = piece,
#   parameters       = parameters,
#   marginal_context = marginal_context
# )
# -------------------------------------------------------------

build_recovery_valuation <- function(piece,
                                     parameters,
                                     marginal_context
                                     ) {

  # -------------------------------------------------------------
  # 1. The alternatives that the assets offer
  # The assets that offer none, such as a building, are left out.
  # -------------------------------------------------------------
  {
    choices  <- NULL
    choosers <- character(0)

    for (CONT_001 in names(parameters$assets)) {
      asset <- parameters$assets[[CONT_001]]

      # model_type_contract is called to take the operations of the
      # type of model of the asset, which say the alternatives it
      # offers for the Recovery Phase.
      model <- model_type_contract(asset$asset_type)

      # The operation recovery_choices of the model is called to take
      # the alternatives of the asset.
      asset_choices <- model$recovery_choices(asset)

      if (!is.null(asset_choices)) {
        if (is.null(choices)) {
          choices <- asset_choices
        } else if (!identical(choices, asset_choices)) {
          stop("build_recovery_valuation: the assets that offer ",
               "alternatives for the Recovery Phase must offer the ",
               "same ones")
        }
        choosers <- c(choosers, CONT_001)
      }
      rm(list = c("asset", "model", "asset_choices"))
    }
    rm(list = "CONT_001")

    if (is.null(choices)) {
      return(NULL)
    }
  }

  # -------------------------------------------------------------
  # 2. The context and the cache
  # The cache is built on the plan of the piece, with no leg fixed,
  # so that the terms of both legs can be read from it.
  # -------------------------------------------------------------
  {
    if (is.null(marginal_context) ||
        is.null(marginal_context$stored_energy_price) ||
        is.null(marginal_context$stored_energy_discount)) {
      stop("build_recovery_valuation: marginal_context must hold ",
           "stored_energy_price and stored_energy_discount, which ",
           "resolve_marginal_context() gives")
    }

    # build_reward_cache is called to resolve, once, what the reward
    # reads of the rows of the piece: the discount of each row and
    # its target interval.
    reward_cache <- build_reward_cache(
      piece            = piece,
      parameters       = parameters,
      marginal_context = marginal_context,
      fixed_leg        = NULL
    )
  }

  return(list(choices          = choices,
              choosers         = choosers,
              marginal_context = marginal_context,
              reward_cache     = reward_cache))
}
