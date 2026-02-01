# -------------------------------------------------------------
# Function: optimize_setpoints.R
# Part of the Model Predictive Control in buildings repository
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function optimizes heating and cooling setpoints over a
# particular period using a Genetic Algorithm (GA) approach.
# It performs the following steps:
#   1. Defines the optimization vectors based on the number of
#      market slots in the target period.
#   2. Initializes parallelization to speed up the optimization process.
#   3. Calls the GA optimizer to find the optimal control mode sequence
#      that maximizes the reward function.
#   4. Post-processes the optimization results to extract the optimal
#      control modes for each market period.
# -------------------------------------------------------------
optimize_setpoints <- function(period_chunk_optimize,
                               set_point_range_heating,
                               set_point_range_cooling,
                               parameters,
                               Deadband,
                               optimization_parameters) {
  
  # Optimization vector definition
  {
    horizon <- length(unique(period_chunk_optimize$MarketUTC))
    
    lower_bounds <- c(rep(set_point_range_heating[1],horizon),
                      rep(set_point_range_cooling[1],horizon))
    upper_bounds <- c(rep(set_point_range_heating[2],horizon),
                      rep(set_point_range_cooling[2],horizon))
    
  }
  
  # paralelization initialization
  {
    n_cores <- parallel::detectCores(logical = TRUE) - 1  # leave 1 core free
    cl <- makeCluster(n_cores)                             # works on Windows and Linux
    registerDoParallel(cl)                                 # register cluster for foreach
    
    # Important for Windows (PSOCK clusters) because child processes don't inherit the global environment
    clusterExport(
      cl,
      varlist = c(
        "evaluate_control_setpoints",
        "period_calculation",
        "reward_function",
        "period_chunk_optimize",
        "parameters",
        "Deadband",
        "optimization_parameters",
        "horizon"
      ),
      envir = environment()
    )
  }

  # Optimization (real type)
  ga_result <- ga(
    type = "real-valued",
    fitness = function(x) evaluate_control_setpoints(period_chunk_optimize,
                                                     setpoints_heating = x[1:horizon],
                                                     setpoints_cooling = x[(horizon+1):(2*horizon)],
                                                     parameters,
                                                     Deadband),
    lower = lower_bounds,
    upper = upper_bounds,
    popSize = optimization_parameters$population_size,
    maxiter = optimization_parameters$iteration_number,
    run = optimization_parameters$run_number,
    parallel = TRUE,
    monitor = FALSE
  )
  
  # Stop cluster
  stopCluster(cl)   # Stop cluster to free resources
  registerDoSEQ()   # Return to sequential execution
  
  # Postprocessing
  {
    set_point_optimized <- ga_result@solution[1, ]
    
    set_point_optimized_heating  <- set_point_optimized[1:horizon]
    set_point_optimized_cooling  <- set_point_optimized[(horizon+1):(2*horizon)]
    
    set_point_optimized<-list(set_point_optimized_heating,set_point_optimized_cooling)
  }
  
  return(set_point_optimized)
}
