# -------------------------------------------------------------
# Function: run_simulation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Runs a whole simulation of a Model Predictive Control (MPC)
# strategy applied to building energy management, from the
# configuration folder to the output files: it loads the data and
# the parameters, prepares everything the simulation loop reads, runs
# the loop, completes the economic analysis and writes the results.
# It is the entry point that Main.R calls once the simulator has
# been loaded with initialize_simulator().
# -------------------------------------------------------------
# The MPC concept
# A model is used to set the control criteria over a long-term
# horizon. Typical control horizon is in the range of 24 hours.
# -------------------------------------------------------------
# The aim of the optimization
# Depending on the selected configuration, the MPC is set to
# optimize the energy consumption over the control horizon, or even
# to deliver flexibility to the grid.
# -------------------------------------------------------------
# The Building
# The building is modeled using a simplified thermal model with
# parameters defined in external configuration files. The model
# includes thermal dynamics, HVAC system characteristics, and
# occupant comfort settings.
# The relevant file for this is "11_Model_parameters.csv", in the
# configuration folder of the building.
# -------------------------------------------------------------
# Control Strategy
# The control strategy is based on predefined modes: the
# optimizer selects the best mode of every market period within a
# set of modes (discrete options), each of which fixes the
# temperature setpoints.
# The control parameters are defined in:
#   - "08_Flexibility_Event_Configuration.csv": the parameters that
#     define the flexibility events
#   - "13_Modes_setpoints.csv": the modes, in the configuration
#     folder of the building
# -------------------------------------------------------------
# Weather forecast
# MPC requires a forecast of the contextual information. In this
# case, the weather forecast. Here, two options are considered:
#   1. Inaccurate forecast: The forecast has some errors compared
#      to the actual weather conditions.
#   2. Accurate forecast: The forecast matches the actual weather
#      conditions perfectly.
# MPC is executed with either of these options but then the
# "optimal" control actions are applied to the real building model
# with the actual weather conditions.
# The forecast parameters for the inaccurate forecast are defined
# in "15_Forecast_parameters.csv".
# -------------------------------------------------------------
# Optimal criteria (reward)
# The optimization aims to maximize a reward function that
# balances energy costs and occupant comfort. The reward parameters
# are defined in "09_Reward_parameters.csv".
# -------------------------------------------------------------
# The overrides
# overrides lets a run change some values of the configuration
# folder without editing it. They are written into a temporary copy
# of the folder, before anything is loaded (see
# apply_config_overrides()), so every overridden value is validated
# against the parameter catalogue as a value of the file would be.
# The copy is removed when the run ends, however it ends.
# -------------------------------------------------------------
# Inputs
#   config_path : Character. Path of the configuration folder, the
#                 one that holds 00_Inner_parameters/, 00_Validation/
#                 and every configuration file. The names of the
#                 files are read from 04_File_paths.csv.
#   overrides   : NULL, for no override, or a data frame with the
#                 text columns file, parameter and value, where file
#                 is written as @<key>, a key of 04_File_paths.csv (see
#                 apply_config_overrides()).
#   data_path   : Character. The folder of the input series,
#                 Meteo_df.rds and Energy_Prices_df.rds.
#   output_path : Character. The folder the output tables are
#                 written to. It is created if it does not exist.
#   The function also reads, from the simulator environment it is
#   defined in:
#   - paths: the C++ module. The configuration files, the data files
#     and the output folder of paths are replaced by those of
#     config_path, data_path and output_path.
#   - the functions and the compiled C++ module.
# -------------------------------------------------------------
# Outputs
#   Named list with the final results of the run:
#   - Main_df            : Data table. The simulation results of the
#                          system, one row per timestep: the common
#                          columns and the balances of the system.
#   - assets             : Named list, one entry per asset, each with
#                          df, the table of the asset (a data table),
#                          one row per row of Main_df.
#   - market_commitments : Named list of 12 data frames. The
#                          differential energy and cost commitments
#                          of every Scheduling and Piloting market.
#   - economic_analysis  : Named list of 3 data frames (market,
#                          decision, slot). The economic analysis,
#                          completed with the execution phase.
#   - execution_time     : List. Timing information of the loop.
#   It also writes the output tables, each as .csv and .rds, to
#   output_path (see write_outputs()):
#     - Main_df_computed
#     - <asset_id>_df_computed, one per asset
#     - Sinthetized_df_computed
#     - Economic_analysis_market_computed
#     - Economic_analysis_decision_computed
#     - Economic_analysis_slot_computed
#   When parameters$debug_and_config$verbose is TRUE, PREPARE lines
#   are written to the console: the period and the seed, each asset
#   prepared, the price signals and the economic analysis.
# -------------------------------------------------------------
# Code outline
# A. Configuration and parameter loading
#   1. Check the arguments and set the paths
#   2. Load data and model parameters
# B. Pre-processing
#   B.1 Random seed
#     3. Fix the random seed (reproducibility of the whole run)
#   B.2 Climate and period
#     4. Climate priority of each building (before subsetting,
#        needs full-year trailing averages)
#     5. Subset Main_df and the table of each asset by month /
#        period
#   B.3 Profiles
#     6. Profiles of each asset
#   B.4 Markets and prices
#     7. Initialise market columns in Main_df, and the table of
#        the market events
#     8. Flexibility generation (conditional)
#     9. Energy/flexibility price signals (buy/sell derivation)
#     10. Build future-horizon price matrices
#     11. Initialise market output matrices (market commitments)
#     12. Initialise the economic analysis accumulators
# C. Simulation
#   13. Perform simulation
# D. Post-process & Export
#   14. Complete the economic analysis (execution phase and
#       fractions)
#   15. Export results to files
#   16. Return the results
# -------------------------------------------------------------
# Usage instructions
# source(file.path("30_Simulation", "03_Functions",
#                  "initialize_simulator.R"))
# sim <- initialize_simulator(
#   simulation_path = file.path(getwd(), "30_Simulation")
# )
# run_simulation <- sim$run_simulation
# results <- run_simulation(
#   config_path = file.path(getwd(), "30_Simulation", "02_Config"),
#   overrides   = NULL,
#   data_path   = file.path(getwd(), "30_Simulation", "01_Data"),
#   output_path = file.path(getwd(), "30_Simulation", "90_Output")
# )
# -------------------------------------------------------------

