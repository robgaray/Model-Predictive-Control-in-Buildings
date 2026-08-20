# -------------------------------------------------------------
# Script: load_15_market_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads market configuration from 15_Market_config.csv (which also
# holds the 5 flexibility-price-generation parameters,
# Max_flex_periods_day/Max_flex_com_price/Max_flex_exec_price/
# Max_flex_period_duration/Max_flex_probability, used by both the
# basic and complex modes of flexibility_generation.R), validates raw
# values against Parameter_config.csv, calls load_market_parameters()
# for structured loading with internal clamping logic, resolves the raw
# scheduling/piloting aim codes (O/E/O+F/E+F) to internal text labels
# ("energy"/"flexibility"/"operation"/"operationflex") via
# map_optimization_aim(), and sets parameters$control$optimization_aim.
# Stores the result in parameters$market.
# Sourced from load_all_parameters.R.
# Requires parameters$control to be already loaded.
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 15_Market_config.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$market_file, "15_Market_config.csv", validation_config
  )

  # load_market_parameters is called to turn the raw key/value pairs
  # into the structured market parameter list, applying its internal
  # clamping logic.
  parameters$market <- load_market_parameters(raw_values)
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

  # Validate market_resolution is a multiple of Main_df's own fixed grid (300s,
  # see assemble_main_df.R), so that a market slot is always an exact number
  # of Main_df rows - required by the flexibility generation algorithm
  # (flexibility_generation.R), which discretizes event start/duration/shift
  # to slots of market_resolution.
  if ((parameters$market$market_resolution * 60) %% 300 != 0) {
    stop("market_resolution (minutes) must be a multiple of Main_df's own ",
         "5-minute (300s) grid")
  }

  str(parameters$optimization)
  cat("Market configuration loaded\n")
  cat("optimization aims: scheduling=",
      parameters$market$optimization_aim_scheduling,
      ", piloting=",
      parameters$market$optimization_aim_piloting, "\n", sep = "")
}
