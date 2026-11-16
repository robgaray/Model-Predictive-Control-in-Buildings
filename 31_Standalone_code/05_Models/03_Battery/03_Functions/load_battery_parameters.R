# -------------------------------------------------------------
# Function: load_battery_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the parameter group of one battery. It is the operation
# load_parameters of the contract of the type Battery (see
# model_type_contract()). The battery has one file in its
# configuration folder, 19_Battery_parameters.csv, validated against
# the parameter catalogue as it is read.
# -------------------------------------------------------------
# Inputs
#   asset_paths                : List. The paths of the files of the
#                                asset, as build_asset_paths()
#                                gives them.
#   validation_config          : Named list. The parameter catalogue.
#   bounding_validation_config : Data frame. Content of
#                                Validation_bounding_simulation.csv.
#                                Not read.
#   parameters                 : List. The parameters of the system
#                                already loaded. Not read.
# -------------------------------------------------------------
# Outputs
#   Named list with the group of the battery:
#   - battery: the 9 parameters of the file:
#     - Capacity
#     - SOC_min
#     - SOC_max
#     - SOC_initial
#     - Charge_power_max
#     - Discharge_power_max
#     - Charge_efficiency
#     - Discharge_efficiency
#     - Self_discharge
# -------------------------------------------------------------
# Code outline
# 1. Load the file of the battery
# -------------------------------------------------------------
# Usage instructions
# groups <- load_battery_parameters(
#   asset_paths                = asset_paths,
#   validation_config          = validation_config,
#   bounding_validation_config = bounding_validation_config,
#   parameters                 = parameters
# )
# -------------------------------------------------------------

load_battery_parameters <- function(asset_paths,
                                    validation_config,
                                    bounding_validation_config,
                                    parameters) {

  # -------------------------------------------------------------
  # 1. Load the file of the battery
  # -------------------------------------------------------------
  {
    # load_parameter_file is called to read the parameters of the
    # battery and check every value against the parameter catalogue.
    battery_parameters <- load_parameter_file(
      asset_paths$battery_file,
      validation_config
    )

    battery_groups <- list(battery = battery_parameters)

    rm(list = "battery_parameters")
  }

  return(battery_groups)
}
