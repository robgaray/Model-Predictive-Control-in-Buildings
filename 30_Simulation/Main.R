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
# 3. Climate priority (before subsetting, needs full-year trailing averages)
# 4. Subset Main_df by month / period
# 5. Initialise market columns in Main_df
# 6. Flexibility generation (conditional)
# 7. Energy/flexibility price signals (buy/sell derivation)
# 8. Generate occupancy profiles
# 9. Generate scheduling profiles
# 10. Build future-horizon price matrices
# 11. Initialise market output matrices (market commitments)
# 12. Initialise the economic analysis accumulators
# 13. Reference temperature profiles
# 14. Perform simulation (calls to external script)
# 15. Complete the economic analysis (execution phase and fractions)
# 16. Export results to files
# -------------------------------------------------------------

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Initialization
# -------------------------------------------------------------
# no need to look inside
# initialization.R is sourced first to reset the environment, set the
# file paths list (paths), load libraries and every project function,
# and compile the C++ simulation module - all prerequisites for
# everything that follows.
source(file.path("30_Simulation", "04_Scripts", "initialization.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Data & model parameters, control, optimization and market parameters
# -------------------------------------------------------------
# THIS IS THE PLACE TO CHANGE PARAMETERS
# Inspect & change the parameter files OR override the
# parameters after they are loaded
# -------------------------------------------------------------
# load_all_parameters.R is sourced to assemble Main_df (from
# Meteo_df/Energy_Prices_df plus the synthetic dataframes) and to load
# every parameter sub-list (model, control, optimization, market,
# reward, forecast, etc.) from the 02_Config CSV files.
source(file.path("30_Simulation", "04_Scripts", "load_all_parameters.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Climate Priority
# -------------------------------------------------------------
# Runs before the month/period subset (like T_ext_24h in
# load_all_parameters.R) so that HDD_period/CDD_period trailing
# averages have access to the full year, not just whatever remains
# after subsetting. Otherwise, the first HDD_period/CDD_period days of
# a subset range would have no prior data to average and would fall
# back to "Intermediate" regardless of season.
# -------------------------------------------------------------
source(file.path("30_Simulation", "04_Scripts", "climate_priority.R"))

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
# market_columns_setup.R is sourced to fill in the Sched_*/Pilot_*
# market-timeline columns of Main_df (market name, bid time, period
# bounds, optimization horizon, aim), in either basic or complex mode,
# so the simulation loop can later tell when each market clears.
source(file.path("30_Simulation", "04_Scripts", "market_columns_setup.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Flexibility generation
# -------------------------------------------------------------
# Only executed when parameters$debug_and_config$Price_emulation == 1
# Overwrites flex price columns in Main_df with generated values, using
# either the basic per-day algorithm or the market-aware algorithm
# (Complex_Market_Config), both based on the Market configuration
# parameters (15_Market_config.csv / 22_Flexibility_generation_parameters.csv)
# -------------------------------------------------------------
if (parameters$debug_and_config$Price_emulation == 1) {
  source(file.path("30_Simulation", "04_Scripts", "flexibility_generation.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Energy/flexibility price signals (buy/sell derivation)
# -------------------------------------------------------------
# Derives the twelve buy/sell price signals consumed by the rest of
# the market/reward pipeline from the six legacy signals above. See
# 30_Simulation/04_Scripts/energy_price_signals_setup.R header.
# -------------------------------------------------------------
source(file.path("30_Simulation", "04_Scripts", "energy_price_signals_setup.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
### Generate Occupancy Profiles
# -------------------------------------------------------------
# generate_occupancy_profiles.R is sourced to derive Main_df$Occupancy
# for every timestamp from parameters$use_patterns (month/weekday/hour
# lookup), needed before the Scheduling profile and the reference
# temperature profiles can be computed.
source(file.path("30_Simulation", "04_Scripts", "generate_occupancy_profiles.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
### Generate Scheduling Profiles
# -------------------------------------------------------------
# generate_scheduling_profiles.R is sourced to derive
# Main_df$Scheduling from Main_df$Occupancy and the anticipation
# parameters, marking the pre/post-occupancy windows used by the
# reference temperature profiles below.
source(file.path("30_Simulation", "04_Scripts", "generate_scheduling_profiles.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
### Setup full market information (price matrices)
# -------------------------------------------------------------
# full_market_information_setup.R is sourced to build the
# future-horizon energy/flexibility price matrices (one row per
# market event, one column per future step) that the Scheduling and
# Piloting processes will look up during the simulation loop.
source(file.path("30_Simulation", "04_Scripts", "full_market_information_setup.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
### Setup market commitments (output matrices)
# -------------------------------------------------------------
# market_commitments_setup.R is sourced to initialise the twelve
# market_commitments output matrices (energy buy/sell/net, their
# _flex counterparts, the four explicit-flexibility buy/sell
# matrices, and the two cost commitments, per market event), which
# the simulation loop will accumulate into as each Scheduling/Piloting
# market is executed.
source(file.path("30_Simulation", "04_Scripts", "market_commitments_setup.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
### Setup economic analysis accumulators
# -------------------------------------------------------------
# economic_analysis_setup.R is sourced to build the empty economic_analysis
# list (the market and slot tables), which the simulation loop fills in as each
# Scheduling and Piloting market trades, and which economic_analysis_finalize.R
# completes with the execution phase once the loop is over.
source(file.path("30_Simulation", "04_Scripts", "economic_analysis_setup.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
### Reference temperature profiles
# -------------------------------------------------------------
# reference_temperature_profiles.R is sourced to compute the
# Service_T_*/Scheduling_T_* comfort setpoint bands from Occupancy,
# Scheduling and Overall_Climate, needed by the reward function during
# the simulation loop.
source(file.path("30_Simulation", "04_Scripts", "reference_temperature_profiles.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Simulation
# -------------------------------------------------------------
# simulation.R is sourced to run the main MPC simulation loop itself
# (Scheduling, Piloting and Execution processes for every row of
# Main_df), using every dataframe/parameter set assembled above.
source(file.path("30_Simulation", "04_Scripts", "simulation.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Economic analysis
# -------------------------------------------------------------
# economic_analysis_finalize.R is sourced to add the execution phase to the
# economic_analysis tables and to derive the reported fractions, giving the
# global economic picture (per market and per market slot) that the
# individual commitment and price matrices do not provide on their own.
source(file.path("30_Simulation", "04_Scripts", "economic_analysis_finalize.R"))

# -------------------------------------------------------------
# -------------------------------------------------------------
#### Data outputs
# -------------------------------------------------------------
# data_outputs.R is sourced as the final step, to export Main_df and
# the synthesized summary data frame to CSV/RDS files under
# paths$output_path.
source(file.path("30_Simulation", "04_Scripts", "data_outputs.R"))
