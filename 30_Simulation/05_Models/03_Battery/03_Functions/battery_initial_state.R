# -------------------------------------------------------------
# Function: battery_initial_state.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation initial_state of the type of model Battery: writes the
# energy the battery stores at the start of the simulation into row 1
# of its table. Row 1 is the only true initial condition of the whole
# run: the simulation loop never recomputes it, in any context. The
# four contexts (exec, plan, plan_flex_down and plan_flex_up) are
# seeded with the same energy, SOC_initial * Capacity (kWh).
# -------------------------------------------------------------
# Inputs
#   asset_df  : data.table. The table of the battery, with the
#               columns Stored_energy_* of the four contexts. It is
#               changed by reference.
#   asset     : Named list. The parameters of the battery, its entry
#               of parameters$assets. asset$battery holds
#               SOC_initial and Capacity.
#   delta_t_h : Numeric scalar. The first timestep of the
#               simulation, in hours. Not read.
# -------------------------------------------------------------
# Outputs
#   data.table. The table of the battery with its row 1 written.
# -------------------------------------------------------------
# Code outline
# 1. Write the initial energy of each context into row 1
# -------------------------------------------------------------
# Usage instructions
# asset_df <- battery_initial_state(asset_df, asset, delta_t_h)
# -------------------------------------------------------------

battery_initial_state <- function(asset_df,
                                  asset,
                                  delta_t_h
                                  ) {

  # -------------------------------------------------------------
  # 1. Write the initial energy of each context into row 1
  # -------------------------------------------------------------
  {
    battery <- asset$battery

    for (CONT_001 in c("exec", "plan", "plan_flex_down", "plan_flex_up")) {
      set(asset_df,
          i     = 1L,
          j     = paste0("Stored_energy_", CONT_001),
          value = battery$SOC_initial * battery$Capacity)
    }
    rm(list = c("battery", "CONT_001"))
  }

  return(asset_df)
}
