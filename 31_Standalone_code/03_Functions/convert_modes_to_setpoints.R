# -------------------------------------------------------------
# Function: convert_modes_to_setpoints.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# HVAC modes are used to define heating and cooling setpoints.
# This function performs a conversion from modes to setpoints: each
# market period carries exactly one mode, and its heating and cooling
# setpoints are read from the table of modes. Once the setpoints are
# defined, this function converts high-level setpoints to low-level
# setpoints with hysteresis deadbands.
# The output carries exactly one row per market period.
# It runs once per candidate of the genetic algorithm. The table of
# modes is checked once, when load_parameters() reads it (no missing
# values, modes numbered 1..n), so it is not checked again here.
# -------------------------------------------------------------
# Inputs
#   setpoint_modes_df : Data frame. Mode of each market period, as
#                       returned by maxmode(). Columns:
#                         period  – POSIXct. Market period timestamps.
#                         maxmode – Integer. Active mode index per period.
#   setpoint_modes    : Data frame. Lookup table mapping mode indices to
#                       heating and cooling setpoint values, as read by
#                       load_parameters(). Columns:
#                         mode    – Integer. Mode index.
#                         heating – Numeric. Heating setpoint (°C).
#                         cooling – Numeric. Cooling setpoint (°C).
#   Deadband          : Numeric scalar. Deadband width for the hysteresis
#                       thermostat. Applied symmetrically:
#                         STP_xxx_low  = STP_xxx - Deadband/2
#                         STP_xxx_high = STP_xxx + Deadband/2
#   target_periods    : POSIXct vector. Market period timestamps, in
#                       increasing order. The output carries one row per
#                       period.
# -------------------------------------------------------------
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
# 1. Mode of each target period
# 2. Look up setpoint values for each mode from setpoint_modes table
# 3. Apply deadband offsets
# -------------------------------------------------------------
# Usage instructions
# sp_df <- convert_modes_to_setpoints(setpoint_modes_df = maxmode_result,
#   setpoint_modes = parameters$setpoint_modes,
#   Deadband = parameters$control$Deadband,
#   target_periods = timestamps$target_periods)
# -------------------------------------------------------------
# Where this function/script is used
#   - fitness_funct_optimize_mode()
#   - optimize_modes()
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If there are fewer modes than periods, the function stops with an
#     error: every period needs a mode.
#   - If a requested mode does not exist in setpoint_modes, the function
#     stops with an error so the simulation does not continue with
#     missing setpoints.
#   - Deadband is applied symmetrically (see above).
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

convert_modes_to_setpoints <- function(setpoint_modes_df,
                                       setpoint_modes,
                                       Deadband,
                                       target_periods
                                       ) {

  # -------------------------------------------------------------
  # 1. Mode of each target period
  # -------------------------------------------------------------
  # The modes are taken in the order of their periods, one per target
  # period.
  # -------------------------------------------------------------
  {
    n_periods <- length(target_periods)

    if (nrow(setpoint_modes_df) < n_periods) {
      stop("convert_modes_to_setpoints() received ", nrow(setpoint_modes_df),
           " modes for ", n_periods, " periods")
    }

    mode_of_period <- setpoint_modes_df$maxmode[order(setpoint_modes_df$period)][seq_len(n_periods)]
  }

  # -------------------------------------------------------------
  # 2. Look up setpoint values for each mode
  # -------------------------------------------------------------
  {
    mode_row <- match(mode_of_period, setpoint_modes$mode)

    if (any(is.na(mode_row))) {
      stop("The following modes do not exist in setpoint_modes: ",
           paste(sort(unique(mode_of_period[is.na(mode_row)])), collapse = ", "))
    }

    df <- data.frame(
      period   = target_periods,
      STP_heat = setpoint_modes$heating[mode_row],
      STP_cool = setpoint_modes$cooling[mode_row]
    )

    rm(n_periods, mode_of_period, mode_row)
  }

  # -------------------------------------------------------------
  # 3. Apply deadbands
  # -------------------------------------------------------------
  {
    df$STP_heat_low  <- df$STP_heat - Deadband / 2
    df$STP_heat_high <- df$STP_heat + Deadband / 2
    df$STP_cool_low  <- df$STP_cool - Deadband / 2
    df$STP_cool_high <- df$STP_cool + Deadband / 2
  }

  return(df)
}
