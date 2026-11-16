# -------------------------------------------------------------
# Function: heat_pump_electricity.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Returns the electricity the HVAC systems draw, step by step, for a
# given heating and cooling energy, so that the flexibility builders
# can bound an itinerary in electricity without running the
# simulation:
#   - the heat pump covers the heating up to its first rated point,
#     Q_hp_heat_1, at the COP of the moment (heat_pump_cop());
#   - the backup resistances cover the rest of the heating, at COP 1;
#   - cooling has a single constant COP.
# The electricity is not computed in R. It is computed by
# heat_pump_electricity_cpp(), with the same compiled expression the
# period simulation evaluates at every step, so that the simulation
# and the R code share one electrical model and get the same values.
# This function only reads the parameters it needs from the
# parameters of the building and passes them on.
# -------------------------------------------------------------
# Inputs
# All the vectors are the same length, one entry per time step.
#   Q_heat     : Numeric vector. Heating energy of each step, in kWh.
#   Q_cool     : Numeric vector. Cooling energy of each step, in kWh.
#   cop_heat   : Numeric vector. Heating COP of each step, as
#                heat_pump_cop() returns it.
#   delta_t_h  : Numeric vector. Length of each step, in hours.
#   asset      : Named list. The parameters of the building, its entry
#                of parameters$assets. Reads, from asset$model:
#                  - Q_hp_heat_1 (kW)
#                  - COP_hp_cool
# -------------------------------------------------------------
# Outputs
#   Numeric vector, the length of the inputs. The electricity of each
#   step, in kWh.
# -------------------------------------------------------------
# Code outline
# 1. The electricity of each step
# -------------------------------------------------------------
# Usage instructions
# Needs period_simulation_cpp.cpp compiled with Rcpp::sourceCpp(),
# which exports heat_pump_electricity_cpp().
# elec <- heat_pump_electricity(Q_heat, Q_cool,
#                               heat_pump_cop(Text, asset),
#                               delta_t_h, asset)
# -------------------------------------------------------------

heat_pump_electricity <- function(Q_heat, Q_cool, cop_heat, delta_t_h, asset) {

  # -------------------------------------------------------------
  # 1. The electricity of each step
  # -------------------------------------------------------------
  {
    # heat_pump_electricity_cpp is called to evaluate the electricity
    # with the compiled electrical model of the period simulation.
    electricity <- heat_pump_electricity_cpp(
      Q_heat      = Q_heat,
      Q_cool      = Q_cool,
      COP_heat    = cop_heat,
      delta_t_h   = delta_t_h,
      Q_hp_heat_1 = asset$model$Q_hp_heat_1,
      COP_hp_cool = asset$model$COP_hp_cool
    )
  }

  return(electricity)
}
