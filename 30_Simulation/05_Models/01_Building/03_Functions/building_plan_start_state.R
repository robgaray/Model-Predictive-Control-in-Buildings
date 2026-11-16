# -------------------------------------------------------------
# Function: building_plan_start_state.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation plan_start_state of the type of model Building: starts
# the plan of the building from the state it has actually reached.
# Row 1 of the chunk is i0, the row the market clears on. The
# execution step of the row before has already written the state the
# building reached there, under the real weather. The plan of the
# market starts from that state, and not from the one an earlier
# market planned for i0, so the forecast errors those markets made do
# not carry over: from i0 on, the plan only follows the forecast of
# this market. The flexibility itineraries are copies of the plan, so
# they start from the same state.
# The state is the two temperatures and what the two systems did in
# the step that ends at i0: their activation, the state of their
# thermostats and their heat. The heat
# is part of the state because a fraction inertial_fact of it reaches
# the indoor air in the first step of the plan, so the plan starts
# from the heat that was executed, not from the one an earlier market
# planned.
# Every type of model receives asset, its parameters, as every
# operation of the contract does (model_type_contract()). The
# building does not read it.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. The view of the building over the
#                  period of a market, with the columns Ti_exec,
#                  Te_exec, Act_heat_exec, Act_cool_exec,
#                  Thermostat_heat_exec, Thermostat_cool_exec,
#                  Q_heat_exec and Q_cool_exec, and their _plan
#                  columns.
#   asset        : Named list. The parameters of the building, its
#                  entry of parameters$assets. Not read.
# -------------------------------------------------------------
# Outputs
#   Data frame. The chunk with row 1 of Ti_plan, Te_plan,
#   Act_heat_plan, Act_cool_plan, Thermostat_heat_plan,
#   Thermostat_cool_plan, Q_heat_plan and Q_cool_plan equal to that of
#   their _exec column.
# -------------------------------------------------------------
# Code outline
# 1. Copy the executed state into row 1 of the plan
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- building_plan_start_state(period_chunk, asset)
# -------------------------------------------------------------

building_plan_start_state <- function(period_chunk,
                                      asset
                                      ) {

  # -------------------------------------------------------------
  # 1. Copy the executed state into row 1 of the plan
  # -------------------------------------------------------------
  {
    for (CONT_001 in c("Ti", "Te", "Act_heat", "Act_cool",
                       "Thermostat_heat", "Thermostat_cool",
                       "Q_heat", "Q_cool")) {
      period_chunk[[paste0(CONT_001, "_plan")]][1] <-
        period_chunk[[paste0(CONT_001, "_exec")]][1]
    }
    rm(list = "CONT_001")
  }

  return(period_chunk)
}
