# -------------------------------------------------------------
# Function: convert_modes_to_setpoints.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# HVAC modes are used to define heating and cooling setpoints.
# This function performs a conversion from modes to setpoints.
# When more than one mode is active, the one with the highest value
# is selected. Once the setpoints are defined, this function converts
# high-level setpoints to low-level setpoints with hysteresis deadbands.
# Length correction is also performed.
# -------------------------------------------------------------
# Inputs
#   setpoint_modes_df : Data frame. Time series defining which mode 'maxmode'
#                       is active in each timestep. Must contain columns:
#                         period  – POSIXct. Market period timestamps.
#                         maxmode – Integer. Active mode index per period.
#   setpoint_modes    : Data frame. Lookup table mapping mode indices to
#                       heating and cooling setpoint values. Must contain:
#                         mode    – Integer. Mode index.
#                         heating – Numeric. Heating setpoint (°C).
#                         cooling – Numeric. Cooling setpoint (°C).
#   Deadband          : Numeric scalar. Deadband width for the hysteresis
#                       thermostat. Applied symmetrically:
#                         STP_xxx_low  = STP_xxx - Deadband/2
#                         STP_xxx_high = STP_xxx + Deadband/2
#   target_periods    : POSIXct vector. Market period timestamps for length
#                       correction. Not strictly required, but needed for
#                       index compatibility.
#   pad_mode          : Integer scalar. Padding mode index for periods beyond
#                       the input length. Default: 0.
#   pad_heating       : Numeric scalar. Padding heating setpoint. Default: 0.
#   pad_cooling       : Numeric scalar. Padding cooling setpoint. Default: 50.
#
# Outputs
#   Data frame (df) with columns:
#     period        – POSIXct. Market period timestamps.
#     mode          – Integer. Active mode index per period.
#     STP_heat      – Numeric. Heating setpoint.
#     STP_cool      – Numeric. Cooling setpoint.
#     STP_heat_low  – Numeric. Heating activation threshold (lower).
#     STP_heat_high – Numeric. Heating deactivation threshold (upper).
#     STP_cool_low  – Numeric. Cooling activation threshold (lower).
#     STP_cool_high – Numeric. Cooling deactivation threshold (upper).
# -------------------------------------------------------------
# Code outline
# 1. Look up setpoint values for each mode from setpoint_modes table
# 2. Apply deadband offsets
# 3. Build output data frame with per-period setpoints
# -------------------------------------------------------------
# Usage instructions
# sp_df <- convert_modes_to_setpoints(maxmode_result, parameters, target_periods)
# -------------------------------------------------------------
# Where this function/script is used
# Called by fitness_funct_optimize_mode.R and optimize_modes.R.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If target_periods is NULL, the output data frame is built directly from
#     the merged result without length adjustment.
#   - If n_setpoints >= n_periods, the output is trimmed to n_periods rows.
#   - If n_setpoints < n_periods, the output is padded using pad_mode,
#     pad_heating, and pad_cooling for the missing timesteps.
#   - Deadband is applied symmetrically (see above).
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

convert_modes_to_setpoints <- function(setpoint_modes_df,
                                       setpoint_modes,
                                       Deadband,
                                       target_periods = NULL,
                                       pad_mode = 0,
                                       pad_heating = 0,
                                       pad_cooling = 50
                                       ) {
  
  # Merge dataframes with modes and setpoints
  df <- merge(setpoint_modes_df,
              setpoint_modes,
              by.x = "maxmode",
              by.y = "mode",
              all.x = TRUE
              )
  
  # Rename columns
  {
    colnames(df)[colnames(df) == "heating"] <- "STP_heat"
    colnames(df)[colnames(df) == "cooling"] <- "STP_cool"
  }
  
  # Adapt for length of output data frame
  if (!is.null(target_periods)) {
    
    n_periods     <- length(target_periods)
    n_setpoints   <- nrow(df)
    
    out <- data.frame(period = target_periods)
    
    if (n_setpoints >= n_periods) {
      # Output data frame is shorter or equal to input data frame
      out$mode     <- df$maxmode[1:n_periods]
      out$STP_heat <- df$STP_heat[1:n_periods]
      out$STP_cool <- df$STP_cool[1:n_periods]
    } else {
      # Output data frame is longer than input data frame
      out$mode     <- c(df$maxmode,    rep(pad_mode,    n_periods - n_setpoints))
      out$STP_heat <- c(df$STP_heat,   rep(pad_heating, n_periods - n_setpoints))
      out$STP_cool <- c(df$STP_cool,   rep(pad_cooling, n_periods - n_setpoints))
    }
    
    df <- out
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
