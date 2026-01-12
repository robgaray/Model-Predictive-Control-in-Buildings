f4_period_calculation_adapted <- function(day_chunk_optimize,
                                          setpoints_heating,
                                          setpoints_cooling,
                                          model_parameters,
                                          Deadband,
                                          optimization_parameters) {
  
  
  set_point_df<-data.frame(
    hour = unique(floor_date(day_chunk_optimize$HourUTC, unit = "hour"))
    )
  
  n_hours <- nrow(set_point_df)
  
  set_point_df$set_point_heating <- numeric(n_hours)
  set_point_df$set_point_cooling <- numeric(n_hours)
  
  n_setpoints <- length(setpoints_heating)

  if (n_setpoints > n_hours) {
    set_point_df$set_point_heating <- setpoints_heating[1:n_hours]
    set_point_df$set_point_cooling <- setpoints_cooling[1:n_hours]
  } else if (n_setpoints < n_hours) {
    set_point_df$set_point_heating <- c(setpoints_heating, rep(0, n_hours - n_setpoints))
    set_point_df$set_point_cooling <- c(setpoints_cooling, rep(50, n_hours - n_setpoints))
  } else {
    set_point_df$set_point_heating <- setpoints_heating
    set_point_df$set_point_cooling <- setpoints_cooling
  }
  
  set_point_df$set_point_heating_low  <- set_point_df$set_point_heating - Deadband/2
  set_point_df$set_point_heating_high <- set_point_df$set_point_heating + Deadband/2
  set_point_df$set_point_cooling_low  <- set_point_df$set_point_cooling - Deadband/2
  set_point_df$set_point_cooling_high <- set_point_df$set_point_cooling + Deadband/2
  
  # Calcular el período usando la función f3_period_calculation
  day_chunk_optimize <- f3_period_calculation(day_chunk_optimize, set_point_df, model_parameters)
  
  # Calcular reward total
  reward <- sum(day_chunk_optimize$reward)
  
  return(reward)
}
