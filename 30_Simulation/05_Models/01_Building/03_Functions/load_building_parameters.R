# -------------------------------------------------------------
# Function: load_building_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads the parameter groups of one Building from the files of its
# configuration folder. It is the operation load_parameters of the
# contract of the type Building (see model_type_contract()). The
# files are read by the loading scripts of the building, each one
# validated against the parameter catalogue as it is read:
#   - 10_Operational_temperature_corrections.csv
#   - 11_Model_parameters.csv, from which the ventilation
#     resistances are computed
#   - 13_Modes_setpoints.csv, which holds the table of the modes and,
#     above it, the block with the deadband of the hysteresis
#   - 14_Use_Patterns.csv
#   - 18_Comfort_parameters.csv, with the comfort weight and the
#     comfort bands of the building
# The scripts are sourced into the environment of this function,
# where asset_paths is their paths, so that they read the files of
# this asset as they would read the files of the system.
# -------------------------------------------------------------
# Inputs
#   asset_paths                : List. The paths of the files of the
#                                asset, as build_asset_paths()
#                                gives them.
#   validation_config          : Named list. The parameter catalogue.
#   bounding_validation_config : Data frame. Content of
#                                Validation_bounding_simulation.csv.
#   parameters                 : List. The parameters of the system
#                                already loaded. It must hold
#                                physical_properties.
# -------------------------------------------------------------
# Outputs
#   Named list with the groups of the building, in this order:
#   - model
#   - operational_temperature_corrections
#   - setpoint_modes
#   - use_patterns
#   - comfort
#   - control, the block of parameters of the modes file (Deadband),
#     under the group the catalogue gives its rows
# -------------------------------------------------------------
# Code outline
# 1. Load the files of the building
# 2. Gather the groups
# -------------------------------------------------------------
# Usage instructions
# groups <- load_building_parameters(
#   asset_paths                = asset_paths,
#   validation_config          = validation_config,
#   bounding_validation_config = bounding_validation_config,
#   parameters                 = parameters
# )
# -------------------------------------------------------------

load_building_parameters <- function(asset_paths,
                                     validation_config,
                                     bounding_validation_config,
                                     parameters) {

  # -------------------------------------------------------------
  # 1. Load the files of the building
  # -------------------------------------------------------------
  {
    # The loading scripts read the files from paths, and add what they
    # load to parameters. Here paths is the one of this asset, and
    # parameters is the local copy that is filled.
    paths <- asset_paths

    # load_parameter_file is called to read the corrections of the
    # reference temperature curves, and check every value against the
    # parameter catalogue.
    parameters$operational_temperature_corrections <- load_parameter_file(
      paths$operational_temperature_corrections_file,
      validation_config
    )

    # load_11_model_parameters.R is sourced to load the model
    # parameters into parameters$model; it needs
    # parameters$physical_properties to compute Rvent.
    source(file.path("30_Simulation", "05_Models", "01_Building",
                     "04_Scripts", "load_11_model_parameters.R"),
           local = TRUE)

    # load_13_modes_setpoints.R is sourced to load and validate the
    # modes into parameters$setpoint_modes.
    source(file.path("30_Simulation", "05_Models", "01_Building",
                     "04_Scripts", "load_13_modes_setpoints.R"),
           local = TRUE)

    # load_14_use_patterns.R is sourced to load and validate the use
    # patterns into parameters$use_patterns.
    source(file.path("30_Simulation", "05_Models", "01_Building",
                     "04_Scripts", "load_14_use_patterns.R"),
           local = TRUE)

    # load_parameter_file is called to read the comfort weight and the
    # comfort bands of the building, and check every value against the
    # parameter catalogue.
    parameters$comfort <- load_parameter_file(
      paths$comfort_file,
      validation_config
    )

    # load_parameter_block is called to read the block of the modes
    # file, which holds the deadband of the hysteresis, and check it
    # against the parameter catalogue.
    control_block <- load_parameter_block(
      path              = paths$setpoint_mode_file,
      validation_config = validation_config
    )

    # The block is kept under the group its rows have in the
    # catalogue.
    block_rules   <- validation_config$rules[
      validation_config$rules$file == basename(paths$setpoint_mode_file) &
        !validation_config$rules$default %in% c("", "-"), ]
    control_group <- unique(block_rules$group)
    if (length(control_group) != 1) {
      stop("The parameters of the block of ",
           basename(paths$setpoint_mode_file),
           " must all belong to one group in the parameter catalogue")
    }
  }

  # -------------------------------------------------------------
  # 2. Gather the groups
  # -------------------------------------------------------------
  {
    building_groups <- list(
      model                               = parameters$model,
      operational_temperature_corrections =
        parameters$operational_temperature_corrections,
      setpoint_modes                      = parameters$setpoint_modes,
      use_patterns                        = parameters$use_patterns,
      comfort                             = parameters$comfort
    )
    building_groups[[control_group]] <- control_block

    rm(list = c("paths", "parameters", "control_block", "block_rules",
                "control_group"))
  }

  return(building_groups)
}
