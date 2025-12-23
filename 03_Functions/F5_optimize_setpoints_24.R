f5_optimize_setpoints_24 <- function(day_chunk_optimize,set_point_df_other,set_point_df_subset,model_parameters,Deadband,optimization_parameters) {
  with(optimization_parameters,{
    ga_result <- ga(
      type = "real-valued",
      fitness = function (x) f4_period_calculation_adapted (day_chunk_optimize,
                                                            set_point_df_other,set_point_df_subset,
                                                            setpoints=x,
                                                            model_parameters,Deadband),
      lower = set_point_df_subset$set_point_envelope_low,
      upper = set_point_df_subset$set_point_envelope_high,
      popSize = population_size,
      maxiter = iteration_number,
      run = run_number,
      monitor = FALSE
    )
    
    best_x <- ga_result@solution[1, ]
    
    return(best_x)
  })
  
  

}
