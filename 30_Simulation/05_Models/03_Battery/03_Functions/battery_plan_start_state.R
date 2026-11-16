# -------------------------------------------------------------
# Function: battery_plan_start_state.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation plan_start_state of the type of model Battery: starts
# the plan of the battery from the energy it has actually stored.
# Row 1 of the chunk is i0, the row the market clears on. The
# execution step of the row before has already written the energy
# the battery stored there, with the real electricity of the system.
# The plan of the market starts from that energy, and not from the
# one an earlier market planned for i0. The flexibility itineraries
# are copies of the plan, so they start from the same energy.
# Every type of model receives asset, its parameters, as every
# operation of the contract does (model_type_contract()). The
# battery does not read it.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. The view of the battery over the
#                  period of a market, with the columns
#                  Stored_energy_exec and Stored_energy_plan.
#   asset        : Named list. The parameters of the battery, its
#                  entry of parameters$assets. Not read.
# -------------------------------------------------------------
# Outputs
#   Data frame. The chunk with row 1 of Stored_energy_plan equal to
#   that of Stored_energy_exec.
# -------------------------------------------------------------
# Code outline
# 1. Copy the executed energy into row 1 of the plan
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- battery_plan_start_state(period_chunk, asset)
# -------------------------------------------------------------

battery_plan_start_state <- function(period_chunk,
                                     asset
                                     ) {

  # -------------------------------------------------------------
  # 1. Copy the executed energy into row 1 of the plan
  # -------------------------------------------------------------
  {
    period_chunk$Stored_energy_plan[1] <- period_chunk$Stored_energy_exec[1]
  }

  return(period_chunk)
}
