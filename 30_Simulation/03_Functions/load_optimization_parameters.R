# -------------------------------------------------------------
# Function: load_optimization_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function structures the already-parsed optimization
# hyperparameters for the GA (as read and validated by
# read_and_validate_parameter_csv() from 14_Optimization_parameters.csv)
# into a validated named list, clamping out-of-range values.
# -------------------------------------------------------------
# Inputs
# values : Named list. Raw parameter/value pairs for optimization
#          parameters, as returned by read_and_validate_parameter_csv().
# -------------------------------------------------------------
# Outputs
# Named list with population_size, iteration_number, run_number,
# pcrossover, pmutation.
# -------------------------------------------------------------
# Usage instructions
# params <- load_optimization_parameters(raw_values)
# -------------------------------------------------------------
# Where this function/script is used
# Called by load_14_optimization_parameters.R.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

load_optimization_parameters <- function(values) {

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
