# -------------------------------------------------------------
# Function: maxmode.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function processes a binary GA solution vector and, for each
# market period, selects the highest-indexed active control mode
# (the mode with the largest index where the binary gene equals 1).
# An error is flagged if any time step has more than one active mode
# or no active mode at all.
# -------------------------------------------------------------
# Inputs
#   x_bin          : Integer vector (0/1). Binary GA solution of length
#                    n_modes * n_periods. The first n_periods genes
#                    correspond to mode_1, the next n_periods to mode_2,
#                    and so on.
#   n_modes        : Integer scalar. Number of available control modes.
#   n_periods      : Integer scalar. Number of market periods in the
#                    optimization horizon.
#   target_periods : POSIXct vector. Market period timestamps used to
#                    index the output data frame.
#
# Outputs
#   A named list with two elements:
#     set_point_df_inner : Data frame with two columns:
#                            period  – POSIXct. Market period timestamps
#                                      (equal to target_periods).
#                            maxmode – Integer. Highest active mode index
#                                      for each period.
#     error              : Logical scalar. TRUE if any time step has more
#                          than one active mode or no active mode.
# -------------------------------------------------------------
# Code outline
# 1. Build data frame with one column per mode
# 2. Identify active modes per time step
# 3. Select highest-indexed active mode
# 4. Flag errors for invalid mode combinations
# -------------------------------------------------------------
# Usage instructions
# result <- maxmode(x_bin, n_modes, n_periods, target_periods)
# -------------------------------------------------------------
# Where this function/script is used
# Called by optimize_modes.R and fitness_funct_optimize_mode.R
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - error is TRUE when any row has more than one mode active (sum > 1)
#     or no mode active (sum == 0).
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
maxmode <- function(x_bin, n_modes, n_periods, target_periods) {

  # Build a data frame with one column per mode
  set_point_df_inner <- data.frame(period = target_periods)
  for (CONT_001 in seq_len(n_modes)) {
    set_point_df_inner[[paste0("mode_", CONT_001)]] <-
      x_bin[((CONT_001 - 1) * n_periods + 1):(CONT_001 * n_periods)]
  }

  # Identify the mode columns
  cols_modes <- grep("^mode_", names(set_point_df_inner), value = TRUE)

  # Extract the numeric index from each mode column name
  indices_modes <- as.numeric(sub("mode_", "", cols_modes))

  # Logical matrix: TRUE where binary gene equals 1
  logical_matrix <- set_point_df_inner[cols_modes] == 1

  # Count active modes per row
  active_counts <- rowSums(logical_matrix)

  # Error: any time step with more than one active mode or no active mode
  error <- any(active_counts > 1) || any(active_counts == 0)

  # Multiply each column by its mode index: active genes keep their index, inactive get 0
  value_matrix <- sweep(logical_matrix, MARGIN = 2, STATS = indices_modes, FUN = "*")

  # Select the maximum mode index per row
  maxmode_vec <- apply(value_matrix, MARGIN = 1, FUN = max)

  # Replace zero values with 1 (default fall-back when no mode is active)
  maxmode_vec[maxmode_vec == 0] <- 1

  # Build the output data frame
  set_point_df_inner <- data.frame(
    period  = set_point_df_inner$period,
    maxmode = maxmode_vec
  )

  return(list(set_point_df_inner = set_point_df_inner, error = error))
}