# -------------------------------------------------------------
# Function: system_stored_energy.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the change of the energy the assets of the system store on
# each row of a piece, in each of the three itineraries, on the side
# of the system (kWh). It is the one place where the system adds what
# the assets store: the reward values it as stored energy
# (compute_stored_energy_value()).
# Each asset gives its own change through the operation
# stored_energy_change of its type of model (model_type_contract()),
# on its table, and the system adds them in the order of the asset
# registry. An asset that stores no energy gives NULL and adds
# nothing.
# -------------------------------------------------------------
# Inputs
#   piece      : The piece of the planning period, with the table of
#                each asset in piece$assets[[asset_id]]$df.
#   parameters : Named list. parameters$assets, the asset registry,
#                with the parameters of each asset.
# -------------------------------------------------------------
# Outputs
#   NULL when no asset of the registry stores energy. Otherwise a
#   named list with the numeric vectors plan, plan_flex_down and
#   plan_flex_up, one value per row of the piece (kWh, positive when
#   the assets store energy).
# -------------------------------------------------------------
# Code outline
# 1. Add the change of each asset that stores energy
# -------------------------------------------------------------
# Usage instructions
# stored_energy <- system_stored_energy(piece, parameters)
# -------------------------------------------------------------

system_stored_energy <- function(piece,
                                 parameters
                                 ) {

  # -------------------------------------------------------------
  # 1. Add the change of each asset that stores energy
  # The first itinerary tells whether the asset stores energy: an
  # asset that does not gives NULL for it, and is not asked for the
  # other two.
  # -------------------------------------------------------------
  {
    itineraries   <- c("plan", "plan_flex_down", "plan_flex_up")
    stored_energy <- NULL

    for (CONT_001 in names(parameters$assets)) {
      asset <- parameters$assets[[CONT_001]]

      # model_type_contract is called to take the operations of the
      # type of model of the asset, which gives what it stores.
      model <- model_type_contract(asset$asset_type)

      # The operation stored_energy_change of the model is called to
      # take the change of the energy the asset stores in the plan.
      asset_change <- model$stored_energy_change(
        asset_df  = piece$assets[[CONT_001]]$df,
        itinerary = itineraries[1],
        asset     = asset
      )
      if (is.null(asset_change)) {
        rm(list = c("asset", "model", "asset_change"))
        next
      }

      asset_changes <- list(asset_change)
      for (CONT_002 in itineraries[-1]) {
        # The operation stored_energy_change of the model is called
        # again for each flexibility itinerary.
        asset_changes[[length(asset_changes) + 1]] <-
          model$stored_energy_change(
            asset_df  = piece$assets[[CONT_001]]$df,
            itinerary = CONT_002,
            asset     = asset
          )
      }
      names(asset_changes) <- itineraries

      if (is.null(stored_energy)) {
        stored_energy <- asset_changes
      } else {
        for (CONT_002 in itineraries) {
          stored_energy[[CONT_002]] <- stored_energy[[CONT_002]] +
            asset_changes[[CONT_002]]
        }
      }
      rm(list = c("asset", "model", "asset_change", "asset_changes"))
    }
    rm(list = intersect(c("CONT_001", "CONT_002"), ls()))
    rm(list = "itineraries")
  }

  return(stored_energy)
}
