load_control_parameters <- function(control_file) {
  
  # Setpoint parameters
  {
    df <- read.csv(control_file, comment.char = "#",
                   stringsAsFactors = FALSE)
    
    values <- as.list(df$value)
    names(values) <- df$parameter
    values <- lapply(values, as.numeric)
    
    set_point_range_heating <- c(values$set_point_range_heating_low,
                                 values$set_point_range_heating_high)
    
    set_point_range_cooling <- c(values$set_point_range_cooling_low,
                                 values$set_point_range_cooling_high)
    
    Deadband <- values$Deadband
  }
  
  cat("setpoint bands loaded\n")
  
  return(list(
    set_point_range_heating = set_point_range_heating,
    set_point_range_cooling = set_point_range_cooling,
    Deadband = Deadband
  ))
}
