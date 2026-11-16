# -------------------------------------------------------------
# Function: asset_simulation_order.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the order in which the assets of the registry are simulated
# over a plan or a step of the execution. An asset whose type reads
# the net electricity of the rest of the system (the operation
# reads_rest_net of its contract, see model_type_contract()) needs
# the electricity of the other assets before it is simulated. So the
# assets that do not read it come first, in the order of the
# registry, and the assets that read it come after them, also in the
# order of the registry. With no asset that reads it, the order is
# that of the registry.
# -------------------------------------------------------------
# Inputs
#   parameters : Named list. The parameters of the simulation, with
#                assets, one entry per asset of the registry in its
#                order, each one with its asset_type.
# -------------------------------------------------------------
# Outputs
#   Character vector. The asset_id of every asset, in the order of
#   simulation.
# -------------------------------------------------------------
# Code outline
# 1. Split the assets by what they read
# 2. Give the order
# -------------------------------------------------------------
# Usage instructions
# for (CONT_001 in asset_simulation_order(parameters)) {
#   asset <- parameters$assets[[CONT_001]]
# }
# -------------------------------------------------------------

asset_simulation_order <- function(parameters
                                   ) {

  # -------------------------------------------------------------
  # 1. Split the assets by what they read
  # -------------------------------------------------------------
  {
    asset_ids <- names(parameters$assets)
    reads     <- logical(length(asset_ids))

    for (CONT_001 in seq_along(asset_ids)) {
      asset <- parameters$assets[[asset_ids[CONT_001]]]

      # model_type_contract is called to take the operations of the
      # type of model of the asset, which say whether it reads the
      # net electricity of the rest of the system.
      model <- model_type_contract(asset$asset_type)
      reads[CONT_001] <- isTRUE(model$reads_rest_net(asset))
    }
    rm(list = c("CONT_001", "asset", "model"))
  }

  # -------------------------------------------------------------
  # 2. Give the order
  # -------------------------------------------------------------
  {
    order <- c(asset_ids[!reads], asset_ids[reads])
    rm(list = c("asset_ids", "reads"))
  }

  return(order)
}
