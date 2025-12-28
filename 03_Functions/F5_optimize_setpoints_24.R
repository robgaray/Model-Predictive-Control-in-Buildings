f5_optimize_setpoints_24 <- function(day_chunk_optimize,set_point_range_heating,model_parameters,Deadband,optimization_parameters) {
  lower_bounds <- rep(set_point_range_heating[1],optimization_parameters$optimization_horizon)
  upper_bounds <- rep(set_point_range_heating[2],optimization_parameters$optimization_horizon)
  
  ga_result <- ga(
    type = "real-valued",
    fitness = function(x) f4_period_calculation_adapted(
      day_chunk_optimize,
      setpoints = x,
      model_parameters,
      Deadband,
      optimization_parameters
    ),
    lower = lower_bounds,
    upper = upper_bounds,
    popSize = optimization_parameters$population_size,
    maxiter = optimization_parameters$iteration_number,
    run = optimization_parameters$run_number,
    monitor = FALSE
  )
    
    best_x <- ga_result@solution[1, ]
    
    return(best_x)
}
