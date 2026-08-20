# -------------------------------------------------------------
# Script: load_all_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Master parameter-loading script. Replaces data_model_parameters.R,
# control_optimization_parameters.R, and market_config_parameters.R.
# Executes one sub-script per configuration file, each of which
# validates the loaded values against Parameter_config.csv.
# -------------------------------------------------------------
# Inputs
#   paths
#     List. Paths set by initialization.R.
# -------------------------------------------------------------
# Outputs
#   Main_df    : Data frame. Main simulation data frame (full year,
#                not subsetted).
#   parameters : List with sub-lists model, physical_properties,
#                use_patterns, reward, forecast, control, optimization, market,
#                market_config_scheduling, market_config_piloting,
#                energy_price, flexibility_generation, debug_and_config,
#                setpoint_modes, needed_cols.
# -------------------------------------------------------------
# Code outline
#   1.  Load validation configuration (Parameter_config.csv)
#   2.  Assemble Main_df via assemble_main_df.R (Meteo_df/Energy_Prices_df
#       + synthetic dataframes), force Occupancy/Scheduling to 0, validate
#       structure (validate_Main_df())
#   3.  Initialise empty parameters list
#   4.  Source sub-scripts (one per CSV file)
#   5.  Load needed-columns list
#   6.  Recalculate T_ext_24h from previous-day averages
# -------------------------------------------------------------
# Usage
#   source(file.path("30_Simulation", "04_Scripts", "load_all_parameters.R"))
# -------------------------------------------------------------
# Where this script is used
#   Sourced by Main.R after initialization.R.
# -------------------------------------------------------------
# Functions / scripts called
#   read_and_validate_parameter_csv(), load_market_config_table(),
#   validate_parameter_config(), validate_Main_df(),
#   validate_physical_properties(), validate_model_parameters(),
#   compute_Rvent(), load_control_parameters(),
#   load_optimization_parameters(), load_market_parameters(),
#   load_debug_and_config_parameters()  -- from 30_Simulation/03_Functions/
#   load_03_physical_properties.R, load_04_use_patterns.R,
#   load_11_model_parameters.R,
#   load_12_control_parameters.R, load_13_modes_setpoints.R,
#   load_14_optimization_parameters.R, load_15_market_config.R,
#   load_16_market_config_scheduling.R,
#   load_17_market_config_piloting.R, load_18_reward_parameters.R,
#   load_19_forecast_parameters.R, load_21_energy_price_parameters.R,
#   load_22_flexibility_generation.R,
#   load_30_debug_and_config.R, assemble_main_df.R
#                                    -- from 30_Simulation/04_Scripts/
# -------------------------------------------------------------

# -----------------------------------------------------------
# 1. Load validation configuration
# -----------------------------------------------------------
{
  validation_config <- read.csv(
    paths$parameter_validation_file,
    comment.char     = "#",
    stringsAsFactors = FALSE
  )
}

# -----------------------------------------------------------
# 2. Assemble Main_df from Meteo_df/Energy_Prices_df (real input
#    dataframes) and System_df/Flexibility_actions_df/
#    Meteo_transformations_df (synthetic dataframes), validate structure
# -----------------------------------------------------------
{
  # assemble_main_df.R is sourced to load Meteo_df/Energy_Prices_df
  # and build the synthetic dataframes, assembling all of them into
  # Main_df on the common 5' master grid.
  source(file.path("30_Simulation", "04_Scripts", "assemble_main_df.R"))

  Main_df$Occupancy  <- 0L
  Main_df$Scheduling <- 0L
  # validate_Main_df is called to check that the freshly assembled
  # Main_df has the expected structure (columns, types) before any
  # parameter is loaded on top of it.
  validate_Main_df(Main_df)
}

# -----------------------------------------------------------
# 3. Initialise parameters list
# -----------------------------------------------------------
{
  parameters <- list()
}

