# -------------------------------------------------------------
# Function: convert_setpoints.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function converts high-level setpoints to low-level setpoints
# with hysteresis deadbands. Length correction is also performed.
# -------------------------------------------------------------
# Inputs
#   setpoints_heating : Numeric vector. Heating setpoints for each period.
#   setpoints_cooling : Numeric vector. Cooling setpoints for each period.
#   Deadband          : Numeric scalar. Deadband width for the hysteresis
#                       thermostat. Default: 1. Applied symmetrically:
#                         STP_xxx_low  = STP_xxx - Deadband/2
#                         STP_xxx_high = STP_xxx + Deadband/2
#   target_periods    : POSIXct vector. Market period timestamps used to
#                       define the output length. Not strictly required,
#                       but needed for index compatibility.
#   pad_heating       : Numeric scalar. Padding value applied to heating
#                       setpoints for periods beyond the input length.
#                       Default: 0.
#   pad_cooling       : Numeric scalar. Padding value applied to cooling
#                       setpoints for periods beyond the input length.
#                       Default: 50.
#
# Outputs
#   Data frame (df) with columns:
#     period        – POSIXct. Market period timestamps.
#     STP_heat      – Numeric. Heating setpoint.
#     STP_cool      – Numeric. Cooling setpoint.
#     STP_heat_low  – Numeric. Heating activation threshold (lower).
#     STP_heat_high – Numeric. Heating deactivation threshold (upper).
#     STP_cool_low  – Numeric. Cooling activation threshold (lower).
#     STP_cool_high – Numeric. Cooling deactivation threshold (upper).
# -------------------------------------------------------------
# Code outline
# 1. Generate setpoint schedule from heating/cooling temperature vectors
# 2. Align with market period timestamps
# 3. Return data frame with period and setpoint columns
# -------------------------------------------------------------
# Usage instructions
# sp_df <- convert_setpoints(setpoints_heating = heat_set,
#   setpoints_cooling = cool_set,
#   Deadband = parameters$control$Deadband,
#   target_periods = timestamps$target_periods)
# -------------------------------------------------------------
# Where this function/script is used
# Called by fitness_funct_optimize_setpoint.R and optimize_setpoints.R.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If n_setpoints >= n_hours, the heating and cooling vectors are trimmed
#     to the first n_hours values.
#   - If n_setpoints < n_hours, the heating and cooling vectors are padded
#     using pad_heating and pad_cooling respectively for the missing periods.
#   - If target_periods is NULL, n_hours will be 0 and the output data frame
#     will have no rows; callers should ensure target_periods is provided.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
convert_setpoints <- function(setpoints_heating,
                              setpoints_cooling,
                              Deadband = 1,
                              target_periods = NULL,
                              pad_heating = 0,
                              pad_cooling = 50
                              ) {
  
  # Adapt for length of output data frame
  n_hours     <- length(target_periods)
  n_setpoints <- length(setpoints_heating)
  
  df <- data.frame(period = target_periods)
  
  if (n_setpoints >= n_hours) {
    df$STP_heat <- setpoints_heating[1:n_hours]
    df$STP_cool <- setpoints_cooling[1:n_hours]
  } else {
    df$STP_heat <- c(setpoints_heating,
                              rep(pad_heating, n_hours - n_setpoints))
    df$STP_cool <- c(setpoints_cooling,
                              rep(pad_cooling, n_hours - n_setpoints))
  }
  
  # Apply deadbands
  {
    df$STP_heat_low  <- df$STP_heat - Deadband / 2
    df$STP_heat_high <- df$STP_heat + Deadband / 2
    df$STP_cool_low  <- df$STP_cool - Deadband / 2
    df$STP_cool_high <- df$STP_cool + Deadband / 2
  }
  
  return(df)
}
