# -------------------------------------------------------------
# Function: heat_pump_cop.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Returns the heating COP of the heat pump at each outdoor
# temperature. The COP is referred to a rating point: it equals
# COP_hp_heat_1_coef1 at the reference outdoor temperature and supply
# temperature, and moves linearly with each of them. It is never
# below 1: where the line falls below 1, the COP is 1.
# The COP is not computed in R. It is computed by heat_pump_cop_cpp(),
# the compiled function the period simulation uses too, so that the
# simulation and the R code share one electrical model and get the
# same values. This function only reads the parameters it needs from
# the parameters of the building and passes them on.
# It is kept apart from heat_pump_electricity() so that a caller that
# evaluates the electricity several times over the same rows computes
# the COP only once.
# -------------------------------------------------------------
# Inputs
#   Text       : Numeric vector. Outdoor temperature, in degC.
#   asset      : Named list. The parameters of the building, its entry
#                of parameters$assets. Reads, from asset$model:
#                  - COP_hp_heat_1_coef1
#                  - COP_hp_heat_1_coef2
#                  - COP_hp_heat_1_coef3
#                  - Text_ref_hp_heat (degC)
#                  - Tsup_hp_heat (degC)
#                  - Tsup_ref_hp_heat (degC)
# -------------------------------------------------------------
# Outputs
#   Numeric vector, the length of Text. The heating COP at each
#   outdoor temperature, never below 1.
# -------------------------------------------------------------
# Code outline
# 1. The COP at each outdoor temperature
# -------------------------------------------------------------
# Usage instructions
# Needs period_simulation_cpp.cpp compiled with Rcpp::sourceCpp(),
# which exports heat_pump_cop_cpp().
# cop_heat <- heat_pump_cop(Text, asset)
# -------------------------------------------------------------

heat_pump_cop <- function(Text, asset) {

  # -------------------------------------------------------------
  # 1. The COP at each outdoor temperature
  # -------------------------------------------------------------
  {
    model <- asset$model

    # heat_pump_cop_cpp is called to evaluate the COP with the compiled
    # electrical model of the period simulation.
    cop_heat <- heat_pump_cop_cpp(
      Text                = Text,
      COP_hp_heat_1_coef1 = model$COP_hp_heat_1_coef1,
      COP_hp_heat_1_coef2 = model$COP_hp_heat_1_coef2,
      COP_hp_heat_1_coef3 = model$COP_hp_heat_1_coef3,
      Tsup_hp_heat        = model$Tsup_hp_heat,
      Text_ref_hp_heat    = model$Text_ref_hp_heat,
      Tsup_ref_hp_heat    = model$Tsup_ref_hp_heat
    )

    rm(list = "model")
  }

  return(cop_heat)
}
