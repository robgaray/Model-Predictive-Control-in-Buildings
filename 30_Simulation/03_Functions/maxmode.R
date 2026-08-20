# -------------------------------------------------------------
# Function: maxmode.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function processes an integer mode vector (one mode index per
# market period) and pairs it with the corresponding timestamps to
# create a structured data frame.
# -------------------------------------------------------------
# Inputs
#   x              : Integer vector of length n_periods. Each element is
#                    a mode index (integer value from 1 to n_modes)
#                    representing the active mode for that market period.
#   n_modes        : Integer scalar. Number of available control modes
#                    (kept for interface compatibility, not used).
#   n_periods      : Integer scalar. Number of market periods in the
#                    optimization horizon (kept for interface compatibility,
#                    derived from length(x) and length(target_periods)).
#   target_periods : POSIXct vector. Market period timestamps used to
#                    index the output data frame.
#
# Outputs
#   Data frame with two columns:
#     period  – POSIXct. Market period timestamps (equal to target_periods).
#     maxmode – Integer. Mode index for each period (from input vector x).
# -------------------------------------------------------------
# Code outline
# 1. Create data frame pairing periods with mode indices
# -------------------------------------------------------------
# Usage instructions
# result <- maxmode(x, n_modes, n_periods, target_periods)
# -------------------------------------------------------------
# Where this function/script is used
# Called by optimize_modes.R (to pair the best GA solution with
# target_periods) and by fitness_funct_optimize_mode.R (to pair each
# candidate chromosome with target_periods before conversion to
# setpoints).
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - n_modes and n_periods are kept as parameters for interface compatibility
#     but are not used in the function body.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
maxmode <- function(x, n_modes, n_periods, target_periods) {

  # Create data frame with period and mode index
  {
    set_point_df_inner <- data.frame(
      period  = target_periods,
      maxmode = as.integer(x)
    )
  }

  return(set_point_df_inner)
}
