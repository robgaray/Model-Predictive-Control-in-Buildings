f5_optimize_setpoints_24 <- function(day_chunk_optimize,
                                     set_point_range_heating,
                                     set_point_range_cooling,
                                     model_parameters,
                                     Deadband,
                                     optimization_parameters) {
  
  horizon<- optimization_parameters$optimization_horizon
  
  horizon <- min(horizon,(as.numeric(day_chunk_optimize$HourUTC_hour[length(day_chunk_optimize$HourUTC_hour)]-day_chunk_optimize$HourUTC_hour[1])+1))
  
  lower_bounds <- c(rep(set_point_range_heating[1],horizon),
                    rep(set_point_range_cooling[1],horizon))
  upper_bounds <- c(rep(set_point_range_heating[2],horizon),
                    rep(set_point_range_cooling[2],horizon))
  
  
  # paralelization initialization
  {
    n_cores <- parallel::detectCores(logical = TRUE) - 1  # leave 1 core free
    cl <- makeCluster(n_cores)                             # works on Windows and Linux
    registerDoParallel(cl)                                 # register cluster for foreach
  }
  
  # Important for Windows (PSOCK clusters) because child processes don't inherit the global environment
  {
    clusterExport(
      cl,
      varlist = c(
        "f4_period_calculation_adapted",
        "day_chunk_optimize",
        "model_parameters",
        "Deadband",
        "optimization_parameters",
        "horizon"
      ),
      envir = environment()
    )
  }
  
  # Optimization
  ga_result <- ga(
    type = "real-valued",
    fitness = function(x) f4_period_calculation_adapted(
      day_chunk_optimize,
      setpoints_heating = x[1:horizon],
      setpoints_cooling = x[(horizon+1):(2*horizon)],
      model_parameters,
      Deadband,
      optimization_parameters
    ),
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
