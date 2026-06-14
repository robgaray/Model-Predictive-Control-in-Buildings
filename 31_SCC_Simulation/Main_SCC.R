# -------------------------------------------------------------
# Script: Main_SCC.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Location: 31_SCC_Simulation/Main_SCC.R
# -------------------------------------------------------------
# Overall description
# This script performs a parametric simulation of a Model Predictive
# Control (MPC) strategy applied to building energy management, adapted
# for execution on supercomputer clusters (SCC) with Slurm job arrays.
# It reads optimization parameters from command line arguments (passed
# by the Slurm job script) and overrides the corresponding values in
# the configuration file. Libraries are loaded from the local
# ./00_Libraries directory installed by Install_libraries.R.
# Output filenames include all run parameters as a suffix.
# -------------------------------------------------------------
# Command line arguments (passed by Job_array_r.sh):
#   1.  population_size
#   2.  iteration_number
#   3.  run_number
#   4.  pcrossover
#   5.  pmutation
#   6.  control_optimization_horizon
#   7.  control_implementation_horizon
#   8.  control_optimization_anticipation
#   9.  control_type
#   10. optimization_aim
#   11. flexibility_event_length_max
#   12. flexibility_recover_timespan
#   13. thermal_stabilization_timespan
#   14. minimum_flexibility
#   15. flexibility_splits
#   16. Alpha_Service_Min
#   17. month_subset
# -------------------------------------------------------------
# Code outline
# 1. Initialization (SCC: libraries from local 00_Libraries)
# 2. Load data and model parameters
# 3. Load control and optimization parameters
#    (SCC: overridden by command line arguments;
#     verbose always FALSE, parallel always 1)
# 4. Initialise market columns in Main_df
# 5. Price emulation (conditional)
# 6. Generate occupancy, scheduling, climate and reference
#    temperature profiles
# 7. Perform simulation (calls to external script)
# 8. Export results to files (SCC: filenames include run parameters)
# -------------------------------------------------------------

# -------------------------------------------------------------
# -------------------------------------------------------------
# 1. Initialization
# -------------------------------------------------------------
{
  source(file.path("31_SCC_Simulation", "initialization_SCC.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 2. Data, model, control, optimization and market parameters
# Parameters are loaded from CSV files; SCC CLI overrides applied
# in the following step.
# -------------------------------------------------------------
{
  source(file.path("30_Simulation", "04_Scripts", "load_all_parameters.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 3. SCC parameter overrides and data subsetting
# Parameters overridden by command line arguments from Optim_parameters.csv
# verbose always FALSE, parallel always 1
# -------------------------------------------------------------
{
  source(file.path("31_SCC_Simulation", "control_optimization_parameters_SCC.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 4. Initialise market columns in Main_df
# -------------------------------------------------------------
{
  source(file.path("30_Simulation", "04_Scripts", "market_columns_setup.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 5. Price emulation
# Only executed when parameters$debug_and_config$Price_emulation == 1
# Overwrites flex price columns in Main_df with randomly generated values
# based on 20_Flex_price_simulation.csv
# -------------------------------------------------------------
{
  if (parameters$debug_and_config$Price_emulation == 1) {
    source(file.path("30_Simulation", "04_Scripts", "price_emulation.R"))
  }
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 6. Generate Occupancy Profiles
# -------------------------------------------------------------
{
  source(file.path("30_Simulation", "04_Scripts", "generate_occupancy_profiles.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 7. Generate Scheduling Profiles
# -------------------------------------------------------------
{
  source(file.path("30_Simulation", "04_Scripts", "generate_scheduling_profiles.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 8. Climate Priority
# -------------------------------------------------------------
{
  source(file.path("30_Simulation", "04_Scripts", "climate_priority.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 9. Reference temperature profiles
# -------------------------------------------------------------
{
  source(file.path("30_Simulation", "04_Scripts", "reference_temperature_profiles.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 10. Simulation
# -------------------------------------------------------------
{
  source(file.path("30_Simulation", "04_Scripts", "simulation.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 11. Data outputs
# Output filenames include all run parameters as suffix
# -------------------------------------------------------------
{
  source(file.path("31_SCC_Simulation", "data_outputs_SCC.R"))
}
