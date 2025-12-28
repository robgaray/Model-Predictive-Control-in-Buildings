f4_period_calculation_adapted <- function(day_chunk_optimize,
                                          setpoints,
                                          model_parameters,
                                          Deadband,
                                          optimization_parameters) {
  set_point_df<-as.data.frame(unique(floor_date(day_chunk_optimize$HourUTC, unit = "hour")))
  names(set_point_df)<-"hour"
  set_point_df$set_point_heating<-c(setpoints,0)
  set_point_df$set_point_heating_low <-set_point_df$set_point_heating - Deadband/2
  set_point_df$set_point_heating_high<-set_point_df$set_point_heating + Deadband/2
  
  # Calcular el período usando la función f3_period_calculation
  day_chunk_optimize <- f3_period_calculation(day_chunk_optimize, set_point_df, model_parameters)
  
  # Calcular reward total
  reward <- sum(day_chunk_optimize$reward)
  
  return(reward)
}
