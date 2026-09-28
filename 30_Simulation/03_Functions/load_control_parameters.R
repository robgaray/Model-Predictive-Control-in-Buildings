# -------------------------------------------------------------
# Function: load_control_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Structures the control parameters that apply whatever control_type
# is chosen, as read and validated from 02_Control.csv, into the
# first part of parameters$control. control_type is kept as text
# ("modes" or "setpoints"); every other value is converted to a
# number.
# -------------------------------------------------------------
# Inputs
#   values : Named list. Raw parameter/value pairs of 02_Control.csv,
#            as returned by read_and_validate_parameter_csv():
#              - control_type : "modes" or "setpoints"
#              - Deadband : width of the hysteresis band [degC]
#              - set_point_default_heating : heating setpoint when no
#                market has set one [degC]
#              - set_point_default_cooling : cooling setpoint when no
#                market has set one [degC]
#              - pad_heating : heating setpoint beyond the optimized
#                horizon [degC]
#              - pad_cooling : cooling setpoint beyond the optimized
#                horizon [degC]
# -------------------------------------------------------------
# Outputs
#   Named list with the same six elements, control_type as text and
#   the rest as numbers.
# -------------------------------------------------------------
# Code outline
# 1. Keep control_type as text and convert the rest to numbers.
# -------------------------------------------------------------
# Usage instructions
# control <- load_control_parameters(raw_values)
# -------------------------------------------------------------
# Where this function/script is used
# Called by load_02_control.R.
# -------------------------------------------------------------
# functions/scripts called
# None.
# -------------------------------------------------------------

load_control_parameters <- function(values) {

  # -------------------------------------------------------------
  # 1. Keep control_type as text and convert the rest to numbers
  # -------------------------------------------------------------
  {
    control <- list(
      control_type              = trimws(as.character(values$control_type)),
      Deadband                  = as.numeric(values$Deadband),
      set_point_default_heating = as.numeric(values$set_point_default_heating),
      set_point_default_cooling = as.numeric(values$set_point_default_cooling),
      pad_heating               = as.numeric(values$pad_heating),
      pad_cooling               = as.numeric(values$pad_cooling)
    )
  }

  return(control)
}
