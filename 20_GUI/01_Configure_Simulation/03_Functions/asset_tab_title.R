# -------------------------------------------------------------
# Function: asset_tab_title.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the title of the tab of a file of an asset from the name of
# the file, by removing its number and its extension and replacing
# its underscores with spaces. For example 11_Model_parameters.csv
# gives Model parameters.
# -------------------------------------------------------------
# Inputs
#   filename : Character. Name of the file, or its path.
# -------------------------------------------------------------
# Outputs
#   Character. The title.
# -------------------------------------------------------------
# Code outline
# 1. Strip the folder, the number and the extension.
# 2. Replace the underscores.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   asset_tab_title(filename)
# -------------------------------------------------------------

asset_tab_title <- function(filename) {

  # -------------------------------------------------------------
  # 1. Strip the folder, the number and the extension
  # -------------------------------------------------------------
  {
    title <- sub("\\.[A-Za-z0-9]+$", "", basename(filename))
    title <- sub("^[0-9]+_", "", title)
  }

  # -------------------------------------------------------------
  # 2. Replace the underscores
  # -------------------------------------------------------------
  {
    title <- gsub("_", " ", title)
  }

  return(title)
}
