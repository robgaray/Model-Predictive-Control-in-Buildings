# -------------------------------------------------------------
# Script: 02_load_all_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Master parameter-loading script. Replaces data_model_parameters.R,
# control_optimization_parameters.R, and market_config_parameters.R.
# Executes one sub-script per configuration file, each of which
# validates the loaded values against Parameter_config.csv.
# -------------------------------------------------------------
# Inputs
#   paths
#     List. Paths set by 01_initialization.R.
# -------------------------------------------------------------
# Outputs
#   Main_df    : Data frame. Main simulation data frame (full year,
#                not subsetted).
#   parameters : List with these sub-lists:
#                  - computing
#                  - physical_properties
#                  - needed_cols
#                  - model
#                  - use_patterns
#                  - control
#                  - setpoint_modes
#                  - optimization
#                  - market
#                  - market_config_scheduling
#                  - market_config_piloting
#                  - reward
#                  - operational_temperature_corrections
#                  - forecast
#                  - energy_price
#                  - flexibility_price_emulation
#                  - debug_and_config
# -------------------------------------------------------------
# Code outline
#   A. Internal parameters
#      1. Validation configuration files (Parameter_config.csv and the
#         validation tables of 00_Validation/)
#      2. Computing parameters, which the assembly of Main_df needs
#      3. Physical properties
#      4. Debug and configuration
#      5. Needed columns
#   B. Main_df
#      6. Assemble Main_df via assemble_main_df.R (Meteo_df/
#         Energy_Prices_df + synthetic dataframes), force
#         Occupancy/Scheduling to 0
#      7. Validate its structure (validate_Main_df())
#   C. Parameters
#      8-22. One loader per configuration file, from
#            01_Optimization_parameters.csv to 15_Forecast_parameters.csv
#      23. Recalculate T_ext_24h from previous-day averages
# -------------------------------------------------------------
# Usage instructions
#   source(file.path("30_Simulation", "04_Scripts", "02_load_all_parameters.R"))
#   Not called: sourced by Main.R after 01_initialization.R, and it
#   sources in turn every loader of 02_Config.
# -------------------------------------------------------------
# Where this function/script is used
#   Sourced by Main.R after 01_initialization.R.
# Sourced by 30_Simulation/Main.R.
# -------------------------------------------------------------
# functions/scripts called
#   Sourced, one per configuration file, each filling its own
#   sub-list of parameters, in this order:
#   load_01_computing_parameters.R, load_03_physical_properties.R,
#   load_16_debug_and_config.R, load_01_optimization_parameters.R,
#   load_02_control.R, load_03_market_config.R,
#   load_04_market_config_scheduling.R,
#   load_05_market_config_piloting.R,
#   load_06_energy_price_parameters.R,
#   load_07_flexibility_price_emulation.R,
#   load_08_flexibility_event_configuration.R,
#   load_09_reward_parameters.R,
#   load_10_operational_temperature_corrections.R,
#   load_11_model_parameters.R, load_12_temperature_setpoints.R,
#   load_13_modes_setpoints.R, load_14_use_patterns.R,
#   load_15_forecast_parameters.R
#                                    -- from 30_Simulation/04_Scripts/
#   assemble_main_df.R - builds Main_df from the input series
#   validate_Main_df() - checks Main_df against its declared ranges
#   The loaders in turn call read_and_validate_parameter_csv() and the
#   load_*_parameters() and validate_*() functions of
#   30_Simulation/03_Functions/.
# -------------------------------------------------------------