# -----------------------------------------------------------
# 4. Source one sub-script per configuration file
# -----------------------------------------------------------
{
  # load_03_physical_properties.R is sourced to load and validate
  # 03_Physical_properties.csv into parameters$physical_properties.
  source(file.path("30_Simulation", "04_Scripts", "load_03_physical_properties.R"))
  # load_11_model_parameters.R is sourced to load 11_Model_parameters.csv
  # into parameters$model; it needs parameters$physical_properties,
  # already loaded above, to compute Rvent.
  source(file.path("30_Simulation", "04_Scripts", "load_11_model_parameters.R"))
  # load_04_use_patterns.R is sourced to load and validate
  # 04_Use_Patterns.csv into parameters$use_patterns.
  source(file.path("30_Simulation", "04_Scripts", "load_04_use_patterns.R"))
  # load_18_reward_parameters.R is sourced to load and validate
  # 18_Reward_parameters.csv into parameters$reward.
  source(file.path("30_Simulation", "04_Scripts", "load_18_reward_parameters.R"))
  # load_19_forecast_parameters.R is sourced to load and validate
  # 19_Forecast_parameters.csv into parameters$forecast.
  source(file.path("30_Simulation", "04_Scripts", "load_19_forecast_parameters.R"))
  # load_12_control_parameters.R is sourced to load and validate
  # 12_Control_parameters.csv into parameters$control.
  source(file.path("30_Simulation", "04_Scripts", "load_12_control_parameters.R"))
  # load_13_modes_setpoints.R is sourced to load and validate
  # 13_Modes_setpoints.csv into parameters$setpoint_modes.
  source(file.path("30_Simulation", "04_Scripts", "load_13_modes_setpoints.R"))
  # load_14_optimization_parameters.R is sourced to load and validate
  # 14_Optimization_parameters.csv into parameters$optimization.
  source(file.path("30_Simulation", "04_Scripts", "load_14_optimization_parameters.R"))
  # load_15_market_config.R is sourced to load 15_Market_config.csv
  # into parameters$market; it needs parameters$control, already
  # loaded above, to set optimization_aim.
  source(file.path("30_Simulation", "04_Scripts", "load_15_market_config.R"))
  # load_16_market_config_scheduling.R is sourced to load and validate
  # 16_Market_config_scheduling.csv into parameters$market_config_scheduling.
  source(file.path("30_Simulation", "04_Scripts", "load_16_market_config_scheduling.R"))
  # load_17_market_config_piloting.R is sourced to load and validate
  # 17_Market_config_piloting.csv into parameters$market_config_piloting.
  source(file.path("30_Simulation", "04_Scripts", "load_17_market_config_piloting.R"))
  # load_21_energy_price_parameters.R is sourced to load and validate
  # 21_Energy_price_parameters.csv into parameters$energy_price.
  source(file.path("30_Simulation", "04_Scripts", "load_21_energy_price_parameters.R"))
  # load_22_flexibility_generation.R is sourced to load and validate
  # 22_Flexibility_generation_parameters.csv into
  # parameters$flexibility_generation.
  source(file.path("30_Simulation", "04_Scripts", "load_22_flexibility_generation.R"))
  # load_30_debug_and_config.R is sourced to load and validate
  # 30_Debug_and_config.csv into parameters$debug_and_config.
  source(file.path("30_Simulation", "04_Scripts", "load_30_debug_and_config.R"))
  rm(validation_config)
}

# -----------------------------------------------------------
# 5. Load needed-columns list
# -----------------------------------------------------------
{
  needed_cols_lines      <- readLines(paths$needed_cols_file)
  parameters$needed_cols <- needed_cols_lines[
    !grepl("^\\s*#", needed_cols_lines) & nzchar(trimws(needed_cols_lines))
  ]
  cat("needed_cols loaded:", length(parameters$needed_cols), "columns\n")
  rm(needed_cols_lines)
}

# -----------------------------------------------------------
# 6. Recalculate T_ext_24h from previous-day averages
# -----------------------------------------------------------
{
  t_ext_24h_default <- parameters$forecast$t_ext_24h_default
  if (is.null(t_ext_24h_default) || is.na(t_ext_24h_default)) {
    stop("t_ext_24h_default is missing\n")
  }

  row_dates       <- as.Date(Main_df$time)
  daily_mean_text <- tapply(Main_df$Text, row_dates, mean, na.rm = TRUE)
  unique_dates    <- sort(unique(row_dates))
  previous_dates  <- unique_dates - 1

  previous_day_means                    <- rep(t_ext_24h_default, length(unique_dates))
  names(previous_day_means)             <- as.character(unique_dates)
  has_previous                          <- as.character(previous_dates) %in% names(daily_mean_text)
  previous_day_means[has_previous]      <- daily_mean_text[as.character(previous_dates[has_previous])]

  Main_df$T_ext_24h <- previous_day_means[as.character(row_dates)]

  cat("T_ext_24h recalculated based on previous day Text average\n")
  cat("Default value used when no previous day:", t_ext_24h_default, "\n")
  rm(t_ext_24h_default, row_dates, daily_mean_text, unique_dates,
     previous_dates, previous_day_means, has_previous)
}
