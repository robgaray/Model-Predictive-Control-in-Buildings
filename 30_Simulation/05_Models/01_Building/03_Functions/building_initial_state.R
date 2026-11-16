# -------------------------------------------------------------
# Function: building_initial_state.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation initial_state of the type of model Building: writes
# the initial condition of a building into row 1 of its table.
# Row 1 is the only true initial condition of the whole run: the
# simulation loop never recomputes it, in any context. The four
# contexts (exec, plan, plan_flex_down and plan_flex_up) are
# therefore seeded with the same state, so that none of them
# starts from a different building than the others.
# Ti_0 and Te_0 are temperatures (degC) and go in as they are.
# Qh_0 and Qc_0 are powers (kW), while the Q_heat_* and Q_cool_*
# columns hold the energy of the step (kWh), so they are
# multiplied by the first timestep, in hours. The C++ engine reads
# this row as Q_heat_prev and divides it by that same timestep to
# recover the power for the inertial term, so the round trip
# returns exactly Qh_0 and Qc_0 in kW.
# -------------------------------------------------------------
# Inputs
#   asset_df    : data.table. The table of the building, with the
#                 columns Ti_*, Te_*, Q_heat_* and Q_cool_* of the
#                 four contexts. It is changed by reference.
#   asset       : Named list. The parameters of the building, its
#                 entry of parameters$assets. asset$model holds
#                 Ti_0, Te_0, Qh_0 and Qc_0.
#   delta_t_h   : Numeric scalar. The first timestep of the
#                 simulation, in hours.
# -------------------------------------------------------------
# Outputs
#   data.table. The table of the building with its row 1 written.
# -------------------------------------------------------------
# Code outline
# 1. Write the initial state of each context into row 1
# -------------------------------------------------------------
# Usage instructions
# asset_df <- building_initial_state(asset_df, asset, delta_t_h)
# -------------------------------------------------------------

building_initial_state <- function(asset_df,
                                   asset,
                                   delta_t_h
                                   ) {

  # -------------------------------------------------------------
  # 1. Write the initial state of each context into row 1
  # -------------------------------------------------------------
  {
    model_parameters <- asset$model

    for (CONT_001 in c("exec", "plan", "plan_flex_down", "plan_flex_up")) {
      set(asset_df,
          i     = 1L,
          j     = paste0("Ti_", CONT_001),
          value = model_parameters$Ti_0)
      set(asset_df,
          i     = 1L,
          j     = paste0("Te_", CONT_001),
          value = model_parameters$Te_0)
      set(asset_df,
          i     = 1L,
          j     = paste0("Q_heat_", CONT_001),
          value = model_parameters$Qh_0 * delta_t_h)
      set(asset_df,
          i     = 1L,
          j     = paste0("Q_cool_", CONT_001),
          value = model_parameters$Qc_0 * delta_t_h)
    }
    rm(list = c("model_parameters", "CONT_001"))
  }

  return(asset_df)
}
