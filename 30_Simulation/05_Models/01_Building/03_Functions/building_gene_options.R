# -------------------------------------------------------------
# Function: building_gene_options.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the number of options of each gene of a building: the number
# of setpoint modes of 13_Modes_setpoints.csv. Each gene of a
# building is the mode of one market interval, a whole number from 1
# to this number. It is the operation gene_options of the type
# Building (see model_type_contract()).
# -------------------------------------------------------------
# Inputs
#   asset : Named list. The parameters of the building, its entry of
#           parameters$assets. Must contain setpoint_modes, the data
#           frame of the setpoint modes, with the column mode.
# -------------------------------------------------------------
# Outputs
#   Integer scalar: the number of distinct modes.
# -------------------------------------------------------------
# Code outline
# 1. Count the modes
# -------------------------------------------------------------
# Usage instructions
# n_modes <- building_gene_options(asset)
# -------------------------------------------------------------

building_gene_options <- function(asset) {

  # -------------------------------------------------------------
  # 1. Count the modes
  # -------------------------------------------------------------
  {
    n_modes <- length(unique(asset$setpoint_modes$mode))
  }

  return(n_modes)
}
