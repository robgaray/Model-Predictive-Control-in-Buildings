# -------------------------------------------------------------
# Function: building_new_table.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the table of a Building on a time grid, with every column
# of its variable registry at its initial value. It is the
# operation new_table of the contract of the type Building (see
# model_type_contract()). Occupancy and Scheduling are integer
# columns at 0: both are generated afterwards, from the use
# patterns of the building (see building_prepare_period()).
# -------------------------------------------------------------
# Inputs
#   time  : POSIXct vector. The time grid of the simulation, that of
#           Main_df.
#   paths : List. The paths of the simulator. The variable registry
#           of the building is the file paths$building_variables_file.
# -------------------------------------------------------------
# Outputs
#   Data frame. The table of the building, one row per element of
#   time.
# -------------------------------------------------------------
# Code outline
# 1. Synthesize the table from the variable registry.
# 2. Set Occupancy and Scheduling to integer 0.
# -------------------------------------------------------------
# Usage instructions
# asset_df <- building_new_table(
#   time  = Main_df$time,
#   paths = paths
# )
# -------------------------------------------------------------
building_new_table <- function(time,
                               paths
                               ) {

  # -------------------------------------------------------------
  # 1. Synthesize the table from the variable registry
  # -------------------------------------------------------------
  {
    # generate_variables_df is called to synthesize the table of the
    # building on the time grid, from the variable registry of the
    # building.
    asset_df <- generate_variables_df(paths$building_variables_file,
                                      time)
  }

  # -------------------------------------------------------------
  # 2. Set Occupancy and Scheduling to integer 0
  # -------------------------------------------------------------
  {
    asset_df$Occupancy  <- 0L
    asset_df$Scheduling <- 0L
  }

  return(asset_df)
}
