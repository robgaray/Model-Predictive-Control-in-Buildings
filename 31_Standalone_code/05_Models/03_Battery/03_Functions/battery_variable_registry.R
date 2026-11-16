# -------------------------------------------------------------
# Function: battery_variable_registry.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the path of the variable registry of the type Battery,
# Simulation_Variables_Battery.txt, the one place where the columns
# of the table of a battery are declared. It is the operation
# variable_registry of the contract of the type Battery (see
# model_type_contract()).
# -------------------------------------------------------------
# Inputs
#   paths : List. The paths of the simulator. The variable registry
#           of the battery is the file paths$battery_variables_file.
# -------------------------------------------------------------
# Outputs
#   Character scalar. The path of the variable registry.
# -------------------------------------------------------------
# Code outline
# 1. Take the path from the paths of the simulator
# -------------------------------------------------------------
# Usage instructions
# registry_path <- battery_variable_registry(paths)
# -------------------------------------------------------------

battery_variable_registry <- function(paths) {

  # -------------------------------------------------------------
  # 1. Take the path from the paths of the simulator
  # -------------------------------------------------------------
  {
    registry_path <- paths$battery_variables_file
  }

  return(registry_path)
}
