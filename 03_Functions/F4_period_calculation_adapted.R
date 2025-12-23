f4_period_calculation_adapted<-function (day_chunk_optimize,
                                         set_point_df_other,set_point_df_subset,
                                         setpoints,
                                         model_parameters,Deadband)
{
  set_point_df_actual<-set_point_df_subset
  set_point_df_actual$set_point<-setpoints
  set_point_df_actual$set_point_low <-set_point_df_actual$set_point - Deadband/2
  set_point_df_actual$set_point_high<-set_point_df_actual$set_point + Deadband/2
  
  set_point_df_other$set_point<-NA
  set_point_df_other$set_point_low<-NA
  set_point_df_other$set_point_high<-NA
  
  set_point_df_actual<-rbind(set_point_df_other,set_point_df_actual) %>% arrange(datetime)
  
  day_chunk_optimize<-f3_period_calculation(day_chunk_optimize, set_point_df_actual, model_parameters)
  
  reward<-sum(day_chunk_optimize$reward)
  
  return(reward)
}