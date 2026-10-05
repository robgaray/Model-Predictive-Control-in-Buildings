# -------------------------------------------------------------
# Function: maxmode.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function processes an integer mode vector (one mode index per
# market period) and pairs it with the corresponding timestamps to
# create a structured data frame.
# -------------------------------------------------------------
# Inputs
#   x              : Integer vector, one element per market period.
#                    Each element is a mode index representing the
#                    active mode for that market period.
#   target_periods : POSIXct vector, same length as x. Market period
#                    timestamps used to index the output data frame.
# -------------------------------------------------------------
# Outputs
#   Data frame with two columns:
#     period  – POSIXct. Market period timestamps (equal to target_periods).
#     maxmode – Integer. Mode index for each period (from input vector x).
# -------------------------------------------------------------
# Code outline
# 1. Create data frame pairing periods with mode indices
# -------------------------------------------------------------
# Usage instructions
# result <- maxmode(x, target_periods)
# -------------------------------------------------------------
# Where this function/script is used
#   - fitness_funct_optimize_mode()
#   - optimize_modes()
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
maxmode <- function(x,
                    target_periods
                    ) {

  # -------------------------------------------------------------
  # 1. Create data frame pairing periods with mode indices
  # -------------------------------------------------------------
  {
    set_point_df_inner <- data.frame(
      period  = target_periods,
      maxmode = as.integer(x)
    )
  }

  return(set_point_df_inner)
}
