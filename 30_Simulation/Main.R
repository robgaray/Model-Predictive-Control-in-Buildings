# -------------------------------------------------------------
# Script: Main.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This script performs a simulation of a Model Predictive
# Control (MPC) strategy applied to building energy
# management. It loads the necessary model parameters, control
# settings, and optimization parameters, then runs the
# simulation and exports the results.
# -------------------------------------------------------------
# The MPC concept
# A model is used to set the control criteria over a long-term horizon.
# Typical control horizon is in the range of 24 hours.
# -------------------------------------------------------------
# The aim of the optimization
# Depending on the selected configuration, the MPC is set to optimize
# the energy consumption over the control horizon, or even to deliver
# flexibility to the grid.
# -------------------------------------------------------------
# The Building
# The building is modeled using a simplified thermal model with
# parameters defined in external configuration files. The model
# includes thermal dynamics, HVAC system characteristics, and
# occupant comfort settings.
# The relevant file for this is "11_Model_parameters.csv".
# -------------------------------------------------------------
# Control Strategy
# The control strategy can be based on either fixed setpoints
# or predefined modes.
# The optimizer will select the best control actions within
# a set of modes (discrete options) or a set of setpoints
# (real-values) as per the selected control option.
# The control parameters are defined in "12_Control_parameters.csv"
# and "13_Modes_setpoints.csv".
# -------------------------------------------------------------
# Weather forecast
# MPC requires a forecast of the contextual information. In
# this case, the weather forecast. Here, two options are
# considered:
#   1. Inaccurate forecast: The forecast has some errors
#      compared to the actual weather conditions.
#   2. Accurate forecast: The forecast matches the actual
#      weather conditions perfectly.
# MPC is executed with either of these options but then the
# "optimal" control actions are applied to the real building
# model with the actual weather conditions.
# The forecast parameters for the inaccurate forecast are
# defined in "19_Forecast_parameters.csv".
# -------------------------------------------------------------
# Optimal criteria (reward)
# The optimization aims to maximize a reward function that
# balances energy costs and occupant comfort. The reward
# parameters are defined in "18_Reward_parameters.csv".
# -------------------------------------------------------------
# Code outline
# 1. Initialization
# 2. Load data and model parameters
# 3. Subset Main_df by month / period
# 4. Initialise market columns in Main_df
# 5. Price emulation (conditional)
# 6. Generate occupancy, scheduling, climate and reference
#    temperature profiles
# 7. Perform simulation (calls to external script)
# 8. Export results to files
# -------------------------------------------------------------

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Initialization
# -------------------------------------------------------------
# no need to look inside
source(file.path("30_Simulation", "04_Scripts", "initialization.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Data & model parameters, control, optimization and market parameters
# -------------------------------------------------------------
# THIS IS THE PLACE TO CHANGE PARAMETERS
# Inspect & change the parameter files OR override the
# parameters after they are loaded
# -------------------------------------------------------------
source(file.path("30_Simulation", "04_Scripts", "load_all_parameters.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Subset Main_df by month / period
# -------------------------------------------------------------
{
  month_subset  <- parameters$debug_and_config$month_subset
  period_subset <- parameters$debug_and_config$period_subset

  if (!is.null(month_subset) && month_subset != 0) {
    Main_df <- Main_df[month(Main_df$time) == month_subset, ]
    cat("Month ", month_subset, " selected\n")
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

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Initialise market columns in Main_df
# -------------------------------------------------------------
source(file.path("30_Simulation", "04_Scripts", "market_columns_setup.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Price emulation
# -------------------------------------------------------------
# Only executed when parameters$debug_and_config$Price_emulation == 1
# Overwrites flex price columns in Main_df with randomly generated values
# based on 20_Flex_price_simulation.csv
# -------------------------------------------------------------
if (parameters$debug_and_config$Price_emulation == 1) {
  source(file.path("30_Simulation", "04_Scripts", "price_emulation.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
### Generate Occupancy Profiles
# -------------------------------------------------------------
source(file.path("30_Simulation", "04_Scripts", "generate_occupancy_profiles.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
### Generate Scheduling Profiles
# -------------------------------------------------------------
source(file.path("30_Simulation", "04_Scripts", "generate_scheduling_profiles.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
### Climate Priority
# -------------------------------------------------------------
source(file.path("30_Simulation", "04_Scripts", "climate_priority.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
### Reference temperature profiles
# -------------------------------------------------------------
source(file.path("30_Simulation", "04_Scripts", "reference_temperature_profiles.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Simulation
# -------------------------------------------------------------
source(file.path("30_Simulation", "04_Scripts", "simulation.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Data outputs
# -------------------------------------------------------------
source(file.path("30_Simulation", "04_Scripts", "data_outputs.R"))
