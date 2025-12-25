f5_optimize_setpoints_24 <- function(day_chunk_optimize,set_point_df_other,set_point_df_subset,model_parameters,Deadband,optimization_parameters) {
  if (nrow(set_point_df_subset) == 0) {
    warning("set_point_df_subset vacío: no se realizará optimización en este período.")
    return(numeric(0))
  }
  
  lower_bounds <- set_point_df_subset$set_point_envelope_low
  upper_bounds <- set_point_df_subset$set_point_envelope_high
    
  ga_result <- ga(
    type = "real-valued",
    fitness = function(x) f4_period_calculation_adapted(
      day_chunk_optimize,
      set_point_df_other,
      set_point_df_subset,
      setpoints = x,
      model_parameters,
      Deadband
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
