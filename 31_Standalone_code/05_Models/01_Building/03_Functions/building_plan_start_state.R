# -------------------------------------------------------------
# Function: building_plan_start_state.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation plan_start_state of the type of model Building: starts
# the plan of the building from the state it has at i0. Row 1 of the
# chunk is i0, the row the market clears on. The state of the
# building at i0 (Ti, Te) is the one of the plan the call received.
# The three itineraries start from it: the plan and the two
# flexibility itineraries, which are copies of the plan.
# The state of the heating and cooling systems is not part of the
# input. It is deduced from the indoor temperature and the setpoints
# of row 1, with the hysteresis of the thermostat:
#   - heating is on when Ti is below the lower threshold of the
#     heating setpoint
#   - cooling is on when Ti is above the upper threshold of the
#     cooling setpoint and heating is off
# That state is both the activation of row 1 and the state of the
# thermostats the hysteresis of row 2 starts from.
# The power of the heat pump in the step before i0 is 0.
# Every type of model receives asset, its parameters, as every
# operation of the contract does (model_type_contract()). The
# building does not read it.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. The view of the building over the
#                  period of the market, with Ti_plan, Te_plan and
#                  the setpoints of row 1 of the plan filled
#                  (STP_heat_low_plan and STP_cool_high_plan).
#   asset        : Named list. The parameters of the building, its
#                  entry of parameters$assets. Not read.
# -------------------------------------------------------------
# Outputs
#   Data frame. The chunk with row 1 of Ti, Te, Act_heat, Act_cool,
#   Thermostat_heat and Thermostat_cool filled in the three
#   itineraries.
# -------------------------------------------------------------
# Code outline
# 1. State of the plan at i0
# 2. Copy it into the three itineraries
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- building_plan_start_state(period_chunk, asset)
# -------------------------------------------------------------

building_plan_start_state <- function(period_chunk,
                                      asset
                                      ) {

  # -------------------------------------------------------------
  # 1. State of the plan at i0
  # -------------------------------------------------------------
  {
    Ti_0    <- period_chunk$Ti_plan[1]
    Te_0    <- period_chunk$Te_plan[1]
    heat_on <- as.integer(Ti_0 < period_chunk$STP_heat_low_plan[1])
    cool_on <- as.integer(Ti_0 > period_chunk$STP_cool_high_plan[1] &
                            heat_on == 0L)
  }

  # -------------------------------------------------------------
  # 2. Copy it into the three itineraries
  # -------------------------------------------------------------
  {
    for (CONT_001 in c("plan", "plan_flex_down", "plan_flex_up")) {
      period_chunk[[paste0("Ti_", CONT_001)]][1]              <- Ti_0
      period_chunk[[paste0("Te_", CONT_001)]][1]              <- Te_0
      period_chunk[[paste0("Act_heat_", CONT_001)]][1]        <- heat_on
      period_chunk[[paste0("Act_cool_", CONT_001)]][1]        <- cool_on
      period_chunk[[paste0("Thermostat_heat_", CONT_001)]][1] <- heat_on
      period_chunk[[paste0("Thermostat_cool_", CONT_001)]][1] <- cool_on
    }
    rm(list = c("CONT_001", "Ti_0", "Te_0", "heat_on", "cool_on"))
  }

  return(period_chunk)
}
