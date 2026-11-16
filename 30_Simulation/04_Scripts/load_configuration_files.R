# -------------------------------------------------------------
# Script: load_configuration_files.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads every configuration file of the system, in the order of their
# numbers, and the files of each asset of the asset registry, each one
# validated against the parameter catalogue as it is read. A file of
# parameter/value lines is loaded by load_parameter_file(), which
# takes the names from the file and the types from the catalogue. The
# files that need more than that keep a script of their own:
#   - the market configuration, whose aim codes are translated and
#     whose horizons are checked against the market resolution
#   - the two market tables
# The loading dependencies hold in this order: Market is loaded after
# Optimization. The control of the system, parameters$control, is the
# flexibility event configuration. The asset registry is loaded last:
# each asset loads its own files, from its own configuration folder,
# through the contract of its type of model, and takes from the
# system parameters loaded before it the physical properties. The
# comfort weight and the comfort bands are not in the reward file:
# each Building loads them from its own file.
# The verification battery sources
# this script too, so the two load the same parameters in the same
# order.
# The scripts it sources run in the environment this script runs in
# (local = TRUE), so they fill the parameters of whoever sources it.
# -------------------------------------------------------------
# Inputs
#   paths                      : List. Paths set by
#                                initialize_simulator().
#   validation_config          : Named list. The parameter catalogue.
#   bounding_validation_config : Data frame. Content of
#                                Validation_bounding_simulation.csv.
#   parameters                 : List. The parameters being assembled,
#                                with the internal parameters already
#                                loaded.
# -------------------------------------------------------------
# Outputs
#   parameters, with the sub-lists:
#     - optimization
#     - control
#     - market
#     - market_config_scheduling
#     - market_config_piloting
#     - energy_price
#     - flexibility_price_emulation
#     - reward
#     - forecast
#     - assets, one entry per asset, with its asset_id, its
#       asset_type and the groups of its type of model. A Building
#       holds:
#         - model
#         - operational_temperature_corrections
#         - setpoint_modes
#         - use_patterns
#         - comfort, from 18_Comfort_parameters.csv
#   One LOAD line is written to the console, after the lines of the
#   assets, with the market resolution and the optimization aims.
#   The scripts it sources write nothing.
# -------------------------------------------------------------
# Code outline
# 1. Optimization parameters
# 2. Market configuration
# 3. Market configuration, scheduling
# 4. Market configuration, piloting
# 5. Energy price parameters
# 6. Flexibility price emulation
# 7. Flexibility event configuration
# 8. Reward parameters
# 9. Forecast parameters
# 10. Asset registry
# 11. Report
# -------------------------------------------------------------
# Usage instructions
#   source(file.path("30_Simulation", "04_Scripts",
#                    "load_configuration_files.R"))
#   Not called: sourced by load_all_parameters(), which supplies
#   paths, the validation tables and parameters.
# -------------------------------------------------------------

# -------------------------------------------------------------
# 1. Optimization parameters
# -------------------------------------------------------------
{
  # load_parameter_file is called to read 01_Optimization_parameters.csv,
  # the parameters of the genetic algorithm, and check every value
  # against the parameter catalogue.
  parameters$optimization <- load_parameter_file(
    paths$optimization_file,
    validation_config
  )
}

# -------------------------------------------------------------
# 2. Market configuration
# -------------------------------------------------------------
{
  # load_03_market_config.R is sourced to load 03_Market_config.csv
  # into parameters$market; it needs parameters$optimization, already
  # loaded above.
  source(file.path("30_Simulation", "04_Scripts", "load_03_market_config.R"), local = TRUE)
}

# -------------------------------------------------------------
# 3. Market configuration, scheduling
# -------------------------------------------------------------
{
  # load_04_market_config_scheduling.R is sourced to load and validate
  # 04_Market_config_scheduling.csv into
  # parameters$market_config_scheduling.
  source(file.path("30_Simulation", "04_Scripts", "load_04_market_config_scheduling.R"), local = TRUE)
}

# -------------------------------------------------------------
# 4. Market configuration, piloting
# -------------------------------------------------------------
{
  # load_05_market_config_piloting.R is sourced to load and validate
  # 05_Market_config_piloting.csv into parameters$market_config_piloting.
  source(file.path("30_Simulation", "04_Scripts", "load_05_market_config_piloting.R"), local = TRUE)
}

# -------------------------------------------------------------
# 5. Energy price parameters
# -------------------------------------------------------------
{
  # load_parameter_file is called to read 06_Energy_price_parameters.csv
  # into parameters$energy_price.
  parameters$energy_price <- load_parameter_file(
    paths$energy_price_file,
    validation_config
  )
}

# -------------------------------------------------------------
# 6. Flexibility price emulation
# -------------------------------------------------------------
{
  # load_parameter_file is called to read
  # 07_Flexibility_price_emulation_parameters.csv into
  # parameters$flexibility_price_emulation.
  parameters$flexibility_price_emulation <- load_parameter_file(
    paths$flexibility_price_emulation_file,
    validation_config
  )
}

# -------------------------------------------------------------
# 7. Flexibility event configuration
# The parameters that define the flexibility events belong to the
# control, so they make parameters$control.
# -------------------------------------------------------------
{
  # load_parameter_file is called to read
  # 08_Flexibility_Event_Configuration.csv into parameters$control.
  parameters$control <- load_parameter_file(
    paths$flexibility_events_file,
    validation_config
  )
}

# -------------------------------------------------------------
# 8. Reward parameters
# -------------------------------------------------------------
{
  # load_parameter_file is called to read 09_Reward_parameters.csv into
  # parameters$reward.
  parameters$reward <- load_parameter_file(
    paths$reward_file,
    validation_config
  )

}

# -------------------------------------------------------------
# 9. Forecast parameters
# -------------------------------------------------------------
{
  # load_parameter_file is called to read 15_Forecast_parameters.csv
  # into parameters$forecast.
  parameters$forecast <- load_parameter_file(
    paths$forecast_file,
    validation_config
  )
}

# -------------------------------------------------------------
# 10. Asset registry
# The registry is loaded after every other file, because each asset
# loads its own files with the help of the system parameters loaded
# above: the physical properties and the comfort group of the reward
# file. The files of an asset are in its own configuration folder.
# -------------------------------------------------------------
{
  # load_12_asset_registry.R is sourced to load and validate
  # 12_Asset_registry.csv and to load the files of each asset into
  # parameters$assets, through the contract of its type of model.
  source(file.path("30_Simulation", "04_Scripts", "load_12_asset_registry.R"), local = TRUE)
}

# -------------------------------------------------------------
# 11. Report
# -------------------------------------------------------------
{
  # console_message is called to write the only line of this script,
  # after the lines of the assets: the market resolution and the
  # optimization aims of the markets.
  console_message(
    label = "LOAD",
    text  = paste0("Configuration files: market resolution ",
                   parameters$market$market_resolution,
                   " min, optimization aims scheduling=",
                   parameters$market$optimization_aim_scheduling,
                   " and piloting=",
                   parameters$market$optimization_aim_piloting)
  )
}
