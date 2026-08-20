# -------------------------------------------------------------
# Function: reset_index_list.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Returns a zeroed index list, matching the fields of
# simulation_control$indexes_global / simulation_control$indexes_local
# that must be reset after each market process (Scheduling, Piloting,
# Execution) in the main simulation loop.
# -------------------------------------------------------------
# Inputs
# (none)
# -------------------------------------------------------------
# Outputs
# Named list with i0, i1, i_begin_horizon, i_end_horizon,
# i_end_control, idx_period, idx_horizon, idx_ctrl, i_flex, all set
# to 0.
# -------------------------------------------------------------
# Code outline
# 1. Build and return the zeroed index list
# -------------------------------------------------------------
# Usage instructions
# simulation_control$indexes_global[names(reset_index_list())] <- reset_index_list()
# simulation_control$indexes_local[names(reset_index_list())]  <- reset_index_list()
# -------------------------------------------------------------
# Where this function/script is used
# Called by simulation.R after the Scheduling, Piloting and Execution
# processes of each simulation step.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - indexes_global and indexes_local also hold an n_steps field that
#     must persist across the whole simulation loop. The partial,
#     named-subset assignment shown above updates only the 9 fields
#     returned by this function, leaving n_steps (and any other field
#     not covered here) untouched. A full-list replacement
#     (simulation_control$indexes_global <- reset_index_list()) would
#     instead wipe out n_steps and must not be used.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

reset_index_list <- function() {
  list(
    i0              = 0,
    i1              = 0,
    i_begin_horizon = 0,
    i_end_horizon   = 0,
    i_end_control   = 0,
    idx_period      = 0,
    idx_horizon     = 0,
    idx_ctrl        = 0,
    i_flex          = 0
  )
}