run_simulation <- function(config_path,
                           overrides,
                           data_path,
                           output_path
                           ) {

  # -------------------------------------------------------------
  # A. Configuration and parameter loading
  # Prepares everything the run reads:
  #   - the paths of the configuration files
  #   - Main_df and every parameter sub-list
  # Steps:
  #   1. Check the arguments and set the paths
  #   2. Load data and model parameters
  # -------------------------------------------------------------
  {
    # -------------------------------------------------------------
    # 1. Check the arguments and set the paths
    # The C++ module is that of the simulator. The configuration
    # files are those of config_path, named in its 04_File_paths.csv,
    # or those of a temporary copy of it when there are overrides.
    # The data files are those of data_path, and the outputs go to
    # output_path.
    # -------------------------------------------------------------
    {
      if (!dir.exists(config_path)) {
        stop("Missing configuration directory:\n", config_path)
      }
      if (!dir.exists(data_path)) {
        stop("Missing data directory:\n", data_path)
      }

      if (!is.null(overrides)) {
        required_columns <- c("file", "parameter", "value")
        if (!is.data.frame(overrides) ||
            !all(required_columns %in% names(overrides))) {
          stop("overrides must be NULL or a data frame with the ",
               "columns file, parameter and value")
        }
        overrides[required_columns] <- lapply(
          overrides[required_columns],
          function(column) trimws(as.character(column))
        )

        # apply_config_overrides is called to write a temporary copy
        # of config_path with the overrides applied, so that they are
        # validated when the copy is loaded. The copy is removed when
        # this function exits.
        config_path <- apply_config_overrides(
          config_path = config_path,
          overrides   = overrides,
          target_path = tempfile("config_")
        )
        on.exit(unlink(config_path, recursive = TRUE), add = TRUE)

        rm(list = "required_columns")
      }

      # The simulator environment holds the paths of the simulator,
      # and is the enclosure of this function.
      paths <- parent.env(environment())$paths

      # build_config_paths is called to name the files of config_path,
      # so that the run reads its configuration from there and not
      # from the folder the simulator was loaded with.
      config_paths <- build_config_paths(config_path = config_path)

      paths[names(config_paths)] <- config_paths
      # The data files keep the names the simulator gives them, in
      # data_path.
      paths$meteo_file         <- file.path(data_path,
                                            basename(paths$meteo_file))
      paths$energy_prices_file <- file.path(data_path,
                                            basename(paths$energy_prices_file))
      paths$output_path        <- output_path

      missing_files <- unlist(config_paths)[!file.exists(unlist(config_paths))]
      if (length(missing_files) > 0) {
        stop("Missing required files:\n", paste(missing_files, collapse = "\n"))
      }

      rm(list = c("config_paths", "missing_files"))
    }

    # -------------------------------------------------------------
    # 2. Load data and model parameters
    # -------------------------------------------------------------
    # THIS IS THE PLACE TO CHANGE PARAMETERS
    # Inspect & change the parameter files OR override the
    # parameters after they are loaded
    # -------------------------------------------------------------
    {
      # load_all_parameters is called to:
      #   - assemble Main_df, from Meteo_df and Energy_Prices_df plus
      #     the synthetic dataframes
      #   - load every parameter sub-list from the configuration
      #     CSV files (see load_all_parameters() for the full list)
      #   - build the table of each asset of the asset registry
      loaded <- load_all_parameters(
        paths = paths
      )

      Main_df    <- loaded$Main_df
      assets     <- loaded$assets
      parameters <- loaded$parameters

      rm(list = "loaded")
    }
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
  #     4. Climate priority of each building (before subsetting,
  #        needs full-year trailing averages)
  #     5. Subset Main_df and the table of each asset by month /
  #        period
  #   B.3 Profiles
  #     6. Profiles of each asset
  #   B.4 Markets and prices
  #     7. Initialise market columns in Main_df, and the table of
#        the market events
  #     8. Flexibility generation (conditional)
  #     9. Energy/flexibility price signals (buy/sell derivation)
  #     10. Build future-horizon price matrices
  #     11. Initialise market output matrices (market commitments)
  #     12. Initialise the economic analysis accumulators
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
    #   - prepare_flexibility_prices.R
    #   - generate_flexibility_events.R
    #   - place_flex_candidate.R
    #   - try_flex_echo.R
    #   - the genetic algorithm operators
    # Without a fixed seed none of them is reproducible and no two
    # runs can be compared.
    # This is the first point where parameters$debug_and_config is
    # available and no random number has been drawn yet, so the seed
    # is set here.
    # random_seed = 0 means "do not fix the seed" and falls back to
    # the system entropy.
    # The genetic algorithm runs on a cluster of worker processes
    # when parallel == 1, and each worker keeps its own random number
    # stream that set.seed() does not reach; start_worker_cluster()
    # therefore calls clusterSetRNGStream() with this same seed right
    # after creating the cluster, before the simulation loop.
    # -------------------------------------------------------------
    {
      if (!is.null(parameters$debug_and_config$random_seed) &&
          parameters$debug_and_config$random_seed != 0) {
        set.seed(parameters$debug_and_config$random_seed)
        seed_text <- paste0("random seed ",
                            parameters$debug_and_config$random_seed)
      } else {
        seed_text <- paste0("random seed not fixed (random_seed = 0), ",
                            "this run is not reproducible")
      }
    }


    # =============================================================
    # B.2 Climate and period
    # =============================================================
    # -------------------------------------------------------------
    # 4. Climate priority (before subsetting, needs full-year trailing averages)
    # -------------------------------------------------------------
    # Runs before the month/period subset (like T_ext_24h in
    # load_all_parameters()) so that the HDD_period/CDD_period
    # trailing days have access to the full year, not just whatever
    # remains after subsetting. Otherwise, the first
    # HDD_period/CDD_period days of a subset range would have no
    # prior data and would be tagged from the first days of the
    # subset instead of from their own preceding days.
    # -------------------------------------------------------------
    {
      for (CONT_001 in names(assets)) {
        # model_type_contract is called to get the operations of the
        # type of model of the asset.
        model <- model_type_contract(parameters$assets[[CONT_001]]$asset_type)

        # The operation prepare_year is called to prepare the table of
        # the asset with what needs the whole year (for a building,
        # the climate of each day, tagged from the daily means of Text,
        # which are read from the whole of Main_df): the period is cut
        # afterwards.
        assets[[CONT_001]]$df <- model$prepare_year(
          Main_df  = Main_df,
          asset_df = assets[[CONT_001]]$df,
          asset    = parameters$assets[[CONT_001]]
        )
      }
      rm(list = c("CONT_001", "model"))
    }

    # -------------------------------------------------------------
    # 5. Subset Main_df and the table of each asset by month / period
    # -------------------------------------------------------------
    {
      # subset_period is called to keep the selected month and the
      # selected number of rows of Main_df, selected by month_subset
      # and period_subset of parameters$debug_and_config. It runs
      # after the climate priority, which needs the whole year.
      Main_df <- subset_period(
        simulation_table = Main_df,
        month_subset     = parameters$debug_and_config$month_subset,
        period_subset    = parameters$debug_and_config$period_subset
      )

      for (CONT_002 in names(assets)) {
        # subset_period is called to keep the same rows of the table of
        # each asset, which shares the time column of Main_df.
        assets[[CONT_002]]$df <- subset_period(
          simulation_table = assets[[CONT_002]]$df,
          month_subset     = parameters$debug_and_config$month_subset,
          period_subset    = parameters$debug_and_config$period_subset
        )
      }
      rm(list = "CONT_002")

      # console_message is called to tell the period of the run and
      # the random seed, once, when the run settings are known.
      if (parameters$debug_and_config$verbose) {
        month_text <- if (is.null(parameters$debug_and_config$month_subset) ||
                          parameters$debug_and_config$month_subset == 0) {
          "full year"
        } else {
          paste0("month ", parameters$debug_and_config$month_subset)
        }
        console_message(
          label = "PREPARE",
          text  = paste0("Period: ", month_text, ", ", nrow(Main_df),
                         " rows; ", seed_text)
        )
        rm(list = "month_text")
      }
      rm(list = "seed_text")
    }


    # =============================================================
    # B.3 Profiles
    # =============================================================
    # -------------------------------------------------------------
    # 6. Profiles of each asset
    # Each asset prepares its table for the simulated period through
    # its type of model. For a building these are its occupancy, its
    # scheduling window and the reference temperature profiles.
    # -------------------------------------------------------------
    {
      for (CONT_003 in names(assets)) {
        # model_type_contract is called to get the operations of the
        # type of model of the asset.
        model <- model_type_contract(parameters$assets[[CONT_003]]$asset_type)

        # The operation prepare_period is called to prepare the table
        # of the asset, already cut to the period, with the profiles
        # that the simulation loop and the reward read.
        assets[[CONT_003]]$df <- model$prepare_period(
          asset_df = assets[[CONT_003]]$df,
          asset    = parameters$assets[[CONT_003]]
        )

        # console_message is called to write the line of this asset.
        if (parameters$debug_and_config$verbose) {
          console_message(
            label = "PREPARE",
            text  = paste0(CONT_003, ": ",
                           parameters$assets[[CONT_003]]$asset_type,
                           " prepared for the year and the period")
          )
        }
      }
      rm(list = c("CONT_003", "model"))
    }


    # =============================================================
    # B.4 Markets and prices
    # =============================================================
    # -------------------------------------------------------------
    # 7. Initialise market columns in Main_df, and the table of the
    #    market events
    # -------------------------------------------------------------
    {
      # prepare_market_calendar is called to key each row to its
      # market interval and to fill in the Sched_ and Pilot_ market
      # columns, which tell the simulation loop when each market
      # clears:
      #   - market name
      #   - bid time
      #   - period bounds
      #   - optimization horizon
      #   - aim
      Main_df <- prepare_market_calendar(
        Main_df                  = Main_df,
        computing                = parameters$computing,
        market                   = parameters$market,
        market_config_scheduling = parameters$market_config_scheduling,
        market_config_piloting   = parameters$market_config_piloting
      )

      # build_market_events is called to read, once, the table of the
      # market events of the run (one row per clearing of a Scheduling
      # or Piloting market) out of the calendar columns, so that the
      # price matrices, the commitment matrices and the economic
      # analysis all take their rows from the same events.
      market_events <- build_market_events(
        Main_df           = Main_df,
        market_resolution = parameters$market$market_resolution
      )
    }

    # -------------------------------------------------------------
    # 8. Flexibility generation (conditional)
    # -------------------------------------------------------------
    # Only executed when parameters$debug_and_config$Price_emulation
    # == 1. Overwrites flex price columns in Main_df with generated
    # values, using either the basic per-day algorithm or the
    # market-aware algorithm (Complex_Market_Config), both based on
    # the Market configuration parameters (03_Market_config.csv /
    # 07_Flexibility_price_emulation_parameters.csv).
    # -------------------------------------------------------------
    {
      if (parameters$debug_and_config$Price_emulation == 1) {
        # prepare_flexibility_prices is called to draw the
        # flexibility events and write their prices, probabilities
        # and activation into Main_df, since this run has no real
        # flexibility market data to read them from.
        Main_df <- prepare_flexibility_prices(
          Main_df                     = Main_df,
          market                      = parameters$market,
          flexibility_price_emulation =
            parameters$flexibility_price_emulation,
          computing                   = parameters$computing
        )
      }
    }

    # -------------------------------------------------------------
    # 9. Energy/flexibility price signals (buy/sell derivation)
    # -------------------------------------------------------------
    {
      # prepare_energy_prices is called to derive the twelve buy/sell
      # price signals from the input price with the discounts, and to
      # copy each flexibility price as its buy and sell signals,
      # which the market information and the economic accounting
      # read.
      Main_df <- prepare_energy_prices(
        Main_df      = Main_df,
        energy_price = parameters$energy_price
      )

      # console_message is called to write the line of the price
      # signals of steps 8 and 9.
      if (parameters$debug_and_config$verbose) {
        console_message(
          label = "PREPARE",
          text  = paste0("Price signals: energy derived, flexibility ",
                         if (parameters$debug_and_config$Price_emulation == 1) {
                           "emulated"
                         } else {
                           "not emulated"
                         })
        )
      }
    }

    # -------------------------------------------------------------
    # 10. Build future-horizon price matrices
    # -------------------------------------------------------------
    {
      # prepare_market_information is called to size the price
      # matrices from the furthest horizon any market looks at, and
      # to fill them with the prices of each market event and each
      # step ahead (one row per market event, one column per future
      # step), which the Scheduling and Piloting processes look up
      # during the loop.
      full_market_information <- prepare_market_information(
        Main_df                  = Main_df,
        market_events            = market_events,
        market                   = parameters$market,
        market_config_scheduling = parameters$market_config_scheduling,
        market_config_piloting   = parameters$market_config_piloting,
        energy_price             = parameters$energy_price,
        computing                = parameters$computing
      )
    }

    # -------------------------------------------------------------
    # 11. Initialise market output matrices (market commitments)
    # -------------------------------------------------------------
    {
      # prepare_commitments is called to create market_commitments,
      # a list of twelve data frames with one row per market event
      # and one column per future step, all at 0. The simulation
      # loop accumulates into them as each Scheduling/Piloting
      # market is executed.
      market_commitments <- prepare_commitments(
        Main_df                  = Main_df,
        market_events            = market_events,
        market                   = parameters$market,
        market_config_scheduling = parameters$market_config_scheduling,
        market_config_piloting   = parameters$market_config_piloting
      )
    }

    # -------------------------------------------------------------
    # 12. Initialise the economic analysis accumulators
    # -------------------------------------------------------------
    {
      # prepare_economic_analysis is called to create the economic
      # analysis tables, which the simulation loop fills in as each
      # Scheduling and Piloting market trades, and which finalize()
      # completes with the execution phase once the loop is over:
      #   - market: one row per market event (Scheduling, Piloting
      #     or Execution), its accumulator columns at 0
      #   - slot: one row per market slot of the simulation, its
      #     accumulator columns at 0
      #   - index: for each slot, its Scheduling, Piloting and
      #     Execution rows of the market table, used while the loop
      #     runs and dropped by finalize()
      economic_analysis <- prepare_economic_analysis(
        Main_df          = Main_df,
        market_events    = market_events,
        debug_and_config = parameters$debug_and_config
      )

      rm(list = "market_events")
    }
  }

  # -------------------------------------------------------------
  # C. Simulation
  # Runs the MPC loop over every row of Main_df, with its three
  # processes:
  #   - Scheduling
  #   - Piloting
  #   - Execution
  # Steps:
  #   13. Perform simulation
  # -------------------------------------------------------------
  {
    # -------------------------------------------------------------
    # 13. Perform simulation
    # -------------------------------------------------------------
    {
      # simulate is called to run the main MPC simulation loop for
      # every row of Main_df, from the state the steps above
      # assembled, and to return the final state, whose elements
      # replace the objects of the same names.
      state <- simulate(
        state      = list(
          Main_df                 = Main_df,
          assets                  = assets,
          full_market_information = full_market_information,
          market_commitments      = market_commitments,
          economic_analysis       = economic_analysis,
          paths                   = paths
        ),
        parameters = parameters
      )

      Main_df            <- state$Main_df
      assets             <- state$assets
      market_commitments <- state$market_commitments
      economic_analysis  <- state$economic_analysis
      execution_time     <- state$execution_time

      rm(list = c("state", "full_market_information"))
    }
  }

  # -------------------------------------------------------------
  # D. Post-process & Export
  # Closes the analysis and writes the results:
  #   - the economic analysis, completed with the execution phase
  #   - the output tables, exported to files
  # Steps:
  #   14. Complete the economic analysis (execution phase and
  #       fractions)
  #   15. Export results to files
  #   16. Return the results
  # -------------------------------------------------------------
  {
    # -------------------------------------------------------------
    # 14. Complete the economic analysis (execution phase and fractions)
    # -------------------------------------------------------------
    {
      # finalize is called to add the execution phase to the
      # economic_analysis tables and to derive the reported
      # fractions, giving the global economic picture (per market
      # and per market slot) that the individual commitment and
      # price matrices do not provide on their own.
      economic_analysis <- finalize(
        economic_analysis = economic_analysis,
        Main_df           = Main_df,
        verbose           = parameters$debug_and_config$verbose,
        flex_energy_tol   = parameters$computing$flex_energy_tol
      )
    }

    # -------------------------------------------------------------
    # 15. Export results to files
    # -------------------------------------------------------------
    {
      # The columns of the table of each asset are those of its type
      # of model.
      asset_types <- vapply(parameters$assets, function(CONT_001) {
        CONT_001$asset_type
      }, character(1))

      # write_outputs is called to export the output tables listed in
      # the header to CSV/RDS files under the output folder of paths.
      # It writes Main_df_computed with the common and system columns,
      # and one table per asset.
      write_outputs(
        Main_df           = Main_df,
        assets            = assets,
        system_columns    = parameters$needed_cols,
        asset_columns     = parameters$asset_cols,
        asset_types       = asset_types,
        economic_analysis = economic_analysis,
        execution_time    = execution_time,
        optimization      = parameters$optimization,
        output_path       = paths$output_path
      )
      rm(list = "asset_types")
    }

    # -------------------------------------------------------------
    # 16. Return the results
    # -------------------------------------------------------------
    {
      return(
        list(
          Main_df            = Main_df,
          assets             = assets,
          market_commitments = market_commitments,
          economic_analysis  = economic_analysis,
          execution_time     = execution_time
        )
      )
    }
  }
}
