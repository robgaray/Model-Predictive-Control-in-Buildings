# -------------------------------------------------------------
# Function: optimize_modes.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function optimizes the control modes over a particular period
# using a Genetic Algorithm (GA) approach.
# It performs the following steps:
#   1. Defines the optimization vector based on the number of modes
#      and the number of market periods in the target period.
#   2. Initializes parallelization to speed up the optimization process.
#   3. Calls the GA optimizer to find the optimal control mode sequence
#      that maximizes the reward function.
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
#                      parameters$optimization (population_size,
#                        iteration_number, run_number, pcrossover, pmutation,
#                        parallel, as returned by load_optimization_parameters())
#   indexes        : Named list. Index metadata (passed through for
#                    interface consistency).
#
# Outputs
#   set_point_optimized : Data frame with setpoint columns and hysteresis
#                         deadbands for the optimal control modes,
#                         as returned by convert_modes_to_setpoints().
# -------------------------------------------------------------
# Code outline
# 1. Define GA chromosome structure for mode selection
# 2. Configure genetic algorithm parameters
# 3. Run GA optimization with mode fitness function
# 4. Extract best mode solution
# 5. Evaluate final control with best modes
# -------------------------------------------------------------
# Usage instructions
# result <- optimize_modes(period_chunk, timestamps, parameters, indexes)
# -------------------------------------------------------------
# Where this function/script is used
# Called by optimize_control_step.R when control_type is "modes".
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If all binary genes for a given market period are zero or NA, the
#     default mode 1 is assigned (fall-back to baseline mode).
#   - Parallelization uses all available logical cores minus one. The
#     cluster is stopped and sequential execution restored after the GA run.
#   - On Windows (PSOCK clusters), required functions and variables are
#     explicitly exported to worker processes via clusterExport().
#   - The GA uses binary encoding: n_modes * n_periods binary genes, where
#     the first n_periods genes correspond to mode_1, the next n_periods
#     to mode_2, and so on.
#   - Only the first solution row of the GA result (ga_result@solution[1,])
#     is used if multiple equally-fit solutions exist.
# -------------------------------------------------------------
# functions/scripts called
#   fitness_funct_optimize_mode()  - GA fitness function
#   maxmode()                      - selects highest-active mode per period
#   convert_modes_to_setpoints()   - maps mode selections to setpoint values
#   evaluate_control()             - building simulation and reward
#                                    (called inside fitness function)
#   period_calculation()           - core building physics simulation
#                                    (called inside evaluate_control)
#   flex_evaluation()              - flexibility event simulation
#                                    (called inside evaluate_control)
#   reward_function()              - reward calculation
#                                    (called inside evaluate_control)
# -------------------------------------------------------------
optimize_modes <- function(period_chunk,
                           timestamps,
                           parameters,
                           indexes
                           ) {
  # Optimization vector definition
  {
    # Number of market slots in the period (taken from target_periods)
    n_periods <- length(timestamps$target_periods)
    
    # Number of available control modes
    n_modes <- length(unique(parameters$setpoint_modes$mode))
    
    # Total number of binary genes for the GA
    n_genes <- n_modes * n_periods
  }

  # Create parameters2 with parallel disabled to avoid nested parallelism conflicts
  parameters2 <- parameters
  parameters2$optimization <- as.list(parameters$optimization)
  parameters2$debug_and_config <- as.list(parameters$debug_and_config)
  parameters2$debug_and_config$parallel <- 0
  
  # Parallelization initialization
  {
    if (parameters$debug_and_config$parallel == 1) {
      n_cores <- parallel::detectCores(logical = TRUE) - 1  # leave 1 core free
      cl <- makeCluster(n_cores)                             # works on Windows and Linux
      registerDoParallel(cl)                                 # register cluster for foreach
      
      # Important for Windows (PSOCK clusters) because child processes don't inherit the global environment
      clusterExport(
        cl,
        varlist = c(
          "evaluate_control",
          "convert_modes_to_setpoints",
          "period_calculation",
          "flex_evaluation",
          "reward_function",
          "period_chunk",
          "parameters2",
          "timestamps",
          "n_periods",
          "n_modes",
          "maxmode"
          ),
        envir = environment()
        )
    }
  }
  
  # Optimization (binary GA)
  ga_result <- ga(
    type       = "binary",
    nBits      = n_genes,
    popSize    = parameters$optimization$population_size,
    maxiter    = parameters$optimization$iteration_number,
    run        = parameters$optimization$run_number,
    pcrossover = parameters$optimization$pcrossover,
    pmutation  = parameters$optimization$pmutation,
    parallel   = (parameters$debug_and_config$parallel == 1),
    monitor    = FALSE,
    fitness    = function(x_bin) fitness_funct_optimize_mode(
                                   x_bin        = x_bin,
                                   n_modes      = n_modes,
                                   n_periods    = n_periods,
                                   timestamps   = timestamps,
                                   parameters   = parameters2,
                                   period_chunk = period_chunk
                                 )
  )
  
  # Stop cluster
  if (parameters$debug_and_config$parallel == 1) {
    stopCluster(cl)   # Stop cluster to free resources
    registerDoSEQ()   # Return to sequential execution
  }
  
  # Postprocessing
  {
    maxmode_result <- maxmode(
      x_bin          = ga_result@solution[1, ],
      n_modes        = n_modes,
      n_periods      = n_periods,
      target_periods = timestamps$target_periods
    )
    setpoint_modes_df_optimized <- maxmode_result$set_point_df_inner
    rm(ga_result)
    
    setpoint_modes_df_optimized <- convert_modes_to_setpoints(
      setpoint_modes_df = setpoint_modes_df_optimized,
      setpoint_modes    = parameters$setpoint_modes,
      Deadband          = parameters$control$Deadband,
      target_periods    = timestamps$target_periods
    )
  }

  return(setpoint_modes_df_optimized)
}
