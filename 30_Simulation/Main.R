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
# The control parameters are defined in:
#   - "02_Control.csv": the parameters of either control option
#   - "08_Flexibility_Event_Configuration.csv": the parameters that
#     define the flexibility events
#   - "12_Temperature_Setpoints.csv": the setpoint ranges, used by the
#     setpoints option
#   - "13_Modes_setpoints.csv": the modes, used by the modes option
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
# defined in "15_Forecast_parameters.csv".
# -------------------------------------------------------------
# Optimal criteria (reward)
# The optimization aims to maximize a reward function that
# balances energy costs and occupant comfort. The reward
# parameters are defined in "09_Reward_parameters.csv".
# -------------------------------------------------------------
# Code outline
# A. Initialization & parameter loading
#   1. Initialization
#   2. Load data and model parameters
# B. Pre-processing
#   B.1 Random seed
#     3. Fix the random seed (reproducibility of the whole run)
#   B.2 Climate and period
#     4. Climate priority (before subsetting, needs full-year trailing averages)
#     5. Subset Main_df by month / period
#   B.3 Profiles
#     6. Generate occupancy profiles
#     7. Generate scheduling profiles
#     8. Reference temperature profiles
#   B.4 Markets and prices
#     9. Initialise market columns in Main_df
#     10. Flexibility generation (conditional)
#     11. Energy/flexibility price signals (buy/sell derivation)
#     12. Build future-horizon price matrices
#     13. Initialise market output matrices (market commitments)
#     14. Initialise the economic analysis accumulators
# C. Simulation
#   15. Perform simulation (calls to external script)
# D. Post-process & Export
#   16. Complete the economic analysis (execution phase and fractions)
#   17. Export results to files
# -------------------------------------------------------------
# Inputs
#   30_Simulation/02_Config/ : every configuration file, with the file
#     names listed in 04_File_paths.csv and their validation tables in
#     00_Validation/.
#   30_Simulation/01_Data/   : Meteo_df.rds and Energy_Prices_df.rds,
#     the input series.
# -------------------------------------------------------------
# Outputs
#   30_Simulation/90_Output/ : four tables, each as .csv and .rds,
#   written by 16_data_outputs.R:
#     - Main_df_computed
#     - Sinthetized_df_computed
#     - Economic_analysis_market_computed
#     - Economic_analysis_slot_computed
# -------------------------------------------------------------
# Usage instructions
# From the repository root:
#   Rscript 30_Simulation/Main.R
# It is the only file of the simulation meant to be run directly.
# -------------------------------------------------------------
# Where this function/script is used
# Run by hand, from the repository root. Nothing in the simulation
# calls it: it is the entry point.
# -------------------------------------------------------------
# functions/scripts called
# Sourced from 30_Simulation/04_Scripts/, in this order:
#   - 01_initialization.R
#   - 02_load_all_parameters.R
#   - 03_climate_priority.R
#   - 04_subset_main_df.R
#   - 05_generate_occupancy_profiles.R
#   - 06_generate_scheduling_profiles.R
#   - 07_reference_temperature_profiles.R
#   - 08_market_columns_setup.R
#   - 09_flexibility_price_emulation.R (only when Price_emulation == 1)
#   - 10_energy_price_signals_setup.R
#   - 11_full_market_information_setup.R
#   - 12_market_commitments_setup.R
#   - 13_economic_analysis_setup.R
#   - 14_simulation.R
#   - 15_economic_analysis_finalize.R
#   - 16_data_outputs.R
# -------------------------------------------------------------

