load_model_parameters <- function(model_file) {
  
  # Model parameters
  {
    df <- read.csv(model_file, comment.char = "#",
                   stringsAsFactors = FALSE)
    
    model_parameters <- as.list(df$value)
    names(model_parameters) <- df$parameter
    model_parameters <- lapply(model_parameters, as.numeric)
  }
  
  cat("model parameters loaded\n")
  return(model_parameters)
}
