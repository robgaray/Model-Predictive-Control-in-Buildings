# -------------------------------------------------------------
# Function: optimize_modes.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function optimizes the control modes over a particular period
# using a Genetic Algorithm (GA) approach with real-type genes that
# are constrained to integer values through custom population,
# crossover, and mutation operators.
# It performs the following steps:
#   1. Defines the optimization vector based on the number of modes
#      and the number of market periods in the target period.
#      It also sizes the elitism against the number of distinct
#      chromosomes the space holds, because ga()'s own default can
#      exceed it and inject an NA row into the population.
#   2. Initializes parallelization to speed up the optimization process.
#   3. Calls the GA optimizer with custom integer-handling operators
#      to find the optimal control mode sequence that maximizes the
#      reward function.
#   4. Post-processes the optimization results to extract the optimal
#      control modes for each market period.
# -------------------------------------------------------------
# Inputs
#   period_chunk   : Data frame. Simulation data for the optimization
#                    horizon. Must contain a 'MarketUTC' column used to
#                    derive the set of target periods, plus all columns
#                    required by period_calculation() (called inside
#                    evaluate_control()).
#   timestamps     : Named list. Timestamp metadata. Must contain:
#                      timestamps$target_periods : POSIXct vector of
#                                                  market period timestamps.
#   parameters     : Named list. Model parameters passed through to
#                    period_calculation() and reward_function().
#                    The following sub-elements are extracted internally:
#                      parameters$setpoint_modes
#                      parameters$control$Deadband
#                      parameters$optimization, as returned by
#                        load_optimization_parameters():
#                          - population_size
#                          - iteration_number
#                          - run_number
#                          - pcrossover
#                          - pmutation
#                      parameters$debug_and_config:
#                          - parallel
#                          - parallel_workers
#                          - random_seed
#   simulation_control : Named list. Index and flexibility metadata,
#                    passed through to the fitness function.
#   marginal_context : Named list or NULL. Passed through to the fitness
#                    function and, via clusterExport(), to worker processes.
# -------------------------------------------------------------
# Outputs
#   set_point_optimized : Data frame with setpoint columns and hysteresis
#                         deadbands for the optimal control modes,
#                         as returned by convert_modes_to_setpoints().
# -------------------------------------------------------------
# Code outline
# 1. Define GA chromosome structure for mode selection (integer vector)
# 1b. Size the elitism against the search space
# 2. Initialize parallelization
# 3. Run GA optimization with mode fitness function
# 4. Stop cluster (if parallel)
# 5. Post-process: extract best mode solution and convert to setpoints
# -------------------------------------------------------------
# Usage instructions
# result <- optimize_modes(period_chunk, timestamps, parameters, simulation_control)
# -------------------------------------------------------------
# Where this function/script is used
#   - optimize_control_step()
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - Parallelization uses parallel_workers worker processes, or all
#     logical cores but one when it is 0. The cluster is stopped and
#     sequential execution restored after the GA run.
#   - Worker processes (PSOCK clusters) do not inherit the global
#     environment: every function it holds is exported to them, and the
#     data of this optimization by name, via clusterExport().
#   - The GA uses real-type encoding with custom integer operators: n_periods
#     genes, each representing a mode index (1 to n_modes).
#   - The custom operators read the selected parent chromosomes from the
#     current GA population to keep the representation valid from the start.
#   - Only the first solution row of the GA result (ga_result@solution[1,])
#     is used if multiple equally-fit solutions exist.
# -------------------------------------------------------------
# functions/scripts called
#   ga_population_int()            - custom population generator
#   ga_crossover_int()             - custom crossover operator
#   ga_mutation_int()              - custom mutation operator
#   fitness_funct_optimize_mode()  - GA fitness function
#   maxmode()                      - pairs the best GA solution with target_periods
#   convert_modes_to_setpoints()   - maps mode selections to setpoint values
#
# Handed to the worker processes, not called here
#   The GA evaluates its candidates in worker processes, which receive
#   every function of the global environment through clusterExport:
#   evaluate_control(), period_calculation(), reward_function() and
#   everything they reach run there, underneath this function, without
#   being called by its body. They are listed apart for that reason:
#   the section above is what the body invokes.
# -------------------------------------------------------------
optimize_modes <- function(period_chunk,
                           timestamps,
                           parameters,
                           simulation_control,
                           marginal_context = NULL
                           ) {
  
  # 1. Define GA chromosome structure for mode selection (integer vector)
  # -------------------------------------------------------------
  # One integer gene per market period, bounded in [1, n_modes].
  # Each gene directly encodes a valid mode index.
  # -------------------------------------------------------------
  {
    n_periods    <- length(timestamps$target_periods)
    n_modes      <- length(unique(parameters$setpoint_modes$mode))
    lower_bounds <- rep(1, n_periods)
    upper_bounds <- rep(n_modes, n_periods)
  }

  # 1b. Size the elitism against the search space
  # -------------------------------------------------------------
  # ga() defaults to elitism = max(1, round(popSize * 0.05)) and its
  # elitism step picks those rows among the UNIQUE ones of the sorted
  # population. When the search space holds fewer distinct chromosomes
  # than that elitism, the index runs past the end of the unique rows
  # and comes back NA, which puts an NA row into the population; the
  # next generation hands that row to the fitness function and the run
  # stops in convert_modes_to_setpoints().
  # The space holds n_modes^n_periods chromosomes, which overflows for
  # any realistic horizon, so it is only computed when the exponent
  # stays small enough to matter: above the population size the cap
  # cannot bind anyway.
  # -------------------------------------------------------------
  {
    population_size <- parameters$optimization$population_size

    distinct_chromosomes <- if (n_periods * log(n_modes) > log(population_size)) {
      population_size
    } else {
      min(n_modes ^ n_periods, population_size)
    }

    elitism_size <- max(1, min(round(population_size * 0.05),
                               distinct_chromosomes))

    rm(distinct_chromosomes)
  }

  # 2. Initialize parallelization
  # -------------------------------------------------------------
  # If parallel is enabled, create a cluster and export all objects
  # needed by the fitness function to the worker processes.
  # On Windows (PSOCK clusters), child processes do not inherit the
  # global environment, so explicit export is required.
  # -------------------------------------------------------------
  {
    if (parameters$debug_and_config$parallel == 1) {
      n_cores <- parameters$debug_and_config$parallel_workers
      if (is.null(n_cores) || n_cores == 0) {
        n_cores <- max(1, parallel::detectCores(logical = TRUE) - 1)
      }
      cl      <- makeCluster(n_cores)
      registerDoParallel(cl)

      # clusterSetRNGStream is called to give every worker process a
      # reproducible random number stream derived from the run's seed.
      # set.seed() in optimize_market() only affects the main process, so without
      # this call the GA's random operators would differ between runs
      # even with the seed fixed. The seed is only applied when it is
      # non-zero, mirroring optimize_market()'s "0 means do not fix" convention.
      # The number of workers is parallel_workers, or all logical cores
      # but one when it is 0. The result does not depend on it.
      if (!is.null(parameters$debug_and_config$random_seed) &&
          parameters$debug_and_config$random_seed != 0) {
        parallel::clusterSetRNGStream(cl, iseed = parameters$debug_and_config$random_seed)
      }

      # Every function the simulation has loaded lives in the global
      # environment, and a worker process starts with none of them. All
      # of them are exported, rather than a list kept by hand: a hand-kept
      # list silently misses the next function added, and the run then
      # stops inside a worker. The C++ entry points travel too, but are
      # replaced below when the module is compiled on each worker.
      project_functions <- Filter(
        function(name) is.function(get(name, envir = globalenv())),
        ls(globalenv())
      )
      clusterExport(
        cl,
        varlist = project_functions,
        envir   = globalenv()
      )
      rm(project_functions)

      # The data of this optimization, from this function's environment
      clusterExport(
        cl,
        varlist = c(
          "period_chunk",
          "parameters",
          "timestamps",
          "simulation_control",
          "marginal_context"
        ),
        envir = environment()
      )

      # Compile C++ simulation module on each worker process
      clusterExport(
        cl,
        "cpp_source_path",
        envir = globalenv()
      )
      clusterEvalQ(
        cl,
        Rcpp::sourceCpp(cpp_source_path)
      )
    }
  }

  # 3. Run GA optimization with mode fitness function
  # -------------------------------------------------------------
  # ga() is called with type="real-valued" and custom population,
  # crossover, and mutation functions that preserve the integer
  # representation by operating on chromosomes stored in the GA population.
  # -------------------------------------------------------------
  {
    ga_result <- ga(
      type       = "real-valued",
      lower      = lower_bounds,
      upper      = upper_bounds,
      popSize    = parameters$optimization$population_size,
      elitism    = elitism_size,
      maxiter    = parameters$optimization$iteration_number,
      run        = parameters$optimization$run_number,
      pcrossover = parameters$optimization$pcrossover,
      pmutation  = parameters$optimization$pmutation,
      population = ga_population_int,
      crossover  = ga_crossover_int,
      mutation   = ga_mutation_int,
      parallel   = if (parameters$debug_and_config$parallel == 1) cl else FALSE,
      monitor    = FALSE,
      # fitness_funct_optimize_mode is wired in as the GA's fitness
      # function so every candidate chromosome is scored through the
      # same period_calculation()/evaluate_control()/reward_function()
      # pipeline used elsewhere, keeping the reward calculation
      # consistent across optimization paths.
      fitness    = function(x) fitness_funct_optimize_mode(
                                 x                  = as.integer(round(x)),
                                 timestamps         = timestamps,
                                 parameters         = parameters,
                                 period_chunk       = period_chunk,
                                 simulation_control = simulation_control,
                                 marginal_context   = marginal_context
                               )
    )
  }

  # 4. Stop cluster (if parallel)
  # -------------------------------------------------------------
  # rm(cl) + gc() force the PSOCK connection objects to be released
  # right away; otherwise R's automatic gc cycles may not reach them
  # before the session ends, and they get closed with a warning at exit.
  # -------------------------------------------------------------
  {
    if (parameters$debug_and_config$parallel == 1) {
      stopCluster(cl)
      registerDoSEQ()
      rm(cl)
      gc(verbose = FALSE)
    }
  }

  # 5. Post-process: extract best mode solution and convert to setpoints
  # -------------------------------------------------------------
  # Extract best solution as integer vector, pair with target_periods
  # to build mode data frame, then convert to setpoints.
  # -------------------------------------------------------------
  {
    best_solution <- as.integer(round(ga_result@solution[1, ]))

    # maxmode is called to pair the best solution with the market
    # periods it encodes, one mode per period.
    setpoint_modes_df_optimized <- maxmode(
      x              = best_solution,
      target_periods = timestamps$target_periods
    )
    rm(ga_result, best_solution)

    # convert_modes_to_setpoints is called to turn those modes into the
    # setpoint schedule, with its hysteresis deadbands.
    setpoint_modes_df_optimized <- convert_modes_to_setpoints(
      setpoint_modes_df = setpoint_modes_df_optimized,
      setpoint_modes    = parameters$setpoint_modes,
      Deadband          = parameters$control$Deadband,
      target_periods    = timestamps$target_periods
    )

    rm(population_size, elitism_size, n_periods, n_modes,
       lower_bounds, upper_bounds)
  }

  return(setpoint_modes_df_optimized)
}