# -------------------------------------------------------------
# A. Initialization & parameter loading
# Prepares the session and everything the run reads:
#   - the environment and the paths
#   - the libraries and the project functions
#   - the C++ simulation module
#   - Main_df and every parameter sub-list
# Steps:
#   1. Initialization
#   2. Load data and model parameters
# -------------------------------------------------------------
{
  # -------------------------------------------------------------
  # 1. Initialization
  # -------------------------------------------------------------
  # no need to look inside
  # 01_initialization.R is sourced first, for the prerequisites of
  # everything that follows:
  #   - reset the environment
  #   - set the file paths list (paths)
  #   - load the libraries and every project function
  #   - compile the C++ simulation module
  source(file.path("30_Simulation", "04_Scripts", "01_initialization.R"))

  # -------------------------------------------------------------
  # 2. Load data and model parameters
  # -------------------------------------------------------------
  # THIS IS THE PLACE TO CHANGE PARAMETERS
  # Inspect & change the parameter files OR override the
  # parameters after they are loaded
  # -------------------------------------------------------------
  # 02_load_all_parameters.R is sourced to:
  #   - assemble Main_df, from Meteo_df and Energy_Prices_df plus the
  #     synthetic dataframes
  #   - load every parameter sub-list from the 02_Config CSV files
  #     (see 02_load_all_parameters.R for the full list)
  source(file.path("30_Simulation", "04_Scripts", "02_load_all_parameters.R"))
}

