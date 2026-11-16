# -------------------------------------------------------------
# Function: asset_type_files.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Lists the configuration files that every asset of a type of model
# holds, in the order of the file paths table. They are the rows of
# 04_File_paths.csv whose scope is the type, so the interface keeps
# no list of files of its own.
# -------------------------------------------------------------
# Inputs
#   paths_table : Data frame. The file paths table, with the columns
#                 key, scope and filename.
#   asset_type  : Character. The type of model, for example Building.
# -------------------------------------------------------------
# Outputs
#   Data frame with the columns key and filename, one row per file,
#   with no rows when the type holds no file.
# -------------------------------------------------------------
# Code outline
# 1. Select the rows of the type.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   asset_type_files(paths_table, asset_type)
# -------------------------------------------------------------

asset_type_files <- function(paths_table, asset_type) {

  # -------------------------------------------------------------
  # 1. Select the rows of the type
  # -------------------------------------------------------------
  {
    rows <- paths_table[paths_table$scope == asset_type,
                        c("key", "filename"), drop = FALSE]
    rownames(rows) <- NULL
  }

  return(rows)
}
