f4_period_calculation_adapted <- function(day_chunk_optimize,
                                          set_point_df_other,
                                          set_point_df_subset,
                                          setpoints,
                                          model_parameters,
                                          Deadband) {
  
  # Crear copia del subset con los setpoints a optimizar
  set_point_df_actual <- set_point_df_subset
  set_point_df_actual$set_point <- setpoints
  set_point_df_actual$set_point_low <- set_point_df_actual$set_point - Deadband / 2
  set_point_df_actual$set_point_high <- set_point_df_actual$set_point + Deadband / 2
  
  # Proteger set_point_df_other si está vacío
  if (nrow(set_point_df_other) > 0) {
    set_point_df_other$set_point <- NA_real_
    set_point_df_other$set_point_low <- NA_real_
    set_point_df_other$set_point_high <- NA_real_
  }
  
  # Combinar los dos data.frames y ordenar por datetime
  set_point_df_actual <- rbind(set_point_df_other, set_point_df_actual) %>% arrange(datetime)
  
  # Calcular el período usando la función f3_period_calculation
  day_chunk_optimize <- f3_period_calculation(day_chunk_optimize, set_point_df_actual, model_parameters)
  
  # Calcular reward total
  reward <- sum(day_chunk_optimize$reward)
  
  return(reward)
}