# -------------------------------------------------------------
# B. Pre-processing
# Turns the loaded data into what the simulation loop needs:
#   - a fixed random seed
#   - the climate priority and the subset of the period
#   - the occupancy and scheduling profiles, and the reference
#     temperatures derived from them
#   - the market timeline, the price signals, the future-horizon
#     price matrices and the empty commitment and economic
#     accumulators
# Steps:
#   B.1 Random seed
#     3. Fix the random seed (reproducibility of the whole run)
#   B.2 Climate and period
#     4. Climate priority (before subsetting, needs full-year trailing averages)
#     5. Subset Main_df by month / period
#   B.3 Profiles
#     6. Generate occupancy profiles
#     7. Generate scheduling profiles
#     8. Reference temperature profiles
#   B.4 Markets and prices
#     9. Initialise market columns in Main_df
#     10. Flexibility generation (conditional)
#     11. Energy/flexibility price signals (buy/sell derivation)
#     12. Build future-horizon price matrices
#     13. Initialise market output matrices (market commitments)
#     14. Initialise the economic analysis accumulators
# -------------------------------------------------------------
{
  # =============================================================
  # B.1 Random seed
  # =============================================================
  # -------------------------------------------------------------
  # 3. Fix the random seed (reproducibility of the whole run)
  # -------------------------------------------------------------
  # Fixes the random number generator so that two runs of the same
  # configuration produce the same results. Several parts of the
  # simulation draw random numbers:
  #   - 09_flexibility_price_emulation.R
  #   - generate_flexibility_events.R
  #   - place_flex_candidate.R
  #   - try_flex_echo.R
  #   - the genetic algorithm operators
  # Without a fixed seed none of them is reproducible and no two runs can be
  # compared.
  # This is the first point where parameters$debug_and_config is
  # available and no random number has been drawn yet, so the seed is
  # set here.
  # random_seed = 0 means "do not fix the seed" and falls back to the
  # system entropy, which is the behaviour of a run without this block.
  # The genetic algorithm runs on a cluster of worker processes when
  # parallel == 1, and each worker keeps its own random number stream
  # that set.seed() does not reach; optimize_setpoints.R and
  # optimize_modes.R therefore call clusterSetRNGStream() with this
  # same seed right after creating their cluster.
  # -------------------------------------------------------------
  {
    if (!is.null(parameters$debug_and_config$random_seed) &&
        parameters$debug_and_config$random_seed != 0) {
      set.seed(parameters$debug_and_config$random_seed)
      cat("Random seed fixed at", parameters$debug_and_config$random_seed, "\n")
    } else {
      cat("Random seed not fixed (random_seed = 0): this run is not reproducible\n")
    }
  }


  # =============================================================
  # B.2 Climate and period
  # =============================================================
  # -------------------------------------------------------------
  # 4. Climate priority (before subsetting, needs full-year trailing averages)
  # -------------------------------------------------------------
  # Runs before the month/period subset (like T_ext_24h in
  # 02_load_all_parameters.R) so that HDD_period/CDD_period trailing
  # averages have access to the full year, not just whatever remains
  # after subsetting. Otherwise, the first HDD_period/CDD_period days of
  # a subset range would have no prior data to average and would fall
  # back to "Intermediate" regardless of season.
  # -------------------------------------------------------------
  source(file.path("30_Simulation", "04_Scripts", "03_climate_priority.R"))

  # -------------------------------------------------------------
  # 5. Subset Main_df by month / period
  # -------------------------------------------------------------
  # 04_subset_main_df.R is sourced to cut Main_df to the period to
  # simulate, selected by month_subset and period_subset of
  # parameters$debug_and_config. It runs after the climate priority,
  # which needs the whole year.
  source(file.path("30_Simulation", "04_Scripts", "04_subset_main_df.R"))


  # =============================================================
  # B.3 Profiles
  # =============================================================
  # -------------------------------------------------------------
  # 6. Generate occupancy profiles
  # -------------------------------------------------------------
  # 05_generate_occupancy_profiles.R is sourced to derive Main_df$Occupancy
  # for every timestamp from parameters$use_patterns (month/weekday/hour
  # lookup), needed before the Scheduling profile and the reference
  # temperature profiles can be computed.
  source(file.path("30_Simulation", "04_Scripts", "05_generate_occupancy_profiles.R"))

  # -------------------------------------------------------------
  # 7. Generate scheduling profiles
  # -------------------------------------------------------------
  # 06_generate_scheduling_profiles.R is sourced to derive
  # Main_df$Scheduling from Main_df$Occupancy and the anticipation
  # parameters, marking the pre/post-occupancy windows used by the
  # reference temperature profiles below.
  source(file.path("30_Simulation", "04_Scripts", "06_generate_scheduling_profiles.R"))

  # -------------------------------------------------------------
  # 8. Reference temperature profiles
  # -------------------------------------------------------------
  # 07_reference_temperature_profiles.R is sourced to compute the
  # Service_T_*/Scheduling_T_* comfort setpoint bands, needed by the
  # reward function during the simulation loop, from:
  #   - Occupancy
  #   - Scheduling
  #   - Overall_Climate
  source(file.path("30_Simulation", "04_Scripts", "07_reference_temperature_profiles.R"))


  # =============================================================
  # B.4 Markets and prices
  # =============================================================
  # -------------------------------------------------------------
  # 9. Initialise market columns in Main_df
  # -------------------------------------------------------------
  # 08_market_columns_setup.R is sourced to fill in the Sched_*/Pilot_*
  # market-timeline columns of Main_df, in either basic or complex
  # mode, so the simulation loop can later tell when each market clears:
  #   - market name
  #   - bid time
  #   - period bounds
  #   - optimization horizon
  #   - aim
  source(file.path("30_Simulation", "04_Scripts", "08_market_columns_setup.R"))

  # -------------------------------------------------------------
  # 10. Flexibility generation (conditional)
  # -------------------------------------------------------------
  # Only executed when parameters$debug_and_config$Price_emulation == 1
  # Overwrites flex price columns in Main_df with generated values, using
  # either the basic per-day algorithm or the market-aware algorithm
  # (Complex_Market_Config), both based on the Market configuration
  # parameters (03_Market_config.csv / 07_Flexibility_price_emulation_parameters.csv)
  # -------------------------------------------------------------
  if (parameters$debug_and_config$Price_emulation == 1) {
    # 09_flexibility_price_emulation.R is sourced to place the flexibility
    # events and generate their prices and probabilities, since this run
    # has no real flexibility market data to read them from.
    source(file.path("30_Simulation", "04_Scripts", "09_flexibility_price_emulation.R"))
  }

  # -------------------------------------------------------------
  # 11. Energy/flexibility price signals (buy/sell derivation)
  # -------------------------------------------------------------
  # Derives the twelve buy/sell price signals consumed by the rest of
  # the market/reward pipeline from the six legacy signals above. See
  # 30_Simulation/04_Scripts/10_energy_price_signals_setup.R header.
  # -------------------------------------------------------------
  source(file.path("30_Simulation", "04_Scripts", "10_energy_price_signals_setup.R"))

  # -------------------------------------------------------------
  # 12. Build future-horizon price matrices
  # -------------------------------------------------------------
  # 11_full_market_information_setup.R is sourced to build the
  # future-horizon energy/flexibility price matrices (one row per
  # market event, one column per future step) that the Scheduling and
  # Piloting processes will look up during the simulation loop.
  source(file.path("30_Simulation", "04_Scripts", "11_full_market_information_setup.R"))

  # -------------------------------------------------------------
  # 13. Initialise market output matrices (market commitments)
  # -------------------------------------------------------------
  # 12_market_commitments_setup.R is sourced to create market_commitments,
  # a list of twelve data frames with one row per market event and one
  # column per future step, all at 0. The simulation loop accumulates
  # into them as each Scheduling/Piloting market is executed.
  #   - Elec_buy_plan_df: energy bought, on the plan
  #   - Elec_sell_plan_df: energy sold, on the plan
  #   - Elec_net_plan_df: net energy, on the plan
  #   - Elec_buy_plan_flex_down_df: energy bought, on the downward
  #     flexibility itinerary
  #   - Elec_sell_plan_flex_down_df: energy sold, on the downward
  #     flexibility itinerary
  #   - Elec_net_plan_flex_down_df: net energy, on the downward
  #     flexibility itinerary
  #   - Elec_flex_down_sell_plan_df: downward flexibility sold
  #   - Elec_flex_down_buy_plan_df: downward flexibility bought back
  #   - Elec_flex_up_sell_plan_df: upward flexibility sold
  #   - Elec_flex_up_buy_plan_df: upward flexibility bought back
  #   - Elec_Cost_plan_df: the committed cost of energy
  #   - Elec_flex_Cost_plan_df: the committed cost of flexibility
  source(file.path("30_Simulation", "04_Scripts", "12_market_commitments_setup.R"))

  # -------------------------------------------------------------
  # 14. Initialise the economic analysis accumulators
  # -------------------------------------------------------------
  # 13_economic_analysis_setup.R is sourced to create economic_analysis,
  # which the simulation loop fills in as each Scheduling and Piloting
  # market trades, and which 15_economic_analysis_finalize.R completes
  # with the execution phase once the loop is over:
  #   - market: one row per market event (Scheduling, Piloting or
  #     Execution), its accumulator columns at 0
  #   - slot: one row per market slot of the simulation, its
  #     accumulator columns at 0
  #   - index: for each slot, its Scheduling, Piloting and Execution
  #     rows of the market table, used while the loop runs and dropped
  #     by 15_economic_analysis_finalize.R
  source(file.path("30_Simulation", "04_Scripts", "13_economic_analysis_setup.R"))
}

