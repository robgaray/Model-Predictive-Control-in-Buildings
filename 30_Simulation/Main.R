# -------------------------------------------------------------
# Script: Main.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Entry point of the simulation of a Model Predictive Control (MPC)
# strategy applied to building energy management. It loads the
# simulator into an environment of its own and runs the whole
# simulation on the configuration folder of the repository. What
# the simulation does, step by step, is described in the header of
# run_simulation().
# -------------------------------------------------------------
# Inputs
#   30_Simulation/02_Config/ : every configuration file, with the
#     file names listed in 04_File_paths.csv and their validation
#     tables in 00_Validation/.
#   30_Simulation/01_Data/   : Meteo_df.rds and Energy_Prices_df.rds,
#     the input series.
# -------------------------------------------------------------
# Outputs
#   30_Simulation/90_Output/ : the output tables, each as .csv and
#   .rds, written by write_outputs():
#     - Main_df_computed
#     - <asset_id>_df_computed, one per asset
#       (Building_001_df_computed)
#     - Sinthetized_df_computed
#     - Economic_analysis_market_computed
#     - Economic_analysis_decision_computed
#     - Economic_analysis_slot_computed
#   results : List. The final results of the run, as returned by
#   run_simulation(), left in the global environment.
#   sim     : Environment. The simulator, left in the global
#   environment.
# -------------------------------------------------------------
# Code outline
# 1. Load the simulator
# 2. Run the simulation
# -------------------------------------------------------------
# Usage instructions
# From the repository root:
#   Rscript 30_Simulation/Main.R
# It is the only file of the simulation meant to be run directly.
# -------------------------------------------------------------

# -------------------------------------------------------------
# 1. Load the simulator
# -------------------------------------------------------------
{
  # initialize_simulator.R is sourced first, so that the function is
  # available to call.
  source(file.path("30_Simulation", "03_Functions", "initialize_simulator.R"))

  simulation_path <- file.path(getwd(), "30_Simulation")

  # initialize_simulator() is called to build the paths, load the
  # libraries and the functions, and compile the C++ module, all
  # into sim rather than into the global environment.
  sim <- initialize_simulator(
    simulation_path = simulation_path
  )

  # sim holds its own copy of initialize_simulator().
  rm(list = "initialize_simulator")
}

# -------------------------------------------------------------
# 2. Run the simulation
# THIS IS THE PLACE TO CHANGE THE CONFIGURATION FOLDER
# -------------------------------------------------------------
{
  # run_simulation is taken from the simulator, so that it runs with
  # the functions and the compiled module of sim.
  run_simulation <- sim$run_simulation

  # run_simulation is called to run the whole simulation on the
  # configuration folder, with no override of the parameters, on the
  # input series of 01_Data, and to write the output tables to
  # 90_Output.
  results <- run_simulation(
    config_path = file.path(simulation_path, "02_Config"),
    overrides   = NULL,
    data_path   = file.path(simulation_path, "01_Data"),
    output_path = file.path(simulation_path, "90_Output")
  )

  rm(list = c("run_simulation", "simulation_path"))
}
