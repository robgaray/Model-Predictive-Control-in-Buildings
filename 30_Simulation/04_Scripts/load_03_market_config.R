# -------------------------------------------------------------
# Script: load_03_market_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads market configuration from 03_Market_config.csv, which also
# holds the six limits of the flexibility price emulation, used by both
# the basic and the complex modes of 09_flexibility_price_emulation.R:
#   - Max_flex_periods_day
#   - Max_flex_com_price
#   - Max_flex_exec_price
#   - Max_flex_period_duration
#   - Max_flex_probability_down
#   - Max_flex_probability_up
# It validates raw
# values against Parameter_config.csv, calls load_market_parameters()
# for structured loading with the horizon clamping logic of
# Validation_Market_Config.csv, resolves the raw
# scheduling/piloting aim codes (O/E/O+F/E+F) to internal text labels
# ("energy"/"flexibility"/"operation"/"operationflex") via
# map_optimization_aim(), and sets parameters$control$optimization_aim.
# Stores the result in parameters$market.
# Sourced from 02_load_all_parameters.R.
# Requires parameters$control and parameters$optimization to be
# already loaded.
# -------------------------------------------------------------
# Inputs
#   paths$market_file : path of 03_Market_config.csv, resolved by
#     01_initialization.R.
#   Its validation table, Validation_Market_Config.csv,
#     read alongside it.
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$market, populated. Nothing else is
#     modified.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value.
# 2. Turn the raw values into the market sub-list.
# 3. Translate each aim letter into its internal name.
# 4. Store the result in parameters$market.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by 02_load_all_parameters.R, which supplies
#   paths and parameters and takes the updated parameters back.
# -------------------------------------------------------------
# Where this function/script is used
# Sourced by 02_load_all_parameters.R.
# -------------------------------------------------------------
# functions/scripts called
#   load_market_parameters() - turns the raw market values
#                              into its sub-list
#   map_optimization_aim() - translates a market's aim letter
#                            into its internal name
#   read_and_validate_parameter_csv() - reads a configuration
#                                       file and validates
#                                       every value
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 03_Market_config.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$market_file, "03_Market_config.csv", validation_config
  )

  # load_market_parameters is called to turn the raw key/value pairs
  # into the structured market parameter list, applying its internal
  # clamping logic.
  parameters$market <- load_market_parameters(
    values                  = raw_values,
    market_validation_config = market_config_validation_config
  )
  rm(raw_values)

  # Resolve optimization_aim_scheduling using centralized mapping
  parameters$market$optimization_aim_scheduling <- map_optimization_aim(
    aim_raw     = parameters$market$optimization_aim_scheduling,
    column_name = "optimization_aim_scheduling",
    row_index   = 0
  )

  # Resolve optimization_aim_piloting using centralized mapping
  parameters$market$optimization_aim_piloting <- map_optimization_aim(
    aim_raw     = parameters$market$optimization_aim_piloting,
    column_name = "optimization_aim_piloting",
    row_index   = 0
  )

  # Set optimization_aim in control based on scheduling aim
  parameters$control$optimization_aim <- parameters$market$optimization_aim_scheduling

  # Validate market resolution divisibility
  if ((parameters$market$Optimization_horizon_scheduling * 60) %%
      parameters$market$market_resolution != 0) {
    stop("Optimization_horizon_scheduling must be divisible by market_resolution")
  }

  # Validate market_resolution is a multiple of Main_df's own grid
  # (parameters$computing$main_resolution_sec, the same value
  # assemble_main_df.R builds the grid with), so that a market slot is
  # always an exact number of Main_df rows - required by the flexibility
  # generation algorithm (09_flexibility_price_emulation.R), which discretizes
  # event start/duration/shift to slots of market_resolution.
  if ((parameters$market$market_resolution * 60) %%
      parameters$computing$main_resolution_sec != 0) {
    stop("market_resolution (minutes) must be a multiple of Main_df's own ",
         parameters$computing$main_resolution_sec, "s grid")
  }

  str(parameters$optimization)
  cat("Market configuration loaded\n")
  cat("optimization aims: scheduling=",
      parameters$market$optimization_aim_scheduling,
      ", piloting=",
      parameters$market$optimization_aim_piloting, "\n", sep = "")
}