# -------------------------------------------------------------
# C. Simulation
# Runs the MPC loop over every row of Main_df, with its three processes:
#   - Scheduling
#   - Piloting
#   - Execution
# Steps:
#   15. Perform simulation (calls to external script)
# -------------------------------------------------------------
{
  # -------------------------------------------------------------
  # 15. Perform simulation (calls to external script)
  # -------------------------------------------------------------
  # 14_simulation.R is sourced to run the main MPC simulation loop itself,
  # for every row of Main_df, with every dataframe and parameter set
  # assembled above.
  source(file.path("30_Simulation", "04_Scripts", "14_simulation.R"))
}

# -------------------------------------------------------------
# D. Post-process & Export
# Closes the analysis and writes the results:
#   - the economic analysis, completed with the execution phase
#   - the output tables, exported to files
# Steps:
#   16. Complete the economic analysis (execution phase and fractions)
#   17. Export results to files
# -------------------------------------------------------------
{
  # -------------------------------------------------------------
  # 16. Complete the economic analysis (execution phase and fractions)
  # -------------------------------------------------------------
  # 15_economic_analysis_finalize.R is sourced to add the execution phase to the
  # economic_analysis tables and to derive the reported fractions, giving the
  # global economic picture (per market and per market slot) that the
  # individual commitment and price matrices do not provide on their own.
  source(file.path("30_Simulation", "04_Scripts", "15_economic_analysis_finalize.R"))

  # -------------------------------------------------------------
  # 17. Export results to files
  # -------------------------------------------------------------
  # 16_data_outputs.R is sourced as the final step, to export the four
  # output tables listed in the header to CSV/RDS files under
  # paths$output_path.
  source(file.path("30_Simulation", "04_Scripts", "16_data_outputs.R"))
}
