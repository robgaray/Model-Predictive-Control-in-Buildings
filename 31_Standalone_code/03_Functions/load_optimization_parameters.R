# -------------------------------------------------------------
# Function: load_optimization_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function structures the already-parsed optimization
# hyperparameters for the GA (as read and validated by
# read_and_validate_parameter_csv() from 01_Optimization_parameters.csv)
# into a named list of numbers. Their presence and ranges are checked
# by read_and_validate_parameter_csv() against Parameter_config.csv,
# which stops execution on a missing or out-of-range value, so they
# are not checked again here.
# -------------------------------------------------------------
# Inputs
# values : Named list. Raw parameter/value pairs for optimization
#          parameters, as returned by read_and_validate_parameter_csv().
# -------------------------------------------------------------
# Outputs
# Named list with the elements:
#   - population_size
#   - iteration_number
#   - run_number
#   - pcrossover
#   - pmutation
# -------------------------------------------------------------
# Usage instructions
# params <- load_optimization_parameters(raw_values)
# -------------------------------------------------------------
# Code outline
# 1. Coerce each parameter to a number and name it.
# -------------------------------------------------------------
# Where this function/script is used
#   - load_parameters()
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

load_optimization_parameters <- function(values) {

  # -------------------------------------------------------------
  # 1. Coerce each parameter to a number and name it
  # -------------------------------------------------------------
  {
    value_num <- function(name) {
      as.numeric(trimws(as.character(values[[name]])))
    }

    optimization_parameters <- list(
      population_size  = value_num("population_size"),
      iteration_number = value_num("iteration_number"),
      run_number       = value_num("run_number"),
      pcrossover       = value_num("pcrossover"),
      pmutation        = value_num("pmutation")
    )

    rm(values, value_num)
  }

  return(optimization_parameters)
}