# -------------------------------------------------------------
# A. Internal parameters
# Loads what the rest of the script and the loaders need before any
# configuration file of 02_Config is read:
#   - the validation tables of 00_Validation/
#   - the computing parameters, which set the master time grid of
#     Main_df
#   - the physical properties
#   - the debug and configuration switches
#   - the list of needed columns
# Steps:
#   1. Validation configuration files
#   2. Computing parameters
#   3. Physical properties
#   4. Debug and configuration
#   5. Needed columns
# -------------------------------------------------------------
{
  # -------------------------------------------------------------
  # 1. Validation configuration files
  # Parameter_config.csv holds the type/range rules shared by every
  # parameter file. The three tables read next hold the limits that
  # are applied outside that mechanism: the engine's own computing
  # parameters, the clamped market horizons, and the plausibility
  # bounds of Main_df's columns and of the building volume. None of
  # these limits is written in the code that enforces them.
  # -------------------------------------------------------------
  validation_config <- read.csv(
    paths$parameter_validation_file,
    comment.char     = "#",
    stringsAsFactors = FALSE
  )

  computing_validation_config <- read.csv(
    paths$computing_validation_file,
    comment.char     = "#",
    stringsAsFactors = FALSE
  )

  market_config_validation_config <- read.csv(
    paths$market_config_validation_file,
    comment.char     = "#",
    stringsAsFactors = FALSE
  )

  bounding_validation_config <- read.csv(
    paths$bounding_simulation_validation_file,
    comment.char     = "#",
    stringsAsFactors = FALSE
  )

  # -------------------------------------------------------------
  # 2. Computing parameters
  # The computing parameters are loaded before Main_df because
  # main_resolution_sec defines the master time grid that Main_df is
  # assembled on, in block B.
  # -------------------------------------------------------------
  parameters <- list()

  # load_01_computing_parameters.R is sourced to load and validate
  # 01_computing_parameters.csv into parameters$computing.
  source(file.path("30_Simulation", "04_Scripts", "load_01_computing_parameters.R"))
  rm(computing_validation_config)

  # -------------------------------------------------------------
  # 3. Physical properties
  # -------------------------------------------------------------
  # load_03_physical_properties.R is sourced to load and validate
  # 03_Physical_properties.csv into parameters$physical_properties.
  source(file.path("30_Simulation", "04_Scripts", "load_03_physical_properties.R"))

  # -------------------------------------------------------------
  # 4. Debug and configuration
  # -------------------------------------------------------------
  # load_16_debug_and_config.R is sourced to load and validate
  # 16_Debug_and_config.csv into parameters$debug_and_config.
  source(file.path("30_Simulation", "04_Scripts", "load_16_debug_and_config.R"))

  # -------------------------------------------------------------
  # 5. Needed columns
  # -------------------------------------------------------------
  needed_cols_lines      <- readLines(paths$needed_cols_file)
  parameters$needed_cols <- needed_cols_lines[
    !grepl("^\\s*#", needed_cols_lines) & nzchar(trimws(needed_cols_lines))
  ]
  cat("needed_cols loaded:", length(parameters$needed_cols), "columns\n")
  rm(needed_cols_lines)
}

# -------------------------------------------------------------
# B. Main_df
# Assembles Main_df from Meteo_df/Energy_Prices_df (real input
# dataframes) and System_df/Flexibility_actions_df/
# Meteo_transformations_df (synthetic dataframes), and validates its
# structure before any parameter is loaded on top of it.
# Steps:
#   6. Assemble Main_df
#   7. Validate Main_df
# -------------------------------------------------------------
{
  # -------------------------------------------------------------
  # 6. Assemble Main_df
  # -------------------------------------------------------------
  # assemble_main_df.R is sourced to load Meteo_df/Energy_Prices_df
  # and build the synthetic dataframes, assembling all of them into
  # Main_df on the common master grid defined by
  # parameters$computing$main_resolution_sec.
  source(file.path("30_Simulation", "04_Scripts", "assemble_main_df.R"))

  Main_df$Occupancy  <- 0L
  Main_df$Scheduling <- 0L

  # -------------------------------------------------------------
  # 7. Validate Main_df
  # -------------------------------------------------------------
  # validate_Main_df is called to check that the freshly assembled
  # Main_df has the expected structure (columns, types) and that its
  # columns stay inside the plausibility bounds of
  # Validation_bounding_simulation.csv, before any parameter is
  # loaded on top of it.
  validate_Main_df(Main_df, bounding_validation_config)
}

