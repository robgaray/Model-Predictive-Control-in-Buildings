# -------------------------------------------------------------
# Function: building_variable_registry.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the path of the variable registry of the type Building,
# Simulation_Variables_Building.txt, the one place where the
# columns of the table of a building are declared. It is the
# operation variable_registry of the contract of the type Building
# (see model_type_contract()).
# -------------------------------------------------------------
# Inputs
#   paths : List. The paths of the simulator. The variable registry
#           of the building is the file paths$building_variables_file.
# -------------------------------------------------------------
# Outputs
#   Character scalar. The path of the variable registry.
# -------------------------------------------------------------
# Code outline
# 1. Take the path from the paths of the simulator
# -------------------------------------------------------------
# Usage instructions
# registry_path <- building_variable_registry(paths)
# -------------------------------------------------------------

building_variable_registry <- function(paths) {

  # -------------------------------------------------------------
  # 1. Take the path from the paths of the simulator
  # -------------------------------------------------------------
  {
    registry_path <- paths$building_variables_file
  }

  return(registry_path)
}
