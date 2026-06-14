# -------------------------------------------------------------
# Function: load_optimization_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function reads optimization hyperparameters for the GA
# from 14_Optimization_parameters.csv and returns them as a
# validated named list.
# -------------------------------------------------------------

load_optimization_parameters <- function(optimization_file) {

  df <- read.csv(
    optimization_file,
    comment.char      = "#",
    stringsAsFactors  = FALSE
  )

  values <- as.list(df$value)
  names(values) <- trimws(df$parameter)
  rm(df)

  value_num <- function(name) {
    if (is.null(values[[name]])) {
      return(NA_real_)
    }
    as.numeric(trimws(as.character(values[[name]])))
  }

  optimization_parameters <- list(
    population_size  = value_num("population_size"),
    iteration_number = value_num("iteration_number"),
    run_number       = value_num("run_number"),
    pcrossover       = value_num("pcrossover"),
    pmutation        = value_num("pmutation")
  )
  rm(values)

  if (is.na(optimization_parameters$population_size) ||
      optimization_parameters$population_size < 1) {
    stop("population_size must be a numeric value >= 1")
  }

  if (is.na(optimization_parameters$iteration_number) ||
      optimization_parameters$iteration_number < 1) {
    stop("iteration_number must be a numeric value >= 1")
  }

  if (is.na(optimization_parameters$run_number) ||
      optimization_parameters$run_number < 1) {
    stop("run_number must be a numeric value >= 1")
  }

  if (is.na(optimization_parameters$pcrossover)) {
    stop("pcrossover must be numeric")
  }
  if (optimization_parameters$pcrossover < 0) {
    optimization_parameters$pcrossover <- 0
    cat("WARNING: pcrossover has been set to 0 (minimum allowed value)\n")
  }
  if (optimization_parameters$pcrossover > 1) {
    optimization_parameters$pcrossover <- 1
    cat("WARNING: pcrossover has been set to 1 (maximum allowed value)\n")
  }

  if (is.na(optimization_parameters$pmutation)) {
    stop("pmutation must be numeric")
  }
  if (optimization_parameters$pmutation < 0) {
    optimization_parameters$pmutation <- 0
    cat("WARNING: pmutation has been set to 0 (minimum allowed value)\n")
  }
  if (optimization_parameters$pmutation > 1) {
    optimization_parameters$pmutation <- 1
    cat("WARNING: pmutation has been set to 1 (maximum allowed value)\n")
  }

  str(optimization_parameters)
  cat("optimization parameters loaded\n")

  return(optimization_parameters)
}
