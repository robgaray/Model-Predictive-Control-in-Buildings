f3_period_calculation <- function(day_chunk_optimize, set_point_df, model_parameters) {
  for (i in 1:(nrow(day_chunk_optimize)-1)) {
    timestep_chunk<-day_chunk_optimize[c(i,i+1),]
    timestep_chunk <- f1_timestep_calculation(timestep_chunk, set_point_df, model_parameters)
    day_chunk_optimize[c(i,i+1),]<-timestep_chunk
    rm(timestep_chunk)
  }
  return(day_chunk_optimize)
}
