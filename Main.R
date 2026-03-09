# -------------------------------------------------------------
# Script: Main.R
# Script to test a Model Predictive Control in buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This script performs a simulation of a Model Predictive
# Control (MPC) #   strategy applied to building energy
# management. It loads the necessary model parameters, control
# settings, and optimization parameters, then runs the
# simulation and exports the results.
# -------------------------------------------------------------
# The building
# The building is modeled using a simplified thermal model with
# parameters defined in external configuration files. The model
# includes thermaldynamics, HVAC system characteristics, and
# occupant comfort settings.
# The relevant file for this is "model_parameters.csv".
# -------------------------------------------------------------
# Control Strategy
# The control strategy can be based on either fixed setpoints
# or predefined modes.
# The optimizer will select the best control actions within
# a set of modes (discrete options) or a set of setpoints
# (real-values) as per the selected control option.
# The control parameters are defined in "control_parameters.csv"
# and "setpoint_modes.csv".
# -------------------------------------------------------------
# Weather forecast
# MPC requires a forecast of the contextual information. In
# this case, the weather forecats. Here, two options are
# considered:
#   1. Inaccurate forecast: The forecast has some errors
#      compared to the actual weather conditions.
#   2. Accurate forecast: The forecast matches the actual
#      weather conditions perfectly.
# MPC is executed with either of these options but then the
# "optimal" control actions are applied to the real building
# model with the actual weather conditions.
# The forecast parameters for the inaccurate forecast are
# defined in "forecast_parameters.csv".
# -------------------------------------------------------------
# Optimal criteria (reward)
# The optimization aims to maximize a reward function that
# balances energy costs and occupant comfort. The reward
# parameters are defined in "reward_parameters.csv".
# -------------------------------------------------------------
# Code outline
# 1. Initialization
# 2. Load data and model parameters
# 3. Load control and optimization parameters
#    It is recommended to change parameters in the external
#    files, but an expert user could override them here.
# 4. Perform simulation (calls to external script)
# 5. Export results to files
# -------------------------------------------------------------

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Initialization
# -------------------------------------------------------------
# no need to look inside
{
  # -----------------------------------------------------------
  # Global configuration
  # -----------------------------------------------------------
  {
    options(stringsAsFactors = FALSE)
    start_time_global <- Sys.time()
    cat("Script started at:", format(start_time_global), "\n")
  }
  
  # -----------------------------------------------------------
  # Cleaning and reset of the environment
  # -----------------------------------------------------------
  {
    rm(list = ls())
    gc()
  }
  
  # -----------------------------------------------------------
  # Initialisation of the file directory
  # -----------------------------------------------------------
  {
    WD <- getwd()
    
    data_path       <- file.path(WD, "01_Simulation", "01_Data")
    config_path     <- file.path(WD, "01_Simulation", "02_config_files")
    functions_path  <- file.path(WD, "01_Simulation", "03_Functions")
    scripts_path    <- file.path(WD, "01_Simulation", "04_Scripts") 
    # library_path    <- file.path(WD, "01_Simulation", "00_Libraries")
    # reserved for SCC case
    output_path     <- file.path(WD, "01_Simulation", "05_Output")
    
    main_file          <- file.path(data_path, "Main_df.rds")
    library_file       <- file.path(config_path, "libraries.txt")
    model_file         <- file.path(config_path, "model_parameters.csv")
    reward_file        <- file.path(config_path, "reward_parameters.csv")
    control_file       <- file.path(config_path, "control_parameters.csv")
    setpoint_mode_file <- file.path(config_path, "setpoint_modes.csv")
    optimization_file  <- file.path(config_path, "optimization_parameters.csv")
    forecast_file      <- file.path(config_path, "forecast_parameters.csv")
    
    simulation_script  <- file.path(scripts_path, "simulation.R")
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
    
    required_files <- c(main_file,
                        library_file,
                        model_file,
                        control_file,
                        setpoint_mode_file,
                        optimization_file
    )
    
    missing_files <- required_files[!file.exists(required_files)]
    
    if (length(missing_files) > 0) {
      stop("Missing required files:\n", paste(missing_files, collapse = "\n"))
    }
    
    cat("All required files and directories validated\n")
  }
  
  # -----------------------------------------------------------
  # Loading of libraries and functions
  # -----------------------------------------------------------
  {
    source(file.path(functions_path, "initialization.R"))
    initialization(library_file, functions_path)
    
    cat("libraries loaded\n")
    cat("functions loaded\n")
  }
}

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Data & model parameters
# -------------------------------------------------------------
# no need to look inside unless you want to modify the physical model
{
  result <- load_data_model_parameters(main_file, model_file,
                                       reward_file, forecast_file)
  Main_df             <- result$Main_df
  model_parameters    <- result$model_parameters
  reward_parameters   <- result$reward_parameters
  forecast_parameters <- result$forecast_parameters
  forecast_type       <- result$forecast_type
  parameters          <- result$parameters
}

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Control and optimization parameters
# -------------------------------------------------------------
# THIS IS THE PLACE TO CHANGE PARAMETERS
# Inspect & change the parameter files OR override the
# parameters after they are loaded
{
  result <- load_control_optimization_parameters(control_file,
                                                  setpoint_mode_file,
                                                  optimization_file,
                                                  Main_df)
  control_type            <- result$control_type
  Deadband                <- result$Deadband
  optimization_parameters <- result$optimization_parameters
  verbose                 <- result$verbose
  month_subset            <- result$month_subset
  period_subset           <- result$period_subset
  Main_df                 <- result$Main_df

  if (!is.null(result$set_point_range_heating)) {
    set_point_range_heating <- result$set_point_range_heating
    set_point_range_cooling <- result$set_point_range_cooling
  }
  if (!is.null(result$setpoint_modes)) {
    setpoint_modes <- result$setpoint_modes
  }
}

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Simulation
# -------------------------------------------------------------
source(simulation_script)

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Data outputs
# -------------------------------------------------------------
write_data_outputs(output_path, Main_df, optimization_parameters, t_process)