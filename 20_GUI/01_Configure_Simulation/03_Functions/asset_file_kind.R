# -------------------------------------------------------------
# Function: asset_file_kind.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Tells how the GUI edits a file of an asset, from its key in
# 04_File_paths.csv:
#   - modes: the key setpoint_mode_file, a block of parameters above
#     a table of modes.
#   - occupancy: the key use_patterns_file, two tables of occupancy
#     profiles.
#   - flat: any other key, a file of parameter,value,unit rows.
# A type of model whose files are all flat needs no code of its own
# in the GUI.
# -------------------------------------------------------------
# Inputs
#   keys : Character vector. The keys of the files of an asset.
# -------------------------------------------------------------
# Outputs
#   Character vector of the same length, with modes, occupancy or
#   flat for each key.
# -------------------------------------------------------------
# Code outline
# 1. Classify each key.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   asset_file_kind(keys)
# -------------------------------------------------------------

asset_file_kind <- function(keys) {

  # -------------------------------------------------------------
  # 1. Classify each key
  # -------------------------------------------------------------
  {
    kinds <- rep("flat", length(keys))
    kinds[keys == "setpoint_mode_file"] <- "modes"
    kinds[keys == "use_patterns_file"]  <- "occupancy"
  }

  return(kinds)
}
