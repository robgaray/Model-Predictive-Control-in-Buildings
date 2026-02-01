# -------------------------------------------------------------
# Function: optimize_modes.R
# Part of the Model Predictive Control in buildings repository
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function optimizes the control modes over a particular period
# using a Genetic Algorithm (GA) approach.
# It performs the following steps:
#   1. Defines the optimization vector based on the number of modes
#      and the number of market periods in the target period.
#   2. Initializes parallelization to speed up the optimization process.
#   3. Calls the GA optimizer to find the optimal control mode sequence
#      that maximizes the reward function.
#   4. Post-processes the optimization results to extract the optimal
#      control modes for each market period.
# -------------------------------------------------------------
optimize_modes <- function(period_chunk,
                           setpoint_modes,
                           parameters,
                           Deadband,
                           optimization_parameters) {
  
  # Optimization vector definition
  {
    # Number of market slots in the period.
    # taken from MarketUTC in period_chunk
    periods_target <- unique(period_chunk$MarketUTC)
    n_periods <- length(periods_target)
    
    # Number of modes 
    n_modes <- length(unique(setpoint_modes$mode))
    
    # Total number of genes to consider in the optimization
    n_genes <- n_modes * n_periods
  }
  
  # paralelization initialization
  {
    n_cores <- parallel::detectCores(logical = TRUE) - 1  # leave 1 core free
    cl <- makeCluster(n_cores)                             # works on Windows and Linux
    registerDoParallel(cl)                                 # register cluster for foreach
    
    # Important for Windows (PSOCK clusters) because child processes don't inherit the global environment
    clusterExport(
      cl,
      varlist = c(
        "evaluate_control_mode",
        "period_calculation",
        "reward_function",
        "period_chunk",
        "setpoint_modes",
        "parameters",
        "Deadband",
        "optimization_parameters",
        "n_periods",
        "n_modes",
        "periods_target"
        ),
      envir = environment()
      )
  }
  
  # Optimization (binary type)
  ga_result <- ga(
    type = "binary",
    nBits = n_genes,
    popSize = optimization_parameters$population_size,
    maxiter = optimization_parameters$iteration_number,
    run = optimization_parameters$run_number,
    # parallel = TRUE,
    monitor = FALSE,
    fitness = function(x_bin) evaluate_control_mode(period_chunk,
                                                    setpoint_modes,
                                                    setpoint_modes_actual = x_bin,
                                                    parameters,
                                                    Deadband,
                                                    periods_target = periods_target  # PASAR periods_target
    )
  )
  
  # Stop cluster
  stopCluster(cl)   # Stop cluster to free resources
  registerDoSEQ()   # Return to sequential execution
  
  # Postprocessing
  {
    setpoint_modes_optimized <- ga_result@solution[1, ]
    
    setpoint_modes_df_optimized <- data.frame(period = periods_target)
    
    for (i in seq_len(n_modes)) {
      setpoint_modes_df_optimized[[paste0("mode_", i)]] <-
        setpoint_modes_optimized[((i-1)*n_periods + 1):(i*n_periods)]
    }
    
    # Calcular maxmode
    mode_cols <- setdiff(colnames(setpoint_modes_df_optimized), "period")
    setpoint_modes_df_optimized$maxmode <- apply(
      setpoint_modes_df_optimized[, mode_cols],
      1,
      function(x) {
        if (all(is.na(x)) || sum(x, na.rm = TRUE) == 0) {
          return(1)  # modo por defecto
        } else {
          # Extraer índice del nombre de columna: "mode_1" → 1
          idx <- which.max(x)
          return(as.numeric(sub("mode_", "", mode_cols[idx])))
        }
      }
    )
    
    # Eliminar columnas de modo binario
    setpoint_modes_df_optimized <- setpoint_modes_df_optimized[, c("period", "maxmode")]
    
  }
  
  return(setpoint_modes_df_optimized)
}
