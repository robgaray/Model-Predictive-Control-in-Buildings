# -------------------------------------------------------------
# Function: load_debug_and_config_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function reads a CSV configuration file containing debug and
# configuration parameters and returns them as a named list.
# The CSV file must have at least two columns: 'parameter' and 'value'.
# Lines beginning with '#' are treated as comments and ignored.
# All values are coerced to numeric.
# -------------------------------------------------------------
# Inputs
#   debug_and_config_file : Character. Path to the CSV configuration file.
#                           Expected parameters in the file are:
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
# 1. Read CSV configuration file
# 2. Convert to named list with numeric values
# -------------------------------------------------------------
# Usage instructions
# params <- load_debug_and_config_parameters(file_path)
# -------------------------------------------------------------
# Where this function/script is used
# Called by control_optimization_parameters.R and control_optimization_parameters_SCC.R
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

load_debug_and_config_parameters <- function(debug_and_config_file) {
  
  df <- read.csv(debug_and_config_file, comment.char = "#",
                 stringsAsFactors = FALSE)
  
  values <- as.list(df$value)
  names(values) <- trimws(df$parameter)
  rm(df)
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
