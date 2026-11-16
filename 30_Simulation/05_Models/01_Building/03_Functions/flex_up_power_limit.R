# -------------------------------------------------------------
# Function: flex_up_power_limit.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Returns the heat power that bounds an upward flexibility window of a
# system: the most the window may raise that system to.
#   - Heating: Q_hp_heat_1 or Q_hp_heat_2, as
#     flex_up_max_power_heating names. They are the rated capacities
#     of the two operating points of the heat pump, and which of them
#     bounds an upward window is a modelling decision rather than a
#     fact of the equipment. Above Q_hp_heat_1 the heat comes from the
#     backup resistances, at COP 1.
#   - Cooling: Q_hp_cool, its only rated capacity.
# The window builder and the holding of a standing window read the
# bound here, so both stop at the same limit.
# -------------------------------------------------------------
# Inputs
#   hvac_up    : Character scalar, "heat" or "cool".
#   parameters : Named list. Reads
#                parameters$control$flex_up_max_power_heating.
#   asset      : Named list. The parameters of the building, its entry
#                of parameters$assets. Reads, from asset$model:
#                  - Q_hp_heat_1 (kW)
#                  - Q_hp_heat_2 (kW)
#                  - Q_hp_cool (kW)
# -------------------------------------------------------------
# Outputs
#   Numeric scalar. The bounding heat power, in kW.
# -------------------------------------------------------------
# Code outline
# 1. Check the system
# 2. Pick the rated capacity
# -------------------------------------------------------------
# Usage instructions
# P_max <- flex_up_power_limit("heat", parameters, asset)
# -------------------------------------------------------------

flex_up_power_limit <- function(hvac_up, parameters, asset) {

  # 1. Check the system
  # -------------------------------------------------------------
  {
    if (!hvac_up %in% c("heat", "cool")) {
      stop("flex_up_power_limit: hvac_up must be 'heat' or 'cool'")
    }
  }

  # 2. Pick the rated capacity
  # -------------------------------------------------------------
  {
    P_max <- if (hvac_up == "cool") {
      asset$model$Q_hp_cool
    } else if (identical(parameters$control$flex_up_max_power_heating,
                         "Q_hp_heat_1")) {
      asset$model$Q_hp_heat_1
    } else {
      asset$model$Q_hp_heat_2
    }
  }

  return(P_max)
}
