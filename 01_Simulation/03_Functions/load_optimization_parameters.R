# -------------------------------------------------------------
# Function: load_optimization_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function reads a CSV configuration file containing optimization
# parameters for the MPC Genetic Algorithm (GA) and returns them as a
# validated named list.
# The CSV file must have at least two columns: 'parameter' and 'value'.
# Lines beginning with '#' are treated as comments and ignored.
# All values are coerced to numeric.
# After loading, seven consistency checks are applied and the parameters
# are automatically corrected (clamped) if they fall outside the allowed
# ranges, with a warning message printed for each correction.
# -------------------------------------------------------------
# Inputs
#   optimization_file : Character. Path to the CSV configuration file.
#                       Expected parameters in the file are:
#                         population_size                  – GA population size
#                         iteration_number                 – maximum GA iterations
#                         run_number                       – GA consecutive runs without improvement
#                         pcrossover                       – GA crossover probability [0, 1]
#                         pmutation                        – GA mutation probability [0, 1]
#                         control_optimization_horizon     – optimization look-ahead (hours)
#                         control_implementation_horizon   – control implementation window (hours)
#                         control_optimization_anticipation – anticipation offset (hours)
#                         market_resolution                – market period length (minutes)
#
# Outputs
#   A named list with the following elements (all numeric):
#     population_size                  : GA population size.
#     iteration_number                 : Maximum number of GA iterations.
#     run_number                       : Stopping criterion (consecutive runs without improvement).
#     pcrossover                       : GA crossover probability; clamped to [0, 1].
#     pmutation                        : GA mutation probability; clamped to [0, 1].
#     control_optimization_horizon     : Optimization horizon (hours); clamped to [2, 36].
#     control_implementation_horizon   : Implementation horizon (hours); clamped to [2, 24]
#                                        and further clamped to control_optimization_horizon.
#     control_optimization_anticipation: Anticipation offset (hours); clamped to [0, 12]
#                                        and further clamped to control_implementation_horizon - 1.
#     market_resolution                : Market period length (minutes).
# -------------------------------------------------------------
# Code outline
# 1. Read CSV configuration file
# 2. Convert to named list with numeric values
# -------------------------------------------------------------
# Usage instructions
# params <- load_optimization_parameters(file_path)
# -------------------------------------------------------------
# Where this function/script is used
# Called by control_optimization_parameters.R and control_optimization_parameters_SCC.R
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - Validation 1: pcrossover is clamped to the range [0, 1].
#   - Validation 2: pmutation is clamped to the range [0, 1].
#   - Validation 3: control_optimization_horizon is clamped to the range [2, 36] hours.
#   - Validation 4: control_implementation_horizon is clamped to the range [2, 24] hours.
#   - Validation 5: control_optimization_anticipation is clamped to the range [0, 12] hours.
#   - Validation 6: control_implementation_horizon must be <= control_optimization_horizon;
#                   if not, it is set equal to control_optimization_horizon.
#   - Validation 7: control_optimization_anticipation must be < control_implementation_horizon;
#                   if not, it is set to max(0, control_implementation_horizon - 1).
#   - For each automatic correction, a WARNING message is printed to the console.
#   - Non-numeric values in the CSV 'value' column will produce NA after coercion.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

