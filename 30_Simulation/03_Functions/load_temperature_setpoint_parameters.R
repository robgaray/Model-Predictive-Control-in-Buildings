# -------------------------------------------------------------
# Function: load_temperature_setpoint_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Structures the temperature setpoint parameters, as read and validated
# from 12_Temperature_Setpoints.csv, into the ranges the optimizer
# may choose each setpoint from. They are only used when control_type
# is setpoints; they are loaded whatever the control_type, so that a
# run can switch type without a missing parameter.
# -------------------------------------------------------------
# Inputs
#   values : Named list. Raw parameter/value pairs of
#            12_Temperature_Setpoints.csv:
#              - set_point_range_heating_low [degC]
#              - set_point_range_heating_high [degC]
#              - set_point_range_cooling_low [degC]
#              - set_point_range_cooling_high [degC]
# -------------------------------------------------------------
# Outputs
#   Named list:
#     - set_point_range_heating : numeric [low, high] [degC]
#     - set_point_range_cooling : numeric [low, high] [degC]
# -------------------------------------------------------------
# Code outline
# 1. Pair each low and high bound into a range.
# -------------------------------------------------------------
# Usage instructions
# ranges <- load_temperature_setpoint_parameters(raw_values)
# -------------------------------------------------------------
# Where this function/script is used
# Called by load_12_temperature_setpoints.R.
# -------------------------------------------------------------
# functions/scripts called
# None.
# -------------------------------------------------------------

load_temperature_setpoint_parameters <- function(values) {

  # -------------------------------------------------------------
  # 1. Pair each low and high bound into a range
  # -------------------------------------------------------------
  {
    setpoints <- list(
      set_point_range_heating = c(as.numeric(values$set_point_range_heating_low),
                                  as.numeric(values$set_point_range_heating_high)),
      set_point_range_cooling = c(as.numeric(values$set_point_range_cooling_low),
                                  as.numeric(values$set_point_range_cooling_high))
    )
  }

  return(setpoints)
}
