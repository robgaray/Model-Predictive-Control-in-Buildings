# -------------------------------------------------------------
# Function: lowest_mode_setpoints.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Returns the setpoints of the lowest-numbered mode of
# 13_Modes_setpoints.csv. They are the setpoints of every row whose
# action no market has determined: a row takes the lowest-numbered
# mode until a market sets another one.
# The low and high setpoints of each system are half a deadband
# below and above its setpoint, the same rule
# convert_modes_to_setpoints() applies to every other mode.
# -------------------------------------------------------------
# Inputs
#   parameters : Named list. The parameters of the system. A building
#                does not read it: the signature is the one of the
#                operation default_control of the contract of the
#                type of model.
#   asset      : Named list. The parameters of the building, its entry
#                of parameters$assets. Must contain:
#                  - setpoint_modes, the data frame with the columns
#                    mode, heating and cooling [degC]
#                  - control$Deadband, the width of the hysteresis
#                    band [degC]
# -------------------------------------------------------------
# Outputs
#   Named list of six numbers [degC]:
#     - STP_heat, STP_heat_low, STP_heat_high
#     - STP_cool, STP_cool_low, STP_cool_high
# -------------------------------------------------------------
# Code outline
# 1. Check the inputs
# 2. Setpoints of the lowest-numbered mode
# -------------------------------------------------------------
# Usage instructions
# fill <- lowest_mode_setpoints(parameters, asset)
# -------------------------------------------------------------
lowest_mode_setpoints <- function(parameters, asset) {

  # -------------------------------------------------------------
  # 1. Check the inputs
  # -------------------------------------------------------------
  {
    modes <- asset$setpoint_modes
    if (is.null(modes) || nrow(modes) == 0) {
      stop("lowest_mode_setpoints: asset$setpoint_modes holds no mode")
    }
    if (!all(c("mode", "heating", "cooling") %in% names(modes))) {
      stop("lowest_mode_setpoints: asset$setpoint_modes needs the ",
           "columns mode, heating and cooling")
    }
    if (is.null(asset$control$Deadband)) {
      stop("lowest_mode_setpoints: asset$control$Deadband was not found")
    }
  }

  # -------------------------------------------------------------
  # 2. Setpoints of the lowest-numbered mode
  # -------------------------------------------------------------
  {
    lowest    <- modes[which.min(as.numeric(modes$mode)), ]
    heating   <- as.numeric(lowest$heating)
    cooling   <- as.numeric(lowest$cooling)
    half_band <- asset$control$Deadband / 2

    setpoints <- list(
      STP_heat      = heating,
      STP_heat_low  = heating - half_band,
      STP_heat_high = heating + half_band,
      STP_cool      = cooling,
      STP_cool_low  = cooling - half_band,
      STP_cool_high = cooling + half_band
    )
  }

  rm(list = c("modes", "lowest", "heating", "cooling", "half_band"))

  return(setpoints)
}