# -------------------------------------------------------------
# C. Parameters
# Loads every configuration file of 02_Config, one loader per file,
# in the order of their numbers. The loading dependencies hold in this
# order: Market is loaded after Control and Optimization, and the
# files that complete Control and Reward after them. Once the forecast
# parameters are loaded, T_ext_24h of Main_df is recalculated, since
# it needs their default value.
# Steps:
#   8. Optimization parameters
#   9. Control
#   10. Market configuration
#   11. Market configuration, scheduling
#   12. Market configuration, piloting
#   13. Energy price parameters
#   14. Flexibility price emulation
#   15. Flexibility event configuration
#   16. Reward parameters
#   17. Operational temperature corrections
#   18. Model parameters
#   19. Temperature setpoints
#   20. Modes setpoints
#   21. Use patterns
#   22. Forecast parameters
#   23. Recalculate T_ext_24h
# -------------------------------------------------------------
{
  # -------------------------------------------------------------
  # 8. Optimization parameters
  # -------------------------------------------------------------
  # load_01_optimization_parameters.R is sourced to load and validate
  # 01_Optimization_parameters.csv into parameters$optimization.
  source(file.path("30_Simulation", "04_Scripts", "load_01_optimization_parameters.R"))

  # -------------------------------------------------------------
  # 9. Control
  # -------------------------------------------------------------
  # load_02_control.R is sourced to load and validate 02_Control.csv
  # into parameters$control: the control parameters that apply whatever
  # control_type is chosen.
  source(file.path("30_Simulation", "04_Scripts", "load_02_control.R"))

  # -------------------------------------------------------------
  # 10. Market configuration
  # -------------------------------------------------------------
  # load_03_market_config.R is sourced to load 03_Market_config.csv
  # into parameters$market; it needs parameters$control and
  # parameters$optimization, both already loaded above.
  source(file.path("30_Simulation", "04_Scripts", "load_03_market_config.R"))

  # -------------------------------------------------------------
  # 11. Market configuration, scheduling
  # -------------------------------------------------------------
  # load_04_market_config_scheduling.R is sourced to load and validate
  # 04_Market_config_scheduling.csv into parameters$market_config_scheduling.
  source(file.path("30_Simulation", "04_Scripts", "load_04_market_config_scheduling.R"))

  # -------------------------------------------------------------
  # 12. Market configuration, piloting
  # -------------------------------------------------------------
  # load_05_market_config_piloting.R is sourced to load and validate
  # 05_Market_config_piloting.csv into parameters$market_config_piloting.
  source(file.path("30_Simulation", "04_Scripts", "load_05_market_config_piloting.R"))

  # -------------------------------------------------------------
  # 13. Energy price parameters
  # -------------------------------------------------------------
  # load_06_energy_price_parameters.R is sourced to load and validate
  # 06_Energy_price_parameters.csv into parameters$energy_price.
  source(file.path("30_Simulation", "04_Scripts", "load_06_energy_price_parameters.R"))

  # -------------------------------------------------------------
  # 14. Flexibility price emulation
  # -------------------------------------------------------------
  # load_07_flexibility_price_emulation.R is sourced to load and validate
  # 07_Flexibility_price_emulation_parameters.csv into
  # parameters$flexibility_price_emulation.
  source(file.path("30_Simulation", "04_Scripts", "load_07_flexibility_price_emulation.R"))

  # -------------------------------------------------------------
  # 15. Flexibility event configuration
  # -------------------------------------------------------------
  # load_08_flexibility_event_configuration.R is sourced to add the
  # parameters of 08_Flexibility_Event_Configuration.csv, which define
  # the flexibility events, to parameters$control.
  source(file.path("30_Simulation", "04_Scripts", "load_08_flexibility_event_configuration.R"))

  # -------------------------------------------------------------
  # 16. Reward parameters
  # -------------------------------------------------------------
  # load_09_reward_parameters.R is sourced to load and validate
  # 09_Reward_parameters.csv into parameters$reward.
  source(file.path("30_Simulation", "04_Scripts", "load_09_reward_parameters.R"))

  # -------------------------------------------------------------
  # 17. Operational temperature corrections
  # -------------------------------------------------------------
  # load_10_operational_temperature_corrections.R is sourced to load
  # the corrections of the reference temperature curves, from
  # 10_Operational_temperature_corrections.csv, into
  # parameters$operational_temperature_corrections.
  source(file.path("30_Simulation", "04_Scripts", "load_10_operational_temperature_corrections.R"))

  # -------------------------------------------------------------
  # 18. Model parameters
  # -------------------------------------------------------------
  # load_11_model_parameters.R is sourced to load 11_Model_parameters.csv
  # into parameters$model; it needs parameters$physical_properties,
  # already loaded above, to compute Rvent.
  source(file.path("30_Simulation", "04_Scripts", "load_11_model_parameters.R"))

  # -------------------------------------------------------------
  # 19. Temperature setpoints
  # -------------------------------------------------------------
  # load_12_temperature_setpoints.R is sourced to add the setpoint
  # ranges of 12_Temperature_Setpoints.csv to parameters$control.
  source(file.path("30_Simulation", "04_Scripts", "load_12_temperature_setpoints.R"))

  # -------------------------------------------------------------
  # 20. Modes setpoints
  # -------------------------------------------------------------
  # load_13_modes_setpoints.R is sourced to load and validate
  # 13_Modes_setpoints.csv into parameters$setpoint_modes.
  source(file.path("30_Simulation", "04_Scripts", "load_13_modes_setpoints.R"))

  # -------------------------------------------------------------
  # 21. Use patterns
  # -------------------------------------------------------------
  # load_14_use_patterns.R is sourced to load and validate
  # 14_Use_Patterns.csv into parameters$use_patterns.
  source(file.path("30_Simulation", "04_Scripts", "load_14_use_patterns.R"))

  # -------------------------------------------------------------
  # 22. Forecast parameters
  # -------------------------------------------------------------
  # load_15_forecast_parameters.R is sourced to load and validate
  # 15_Forecast_parameters.csv into parameters$forecast.
  source(file.path("30_Simulation", "04_Scripts", "load_15_forecast_parameters.R"))

  # -------------------------------------------------------------
  # 23. Recalculate T_ext_24h
  # T_ext_24h is set to the mean Text of the previous calendar day.
  # The first day has no previous day and takes t_ext_24h_default,
  # from 15_Forecast_parameters.csv, loaded in step 22.
  # -------------------------------------------------------------
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
  rm(validation_config, market_config_validation_config,
     bounding_validation_config)
}
