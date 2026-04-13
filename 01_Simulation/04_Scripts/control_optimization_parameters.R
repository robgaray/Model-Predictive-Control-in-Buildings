# -------------------------------------------------------------
# Script: control_optimization_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This script loads the control and optimization parameters.
# It is sourced from Main.R.
# THIS IS THE PLACE TO CHANGE PARAMETERS
# Inspect & change the parameter files OR override the
# parameters after they are loaded.
# -------------------------------------------------------------
# Inputs
# parameters : List. Must contain model, reward, forecast sub-lists.
# control_file, setpoint_mode_file, optimization_file,
# debug_and_config_file : Character. Config file paths.
# Main_df : Data frame. The main simulation data frame.
# -------------------------------------------------------------
# Outputs
# parameters : List. Updated with control, optimization, debug_and_config sub-lists.
# Main_df : Data frame. Potentially subsetted by month/period.
# -------------------------------------------------------------
# Code outline
# 1. Load and configure control parameters (setpoints/modes)
# 2. Configure optimization aim (energy/flexibility)
# 3. Load optimization parameters
# 4. Load debug and configuration parameters
# 5. Subset data frame by month/period if configured
# -------------------------------------------------------------
# Usage
# source(file.path("01_Simulation", "04_Scripts", "control_optimization_parameters.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by Main.R after data_model_parameters.R.
# -------------------------------------------------------------
# functions/scripts called
# load_control_parameters(), load_optimization_parameters(),
# load_debug_and_config_parameters() from 01_Simulation/03_Functions/
# -------------------------------------------------------------

# -----------------------------------------------------------
# Setpoint parameters
# -----------------------------------------------------------
{
  parameters$control <- load_control_parameters(control_file)
  rm(control_file)
  parameters$control$control_type <- ifelse(parameters$control$control_type == 1, "modes", "setpoint")
  
  if (is.null(parameters$control$Deadband)) stop("Deadband not found in control parameters")
  
  # Default setpoints (used when no prior control strategy exists)
  
  if (parameters$control$control_type == "modes") {
    parameters$setpoint_modes <- read.csv(setpoint_mode_file, comment.char = "#")
  }
  
  # Optimization aim (1: energy, 2: flexibility)
  if (is.null(parameters$control$optimization_aim) || 
      !parameters$control$optimization_aim %in% c(1, 2)) {
    stop("optimization_aim must be 1 (energy) or 2 (flexibility)")
  }
  
  parameters$control$optimization_aim <- ifelse(parameters$control$optimization_aim == 1, "energy", "flexibility")
  
  # TODO: temporary implementation - update for all conditions when flexibility
  #       mode is fully integrated with all control_type variants
  if (parameters$control$optimization_aim == "flexibility") {
    parameters$control$control_type  <- "modes"
    parameters$forecast$forecast_type <- "accurate"
    if (is.null(parameters$setpoint_modes)) {
      parameters$setpoint_modes <- read.csv(setpoint_mode_file, comment.char = "#")
    }
  }
  rm(setpoint_mode_file)
  
  cat("setpoint ranges loaded\n")
  cat("optimization aim:", parameters$control$optimization_aim, "\n")
}

# -----------------------------------------------------------
# Optimization parameters
# -----------------------------------------------------------
{
  parameters$optimization <- load_optimization_parameters(optimization_file)
  rm(optimization_file)
  
  # TODO: temporary implementation - update for all conditions when flexibility
  #       mode is fully integrated with all control_type variants
  if (parameters$control$optimization_aim == "flexibility") {
    parameters$optimization$control_optimization_horizon    <- 24
    parameters$optimization$control_implementation_horizon  <- 24
    parameters$optimization$control_optimization_anticipation <- 0
  }
  
  # Check market resolution consistency
  if ((parameters$optimization$control_optimization_horizon * 60) %%
      parameters$optimization$market_resolution != 0) {
    stop("control_optimization_horizon must be divisible by market_resolution")
  }
  
  str(parameters$optimization)
  cat("optimization parameters loaded\n")
}

# -----------------------------------------------------------
# Debug and configuration parameters
# -----------------------------------------------------------
{
  parameters$debug_and_config <- load_debug_and_config_parameters(debug_and_config_file)
  rm(debug_and_config_file)
}

# -----------------------------------------------------------
# subset dataframe by month
# -----------------------------------------------------------
{
  month_subset  <- parameters$debug_and_config$month_subset
  period_subset <- parameters$debug_and_config$period_subset # in timesteps
  
  if (!is.null(month_subset) && month_subset != 0) {
    Main_df <- Main_df[month(Main_df$time) == month_subset, ]
    cat("Month ", month_subset," selected\n")
  } else {
    cat("Full year selected\n")
  }
  
  if (!is.null(period_subset) && period_subset > nrow(Main_df)) {
    period_subset <- nrow(Main_df)
  }
  
  if (!is.null(period_subset) && period_subset != 0) {
    Main_df <- Main_df[1:period_subset, ]
  }
  rm(month_subset, period_subset)
}
