# -------------------------------------------------------------
# Script: Main_SCC.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Location: 02_SCC_simulation/Main_SCC.R
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
#   16. Alpha_confort
#   17. month_subset
# -------------------------------------------------------------
# Code outline
# 1. Initialization (SCC: libraries from local 00_Libraries)
# 2. Load data and model parameters
# 3. Load control and optimization parameters
#    (SCC: overridden by command line arguments;
#     verbose always FALSE, parallel always 1)
# 4. Perform simulation (calls to external script)
# 5. Export results to files (SCC: filenames include run parameters)
# -------------------------------------------------------------

# -------------------------------------------------------------
# -------------------------------------------------------------
# 1. Initialization
# -------------------------------------------------------------
{
  source(file.path("02_SCC_simulation", "initialization_SCC.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 2. Data & model parameters
# -------------------------------------------------------------
{
  source(file.path("01_Simulation", "04_Scripts", "data_model_parameters.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 3. Control and optimization parameters
# Parameters overridden by command line arguments from Optim_parameters.csv
# verbose always FALSE, parallel always 1
# -------------------------------------------------------------
{
  source(file.path("02_SCC_simulation", "control_optimization_parameters_SCC.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 4. Price emulation
# Only executed when parameters$debug_and_config$Price_emulation == 1
# Overwrites flex price columns in Main_df with randomly generated values
# based on flex_price_simulation.csv
# -------------------------------------------------------------
{
  if (parameters$debug_and_config$Price_emulation == 1) {
    source(file.path("01_Simulation", "04_Scripts", "price_emulation.R"))
  }
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 5. Simulation
# -------------------------------------------------------------
{
  source(file.path("01_Simulation", "04_Scripts", "simulation.R"))
}

# -------------------------------------------------------------
# -------------------------------------------------------------
# 6. Data outputs
# Output filenames include all run parameters as suffix
# -------------------------------------------------------------
{
  source(file.path("02_SCC_simulation", "data_outputs_SCC.R"))
}
