# -------------------------------------------------------------
# Function: load_debug_and_config_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function structures the already-parsed debug and
# configuration parameters (as read and validated by
# read_and_validate_parameter_csv() from 30_Debug_and_config.csv) into
# a named list. All values are coerced to numeric.
# -------------------------------------------------------------
# Inputs
#   values : Named list. Raw parameter/value pairs for debug and
#            config parameters, as returned by
#            read_and_validate_parameter_csv(). Expected parameters are:
#                             month_subset    – month filter (0 = all months, 1-12 = specific month)
#                             period_subset   – period filter (0 = all periods, >0 = limit timesteps)
#                             verbose         – verbosity flag (0 = silent, 1 = print progress)
#                             parallel        – parallelization flag (1 = parallel, 0 = sequential)
#                             Price_emulation – price emulation flag (1 = enabled, 0 = disabled)
#
# Outputs
#   A named list with the following elements:
#     month_subset    : Month filter index (numeric).
#     period_subset   : Period filter index (numeric).
#     verbose         : Verbosity flag converted to logical (TRUE/FALSE).
#     parallel        : Parallelization flag (numeric, 1 or 0).
#     Price_emulation : Price emulation flag (numeric, 1 or 0).
# -------------------------------------------------------------
# Code outline
# 1. Coerce all values to numeric
# 2. Build named list, converting verbose to logical (== 1)
# -------------------------------------------------------------
# Usage instructions
# params <- load_debug_and_config_parameters(raw_values)
# -------------------------------------------------------------
# Where this function/script is used
# Called by load_30_debug_and_config.R.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

load_debug_and_config_parameters <- function(values) {

  values <- lapply(values, function(x) as.numeric(trimws(as.character(x))))
  
  debug_and_config_parameters <- list(
    month_subset    = values$month_subset,
    period_subset   = values$period_subset,
    verbose         = (values$verbose == 1),
    parallel        = values$parallel,
    Price_emulation = values$Price_emulation
  )
  rm(values)
  
  str(debug_and_config_parameters)
  cat("debug and config parameters loaded\n")
  
  return(debug_and_config_parameters)
}
