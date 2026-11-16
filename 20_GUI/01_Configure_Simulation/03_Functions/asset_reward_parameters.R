# -------------------------------------------------------------
# Function: asset_reward_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Selects, from the table of the parameters of the assets that the
# Reward Function tab shows, the rows of one type of model. The
# table is 02_Config/GUI_reward_asset_parameters.csv, so the
# interface keeps no list of those parameters of its own.
# -------------------------------------------------------------
# Inputs
#   reward_table : Data frame. The table, with the columns
#                  asset_type, file_key and parameter.
#   asset_type   : Character. The type of model, for example
#                  Building.
# -------------------------------------------------------------
# Outputs
#   Data frame with the columns file_key and parameter, one row per
#   parameter, with no rows when the type has none.
# -------------------------------------------------------------
# Code outline
# 1. Select the rows of the type.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   asset_reward_parameters(reward_table, asset_type)
# -------------------------------------------------------------

asset_reward_parameters <- function(reward_table, asset_type) {

  # -------------------------------------------------------------
  # 1. Select the rows of the type
  # -------------------------------------------------------------
  {
    rows <- reward_table[reward_table$asset_type == asset_type,
                         c("file_key", "parameter"), drop = FALSE]
    rownames(rows) <- NULL
  }

  return(rows)
}
