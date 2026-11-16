# -------------------------------------------------------------
# Function: building_can_hold.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation can_hold of the type of model Building: whether the
# building can keep its electricity apart from its plan in a
# flexibility itinerary. A building can: its heat pump moves energy
# in time through the thermal mass of the building.
# Every operation of the contract receives asset, its parameters
# (model_type_contract()). The building does not read it.
# -------------------------------------------------------------
# Inputs
#   asset : Named list. The parameters of the building, its entry of
#           parameters$assets. Not read.
# -------------------------------------------------------------
# Outputs
#   Logical scalar. TRUE.
# -------------------------------------------------------------
# Code outline
# 1. Answer
# -------------------------------------------------------------
# Usage instructions
# holds <- building_can_hold(asset)
# -------------------------------------------------------------

building_can_hold <- function(asset) {

  # -------------------------------------------------------------
  # 1. Answer
  # -------------------------------------------------------------
  {
    can_hold <- TRUE
  }

  return(can_hold)
}
