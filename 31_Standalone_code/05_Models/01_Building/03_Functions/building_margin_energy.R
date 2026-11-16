# -------------------------------------------------------------
# Function: building_margin_energy.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the electricity a building draws, row by row, over the guard
# zone of the Commitment Phase of a flexibility window, for a given
# heating and cooling. It is the operation margin_energy of the type
# of model Building (model_type_contract()).
# The commitment margin is of the set of assets, and the system
# measures it on their net electricity (system_commitment_margin()).
# The system scales the heat of the building, and asks it here what
# that heat draws: the electrical model of the building is its own.
# The electricity is computed with the electrical model of the period
# simulation, at the COP and the time step of the margin data of the
# building (building_margin_data()).
# -------------------------------------------------------------
# Inputs
#   margin  : Named list. The margin data of the building, as
#             building_margin_data() gives it. Reads cop_heat and
#             delta_t_h.
#   control : Named list. The heat of the building on the rows of the
#             margin data, in kWh: list(Q_heat, Q_cool), as the plan
#             and the profile of the margin data hold it.
#   asset   : Named list. The parameters of the building, its entry of
#             parameters$assets. Reads asset$model, for the heat pump.
# -------------------------------------------------------------
# Outputs
#   Numeric vector, one entry per row of the margin data: the
#   electricity (kWh) the building draws with that heat.
# -------------------------------------------------------------
# Code outline
# 1. The electricity of each row
# -------------------------------------------------------------
# Usage instructions
# Needs period_simulation_cpp.cpp compiled with Rcpp::sourceCpp().
# energy <- building_margin_energy(margin  = margin,
#                                  control = margin$plan,
#                                  asset   = asset)
# -------------------------------------------------------------

building_margin_energy <- function(margin,
                                   control,
                                   asset) {

  # -------------------------------------------------------------
  # 1. The electricity of each row
  # -------------------------------------------------------------
  {
    # heat_pump_electricity is called for the electricity of each
    # row, with the electrical model of the period simulation.
    energy <- heat_pump_electricity(
      Q_heat     = control$Q_heat,
      Q_cool     = control$Q_cool,
      cop_heat   = margin$cop_heat,
      delta_t_h  = margin$delta_t_h,
      asset      = asset
    )
  }

  return(energy)
}
