load_parameters <- function(file) {
  
  # Model parameters
  {
    df <- read.csv(file, comment.char = "#",
                   stringsAsFactors = FALSE)
    
    parameters <- as.list(df$value)
    names(parameters) <- df$parameter
    parameters <- lapply(parameters, as.numeric)
  }
  
  cat("model parameters loaded\n")
  return(parameters)
}
