# -------------------------------------------------------------
# Function: to_local_indexes.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Converts the global indexes of a period (rows of the full
# Main_df) into local indexes (rows of the piece of Main_df cut
# for that period). The local index of the first row of the period
# is 1, and every other index keeps its distance to that row.
# -------------------------------------------------------------
# Inputs
# indexes_global: list, simulation_control$indexes_global, with
# these elements already filled for the period:
#   - i0
#   - i_begin_horizon
#   - i_end_horizon
#   - i_end_control
#   - idx_period
#   - idx_horizon
#   - idx_ctrl
# -------------------------------------------------------------
# Outputs
# Named list with the local version of the indexes:
#   - i0
#   - i_begin_horizon
#   - i_end_horizon
#   - i_end_control
#   - idx_period
#   - idx_horizon
#   - idx_ctrl
#   - i_flex
# -------------------------------------------------------------
# Code outline
# 1. Set the local index of the first row of the period
# 2. Shift every global index by the first row of the period
# 3. Return the local indexes
# -------------------------------------------------------------
# Usage instructions
# local_indexes <- to_local_indexes(
#   indexes_global = simulation_control$indexes_global
# )
# simulation_control$indexes_local[names(local_indexes)] <-
#   local_indexes
# -------------------------------------------------------------

to_local_indexes <- function(indexes_global) {

  # -----------------------------------------------------------
  # 1. First row of the period
  # The first row of the period is row 1 of the local piece.
  # -----------------------------------------------------------
  {
    local_i0 <- 1
  }

  # -----------------------------------------------------------
  # 2. Shift
  # Every global index is moved by the same amount, so that
  # i0 lands on local_i0.
  # -----------------------------------------------------------
  {
    indexes_local <- list(
      i0              = local_i0,
      i_begin_horizon = indexes_global$i_begin_horizon - indexes_global$i0 + local_i0,
      i_end_horizon   = indexes_global$i_end_horizon   - indexes_global$i0 + local_i0,
      i_end_control   = indexes_global$i_end_control   - indexes_global$i0 + local_i0,
      idx_period      = indexes_global$idx_period      - indexes_global$i0 + local_i0,
      idx_horizon     = indexes_global$idx_horizon     - indexes_global$i0 + local_i0,
      idx_ctrl        = indexes_global$idx_ctrl        - indexes_global$i0 + local_i0,
      i_flex          = local_i0
    )
  }

  # -----------------------------------------------------------
  # 3. Return
  # -----------------------------------------------------------
  return(indexes_local)
}
