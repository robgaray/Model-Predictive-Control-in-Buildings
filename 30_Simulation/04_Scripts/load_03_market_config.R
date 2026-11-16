# -------------------------------------------------------------
# Script: load_03_market_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads market configuration from 03_Market_config.csv, which also
# holds the six limits of the flexibility price emulation, used by both
# the basic and the complex modes of prepare_flexibility_prices():
#   - Max_flex_periods_day
#   - Max_flex_com_price
#   - Max_flex_exec_price
#   - Max_flex_period_duration
#   - Max_flex_probability_down
#   - Max_flex_probability_up
# It validates the values against the parameter catalogue, checks
# that both optimization horizons are a whole number of market
# intervals,
# resolves the raw scheduling/piloting aim codes (O/E/O+F/E+F) to
# internal text labels
# ("energy"/"flexibility"/"operation"/"operationflex") via
# map_optimization_aim().
# Stores the result in parameters$market.
# Sourced from load_all_parameters().
# Requires parameters$optimization to be already loaded.
# -------------------------------------------------------------
# Inputs
#   paths$market_file : path of 03_Market_config.csv, resolved by
#     initialize_simulator().
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$market, populated. Nothing else is
#     modified.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value.
# 2. Translate each aim letter into its internal name.
# 3. Check the horizons against the market resolution.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by load_all_parameters(), which supplies
#   paths and parameters and takes the updated parameters back.
# -------------------------------------------------------------

{
  # load_parameter_file is called to read 03_Market_config.csv,
  # check every value against the parameter catalogue and return each
  # one in the type of its rule, into the market sub-list.
  parameters$market <- load_parameter_file(
    paths$market_file,
    validation_config
  )

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

  # Validate market resolution divisibility, for both families: an
  # optimization horizon has to be a whole number of market intervals.
  if ((parameters$market$Optimization_horizon_scheduling * 60) %%
      parameters$market$market_resolution != 0) {
    stop("Optimization_horizon_scheduling must be divisible by market_resolution")
  }
  if ((parameters$market$Optimization_horizon_piloting * 60) %%
      parameters$market$market_resolution != 0) {
    stop("Optimization_horizon_piloting must be divisible by market_resolution")
  }

  # Validate market_resolution is a multiple of Main_df's own grid
  # (parameters$computing$main_resolution_sec, the same value
  # assemble_main_df.R builds the grid with), so that a market slot is
  # always an exact number of Main_df rows - required by the flexibility
  # generation algorithm (prepare_flexibility_prices()), which discretizes
  # event start/duration/shift to slots of market_resolution.
  if ((parameters$market$market_resolution * 60) %%
      parameters$computing$main_resolution_sec != 0) {
    stop("market_resolution (minutes) must be a multiple of Main_df's own ",
         parameters$computing$main_resolution_sec, "s grid")
  }
}
