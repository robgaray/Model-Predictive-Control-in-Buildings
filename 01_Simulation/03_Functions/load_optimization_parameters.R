load_optimization_parameters <- function(optimization_file) {
  
  df <- read.csv(optimization_file, comment.char = "#",
                 stringsAsFactors = FALSE)
  
  values <- as.list(df$value)
  names(values) <- df$parameter
  values <- lapply(values, as.numeric)
  
  # Optimization_parameters
  {
    optimization_parameters <- list(population_size        = values$population_size,
                                    iteration_number       = values$iteration_number,
                                    run_number             = values$run_number,
                                    optimization_horizon   = values$optimization_horizon,
                                    optimization_frequency = values$optimization_frequency,
                                    market_resolution      = values$market_resolution,
                                    month_subset           = values$month_subset,
                                    period_subset          = values$period_subset,
                                    verbose                = values$verbose
                                    )
    
    # Corrections
    if (optimization_parameters[["optimization_frequency"]] > optimization_parameters[["optimization_horizon"]]) {
      optimization_parameters[["optimization_frequency"]] <- optimization_parameters[["optimization_horizon"]]
    }
  }
  
  str(optimization_parameters)
  cat("optimization parameters loaded\n")
  
  return(optimization_parameters)
}
