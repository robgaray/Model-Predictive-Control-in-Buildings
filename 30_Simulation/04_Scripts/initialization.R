# -------------------------------------------------------------
# Script: initialization.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This script performs the initialization phase of the MPC simulation.
# It is sourced from Main.R and performs the following steps:
#   1. Cleans and resets the environment
#   2. Sets global configuration options
#   3. Initialises file directory paths
#   4. Validates required files and directories
#   5. Loads libraries and functions
# -------------------------------------------------------------
# Inputs
# (none) - this script initializes the environment from scratch.
# -------------------------------------------------------------
# Outputs
# functions_path : Character. Path to the functions directory.
# paths : List. Paths to all required data/config files used by Main.R
# and sourced scripts (e.g., paths$control_file, paths$output_path).
# -------------------------------------------------------------
# Code outline
# 1. Clean environment
# 2. Set global configuration
# 3. Initialize file paths
# 4. Validate required files and directories
# 5. Load libraries and functions
# -------------------------------------------------------------
# Usage
# source(file.path("30_Simulation", "04_Scripts", "initialization.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by Main.R as the first step.
# -------------------------------------------------------------
# functions/scripts called
# initialization() from 30_Simulation/03_Functions/initialization.R
# -------------------------------------------------------------

# -----------------------------------------------------------
# Cleaning and reset of the environment
# -----------------------------------------------------------
{
  rm(list = ls())
  gc()
}

# -----------------------------------------------------------
# Global configuration
# -----------------------------------------------------------
{
  options(stringsAsFactors = FALSE)
}

# -----------------------------------------------------------
# Initialisation of the file directory
# -----------------------------------------------------------
{
  WD <- getwd()
  
  data_path       <- file.path(WD, "30_Simulation", "01_Data")
  config_path     <- file.path(WD, "30_Simulation", "02_Config")
  functions_path  <- file.path(WD, "30_Simulation", "03_Functions")
  # library_path    <- file.path(WD, "30_Simulation", "00_Libraries")
  # reserved for SCC case
  
  paths <- list(
    output_path                 = file.path(WD, "30_Simulation", "90_Output"),
    main_file                   = file.path(data_path, "Main_df.rds"),
    library_file                = file.path(config_path, "01_Libraries.txt"),
    needed_cols_file            = file.path(config_path, "02_Needed_cols.csv"),
    model_file                  = file.path(config_path, "11_Model_parameters.csv"),
    physical_properties_file    = file.path(config_path, "03_Physical_properties.csv"),
    use_patterns_file           = file.path(config_path, "04_Use_Patterns.csv"),
    reward_file                 = file.path(config_path, "18_Reward_parameters.csv"),
    control_file                = file.path(config_path, "12_Control_parameters.csv"),
    setpoint_mode_file          = file.path(config_path, "13_Modes_setpoints.csv"),
    optimization_file           = file.path(config_path, "14_Optimization_parameters.csv"),
    market_file                 = file.path(config_path, "15_Market_config.csv"),
    market_config_scheduling_file = file.path(config_path, "16_Market_config_scheduling.csv"),
    market_config_piloting_file   = file.path(config_path, "17_Market_config_piloting.csv"),
    forecast_file               = file.path(config_path, "19_Forecast_parameters.csv"),
    debug_and_config_file       = file.path(config_path, "30_Debug_and_config.csv"),
    flex_price_sim_file         = file.path(config_path, "20_Flex_price_simulation.csv"),
    parameter_validation_file   = file.path(config_path, "00_Validation", "Parameter_config.csv")
  )

  rm(WD)
}

# -----------------------------------------------------------
# Validate required files and directories
# -----------------------------------------------------------
{
  required_paths <- c(data_path, config_path, functions_path)
  missing_paths  <- required_paths[!dir.exists(required_paths)]
  
  if (length(missing_paths) > 0) {
    stop("Missing required directories:\n", paste(missing_paths, collapse = "\n"))
  }
  
  required_files <- unlist(paths[names(paths) != "output_path"], use.names = FALSE)
  
  missing_files <- required_files[!file.exists(required_files)]
  
  if (length(missing_files) > 0) {
    stop("Missing required files:\n", paste(missing_files, collapse = "\n"))
  }
  
  cat("All required files and directories validated\n")
  rm(required_paths, missing_paths, required_files, missing_files, data_path, config_path)
}

# -----------------------------------------------------------
# Loading of libraries and functions
# -----------------------------------------------------------
{
  source(file.path(functions_path, "initialization.R"))
  initialization(paths$library_file, functions_path)
  
  cat("libraries loaded\n")
  cat("functions loaded\n")
  rm(functions_path)
}