load_optimization_parameters <- function(optimization_file) {
  
  df <- read.csv(optimization_file, comment.char = "#",
                 stringsAsFactors = FALSE)
  
  values <- as.list(df$value)
  names(values) <- df$parameter
  rm(df)
  values <- lapply(values, as.numeric)
  
  # Optimization_parameters
  {
    optimization_parameters <- list(population_size                   = values$population_size,
                                    iteration_number                  = values$iteration_number,
                                    run_number                        = values$run_number,
                                    pcrossover                        = values$pcrossover,
                                    pmutation                         = values$pmutation,
                                    control_optimization_horizon      = values$control_optimization_horizon,
                                    control_implementation_horizon    = values$control_implementation_horizon,
                                    control_optimization_anticipation = values$control_optimization_anticipation,
                                    market_resolution                 = values$market_resolution
                                    )
    rm(values)
    
    # Corrections
    # Validation 1: pcrossover must be >= 0 and <= 1
    if (optimization_parameters[["pcrossover"]] < 0) {
      optimization_parameters[["pcrossover"]] <- 0
      cat("WARNING: pcrossover has been set to 0 (minimum allowed value)\n")
    }
    if (optimization_parameters[["pcrossover"]] > 1) {
      optimization_parameters[["pcrossover"]] <- 1
      cat("WARNING: pcrossover has been set to 1 (maximum allowed value)\n")
    }
    
    # Validation 2: pmutation must be >= 0 and <= 1
    if (optimization_parameters[["pmutation"]] < 0) {
      optimization_parameters[["pmutation"]] <- 0
      cat("WARNING: pmutation has been set to 0 (minimum allowed value)\n")
    }
    if (optimization_parameters[["pmutation"]] > 1) {
      optimization_parameters[["pmutation"]] <- 1
      cat("WARNING: pmutation has been set to 1 (maximum allowed value)\n")
    }
    
    # Validation 3: control_optimization_horizon must be >= 2 and <= 36 hours
    if (optimization_parameters[["control_optimization_horizon"]] < 2) {
      optimization_parameters[["control_optimization_horizon"]] <- 2
      cat("WARNING: control_optimization_horizon has been set to 2 hours (minimum allowed value)\n")
    }
    if (optimization_parameters[["control_optimization_horizon"]] > 36) {
      optimization_parameters[["control_optimization_horizon"]] <- 36
      cat("WARNING: control_optimization_horizon has been set to 36 hours (maximum allowed value)\n")
    }
    
    # Validation 4: control_implementation_horizon must be >= 2 and <= 24 hours
    if (optimization_parameters[["control_implementation_horizon"]] < 2) {
      optimization_parameters[["control_implementation_horizon"]] <- 2
      cat("WARNING: control_implementation_horizon has been set to 2 hours (minimum allowed value)\n")
    }
    if (optimization_parameters[["control_implementation_horizon"]] > 24) {
      optimization_parameters[["control_implementation_horizon"]] <- 24
      cat("WARNING: control_implementation_horizon has been set to 24 hours (maximum allowed value)\n")
    }
    
    # Validation 5: control_optimization_anticipation must be >= 0 and <= 12 hours
    if (optimization_parameters[["control_optimization_anticipation"]] < 0) {
      optimization_parameters[["control_optimization_anticipation"]] <- 0
      cat("WARNING: control_optimization_anticipation has been set to 0 hours (minimum allowed value)\n")
    }
    if (optimization_parameters[["control_optimization_anticipation"]] > 12) {
      optimization_parameters[["control_optimization_anticipation"]] <- 12
      cat("WARNING: control_optimization_anticipation has been set to 12 hours (maximum allowed value)\n")
    }
    
    # Verification 6: control_implementation_horizon must be less than or equal to control_optimization_horizon
    if (optimization_parameters[["control_implementation_horizon"]] > optimization_parameters[["control_optimization_horizon"]]) {
      optimization_parameters[["control_implementation_horizon"]] <- optimization_parameters[["control_optimization_horizon"]]
      cat("WARNING: control_implementation_horizon has been set equal to control_optimization_horizon (", 
          optimization_parameters[["control_optimization_horizon"]], 
          ") because control_implementation_horizon must be less than or equal to control_optimization_horizon\n", sep = "")
    }
    
    # Verification 7: control_optimization_anticipation must be less than control_implementation_horizon
    if (optimization_parameters[["control_optimization_anticipation"]] >= optimization_parameters[["control_implementation_horizon"]]) {
      optimization_parameters[["control_optimization_anticipation"]] <- max(0, optimization_parameters[["control_implementation_horizon"]] - 1)
      cat("WARNING: control_optimization_anticipation has been set to ", 
          optimization_parameters[["control_optimization_anticipation"]], 
          " hours because control_optimization_anticipation must be less than control_implementation_horizon (", 
          optimization_parameters[["control_implementation_horizon"]], ")\n", sep = "")
    }
  }
  
  str(optimization_parameters)
  cat("optimization parameters loaded\n")
  
  return(optimization_parameters)
}
