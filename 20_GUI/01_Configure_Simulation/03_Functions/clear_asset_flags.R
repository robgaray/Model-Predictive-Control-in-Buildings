# -------------------------------------------------------------
# Function: clear_asset_flags.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Clears the flags of the state of one asset once its values have
# been written: the parameters that took a default, the parameters
# found twice and the rows that took a default. The values just
# saved are the choice of the user, so the interface stops painting
# them in red.
# -------------------------------------------------------------
# Inputs
#   asset_rv : reactiveValues. The state of the asset, as built from
#              load_asset_state().
# -------------------------------------------------------------
# Outputs
#   None. The state of the asset is changed.
# -------------------------------------------------------------
# Code outline
# 1. Empty each flag, by the suffix of its name.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   clear_asset_flags(asset_rv)
# -------------------------------------------------------------

clear_asset_flags <- function(asset_rv) {

  # -------------------------------------------------------------
  # 1. Empty each flag, by the suffix of its name
  # -------------------------------------------------------------
  {
    slots <- names(reactiveValuesToList(asset_rv))
    for (CONT_001 in slots[grepl("__(defaulted|duplicated)$", slots)]) {
      asset_rv[[CONT_001]] <- character(0)
    }
    for (CONT_002 in slots[grepl("__defaulted_rows$", slots)]) {
      asset_rv[[CONT_002]] <- integer(0)
    }
    rm(slots, CONT_001, CONT_002)
  }

  return(invisible(NULL))
}
