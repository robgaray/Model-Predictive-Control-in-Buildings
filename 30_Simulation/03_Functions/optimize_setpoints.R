# -------------------------------------------------------------
# Function: optimize_setpoints.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function optimizes heating and cooling setpoints over a
# particular period using a Genetic Algorithm (GA) approach.
# It performs the following steps:
#   1. Defines the optimization vectors based on the number of
#      market slots in the target period.
#   2. Initializes parallelization to speed up the optimization process.
#   3. Calls the GA optimizer to find the optimal setpoint sequence
#      that maximizes the reward function.
#   4. Post-processes the optimization results to extract the optimal
#      heating and cooling setpoints for each market period.
# -------------------------------------------------------------
# Inputs
#   period_chunk   : Data frame. Simulation data for the optimization
#                    horizon. Must contain a 'MarketUTC' column used to
#                    determine the number of market periods (horizon),
#                    plus all columns required by period_calculation()
#                    (called inside evaluate_control()).
#   timestamps     : Named list. Timestamp metadata. Must contain:
#                      timestamps$target_periods : POSIXct vector of
#                                                  market period timestamps.
#   parameters     : Named list. Model parameters passed through to
#                    period_calculation() and reward_function().
#                    The following sub-elements are extracted internally:
#                      parameters$control$set_point_range_heating
#                      parameters$control$set_point_range_cooling
#                      parameters$control$Deadband
#                      parameters$optimization, as returned by
#                        load_optimization_parameters():
#                          - population_size
#                          - iteration_number
#                          - run_number
#                          - pcrossover
#                          - pmutation
#                          - parallel
#   simulation_control : Named list. Index/step metadata (passed through to
#                    the fitness function for interface consistency).
#   marginal_context : Named list or NULL. Passed through to the fitness
#                    function and, via clusterExport(), to worker processes.
# -------------------------------------------------------------
# Outputs
#   set_point_optimized : Data frame with setpoint columns and hysteresis
#                         deadbands for the optimal heating and cooling
#                         setpoints, as returned by convert_setpoints().
# -------------------------------------------------------------
# Code outline
# 1. Build lower and upper bounds for heating/cooling setpoints
# 2. Configure genetic algorithm (GA) parameters
# 3. Run GA optimization with fitness function
# 4. Extract best setpoint solution
# 5. Convert best solution to a set_point_df with hysteresis deadbands
#    via convert_setpoints()
# -------------------------------------------------------------
# Usage instructions
# result <- optimize_setpoints(period_chunk, timestamps, parameters, simulation_control)
# -------------------------------------------------------------
# Where this function/script is used
# Called by optimize_control_step.R when control_type is "setpoints".
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - Parallelization uses parallel_workers worker processes, or all
#     logical cores but one when it is 0. The cluster
#     is stopped and sequential execution restored after the GA run.
#   - Worker processes (PSOCK clusters) do not inherit the global
#     environment: every function it holds is exported to them, and the
#     data of this optimization by name, via clusterExport().
#   - The GA uses real-valued encoding: 2 * horizon real genes, where the
#     first 'horizon' genes are heating setpoints and the next 'horizon'
#     genes are cooling setpoints.
#   - The GA optimization vector has lower bounds set to set_point_range_heating[1]
#     and set_point_range_cooling[1], and upper bounds to set_point_range_heating[2]
#     and set_point_range_cooling[2].
#   - Only the first solution row of the GA result (ga_result@solution[1,])
#     is used if multiple equally-fit solutions exist.
# -------------------------------------------------------------
# functions/scripts called
#   fitness_funct_optimize_setpoint() - GA fitness function
#   convert_setpoints()               - converts raw setpoints to a data
#                                       frame with hysteresis deadbands
#
# Handed to the worker processes, not called here
#   The GA evaluates its candidates in worker processes, which receive
#   every function of the global environment through clusterExport:
#   evaluate_control(), period_calculation(), reward_function() and
#   everything they reach run there, underneath this function, without
#   being called by its body. They are listed apart for that reason:
#   the section above is what the body invokes.
# -------------------------------------------------------------
optimize_setpoints <- function(period_chunk,
                               timestamps,
                               parameters,
                               simulation_control,
                               marginal_context = NULL
                               ) {
  # Optimization vector definition
  {
    horizon <- length(timestamps$target_periods)
    
    lower_bounds <- c(rep(parameters$control$set_point_range_heating[1], horizon),
                      rep(parameters$control$set_point_range_cooling[1], horizon))
    upper_bounds <- c(rep(parameters$control$set_point_range_heating[2], horizon),
                      rep(parameters$control$set_point_range_cooling[2], horizon))
    
  }

  # Create parameters2 with parallel disabled to avoid nested parallelism conflicts
  parameters2 <- parameters
  parameters2$optimization <- as.list(parameters$optimization)
  parameters2$debug_and_config <- as.list(parameters$debug_and_config)
  parameters2$debug_and_config$parallel <- 0
  
  # Parallelization initialization
  {
    if (parameters$debug_and_config$parallel == 1) {
      n_cores <- parameters$debug_and_config$parallel_workers
      if (is.null(n_cores) || n_cores == 0) {
        n_cores <- max(1, parallel::detectCores(logical = TRUE) - 1)  # leave 1 core free
      }
      cl <- makeCluster(n_cores)                             # works on Windows and Linux
      registerDoParallel(cl)                                 # register cluster for foreach

      # clusterSetRNGStream is called to give every worker process a
      # reproducible random number stream derived from the run's seed.
      # set.seed() in Main.R only affects the main process, so without
      # this call the GA's random operators would differ between runs
      # even with the seed fixed. The seed is only applied when it is
      # non-zero, mirroring Main.R's "0 means do not fix" convention.
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
          "parameters2",
          "horizon",
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

  # Optimization (real-valued GA)
  # fitness_funct_optimize_setpoint is wired in as the GA's fitness
  # function so every candidate setpoint array is scored through the
  # same period_calculation()/evaluate_control()/reward_function()
  # pipeline used elsewhere, keeping the reward calculation consistent
  # across optimization paths.
  ga_result <- ga(
    type       = "real-valued",
    fitness    = function(x) fitness_funct_optimize_setpoint(
                               setpoint_array    = x,
                               period_chunk      = period_chunk,
                               parameters        = parameters2,
                               timestamps        = timestamps,
                               simulation_control = simulation_control,
                               marginal_context  = marginal_context
                             ),
    lower      = lower_bounds,
    upper      = upper_bounds,
    popSize    = parameters$optimization$population_size,
    maxiter    = parameters$optimization$iteration_number,
    run        = parameters$optimization$run_number,
    pcrossover = parameters$optimization$pcrossover,
    pmutation  = parameters$optimization$pmutation,
    parallel   = if (parameters$debug_and_config$parallel == 1) cl else FALSE,
    monitor    = FALSE
  )
  
  # Stop cluster
  # rm(cl) + gc() force the PSOCK connection objects to be released
  # right away; otherwise R's automatic gc cycles may not reach them
  # before the session ends, and they get closed with a warning at exit.
  if (parameters$debug_and_config$parallel == 1) {
    stopCluster(cl)   # Stop cluster to free resources
    registerDoSEQ()   # Return to sequential execution
    rm(cl)
    gc(verbose = FALSE)
  }
  
  # Postprocessing
  {
    set_point_optimized <- ga_result@solution[1, ]
    rm(ga_result)

    # convert_setpoints is called to split the best GA solution into
    # heating/cooling setpoint vectors and build the set_point_df with
    # hysteresis deadbands expected by period_calculation().
    set_point_optimized <- convert_setpoints(
      setpoints_heating = set_point_optimized[1:horizon],
      setpoints_cooling = set_point_optimized[(horizon + 1):(2 * horizon)],
      Deadband          = parameters$control$Deadband,
      target_periods    = timestamps$target_periods,
      pad_heating       = parameters$control$pad_heating,
      pad_cooling       = parameters$control$pad_cooling
    )
  }
  
  return(set_point_optimized)
}
