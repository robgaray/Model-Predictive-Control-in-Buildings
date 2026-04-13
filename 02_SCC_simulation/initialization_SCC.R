# -------------------------------------------------------------
# Script: initialization_SCC.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Location: 02_SCC_simulation/initialization_SCC.R
# -------------------------------------------------------------
# This script performs the initialization phase of the MPC simulation
# for supercomputer cluster (SCC) environments. It is sourced from
# Main_SCC.R and performs the following steps:
#   1. Cleans and resets the environment
#   2. Sets global configuration options
#   3. Initialises file directory paths (including local library path)
#   4. Validates required files and directories
#   5. Loads libraries from local 00_Libraries directory and functions
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
  
  data_path       <- file.path(WD, "01_Simulation", "01_Data")
  config_path     <- file.path(WD, "01_Simulation", "02_Config")
  functions_path  <- file.path(WD, "01_Simulation", "03_Functions")
  scripts_path    <- file.path(WD, "01_Simulation", "04_Scripts")
  library_path    <- file.path(WD, "00_Libraries")
  output_path     <- file.path(WD, "01_Simulation", "90_Output")
  
  main_file               <- file.path(data_path, "Main_df.rds")
  library_file            <- file.path(config_path, "libraries.txt")
  needed_cols_file        <- file.path(config_path, "needed_cols.txt")
  model_file              <- file.path(config_path, "model_parameters.csv")
  reward_file             <- file.path(config_path, "reward_parameters.csv")
  control_file            <- file.path(config_path, "control_parameters.csv")
  setpoint_mode_file      <- file.path(config_path, "setpoint_modes.csv")
  optimization_file       <- file.path(config_path, "optimization_parameters.csv")
  forecast_file           <- file.path(config_path, "forecast_parameters.csv")
  debug_and_config_file   <- file.path(config_path, "debug_and_config.csv")
  flex_price_sim_file     <- file.path(config_path, "flex_price_simulation.csv")
  
  rm(WD, scripts_path)
}

# -----------------------------------------------------------
# Validate required files and directories
# -----------------------------------------------------------
{
  required_paths <- c(data_path, config_path, functions_path, library_path)
  missing_paths  <- required_paths[!dir.exists(required_paths)]
  
  if (length(missing_paths) > 0) {
    stop("Missing required directories:\n", paste(missing_paths, collapse = "\n"))
  }
  
  required_files <- c(main_file,
                      library_file,
                      needed_cols_file,
                      model_file,
                      control_file,
                      setpoint_mode_file,
                      optimization_file,
                      debug_and_config_file,
                      flex_price_sim_file
  )
  
  missing_files <- required_files[!file.exists(required_files)]
  
  if (length(missing_files) > 0) {
    stop("Missing required files:\n", paste(missing_files, collapse = "\n"))
  }
  
  cat("All required files and directories validated\n")
  rm(required_paths, missing_paths, required_files, missing_files, data_path, config_path)
}

# -----------------------------------------------------------
# Loading of libraries and functions
# (libraries loaded from local 00_Libraries directory)
# Critical: 00_Libraries must be placed first in .libPaths()
# BEFORE any library() call, to ensure locally installed
# package versions (e.g. cli) take precedence over system
# versions pre-loaded by the R module on the SCC.
# -----------------------------------------------------------
{
  # Place local library first in the search path before any package is loaded.
  # This is required on SCC environments where the R module may pre-load
  # outdated package versions (e.g. cli 3.3.0) that conflict with
  # dependencies of packages such as tidyr (which requires cli >= 3.6.1).
  .libPaths(c(library_path, .libPaths()))
  
  source(file.path(functions_path, "initialization.R"))
  initialization(library_file, functions_path, lib_path = library_path)
  
  cat("libraries loaded\n")
  cat("functions loaded\n")
  rm(library_file, functions_path)
}
