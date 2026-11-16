# -------------------------------------------------------------
# Function: photovoltaic_new_table.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the table of a photovoltaic installation on a time grid,
# with every column of its variable registry at its initial value.
# It is the operation new_table of the contract of the type
# Photovoltaic (see model_type_contract()). The table holds the
# electricity the installation produces and its electricity for the
# system, each one for the execution and for the plan and the two
# flexibility itineraries.
# -------------------------------------------------------------
# Inputs
#   time  : POSIXct vector. The time grid of the simulation, that of
#           Main_df.
#   paths : List. The paths of the simulator. The variable registry
#           of the installation is the file
#           paths$photovoltaic_variables_file.
# -------------------------------------------------------------
# Outputs
#   Data frame. The table of the installation, one row per element of
#   time.
# -------------------------------------------------------------
# Code outline
# 1. Synthesize the table from the variable registry
# -------------------------------------------------------------
# Usage instructions
# asset_df <- photovoltaic_new_table(
#   time  = Main_df$time,
#   paths = paths
# )
# -------------------------------------------------------------

photovoltaic_new_table <- function(time,
                                   paths
                                   ) {

  # -------------------------------------------------------------
  # 1. Synthesize the table from the variable registry
  # -------------------------------------------------------------
  {
    # generate_variables_df is called to synthesize the table of the
    # installation on the time grid, from the variable registry of
    # the type.
    asset_df <- generate_variables_df(paths$photovoltaic_variables_file,
                                      time)
  }

  return(asset_df)
}
