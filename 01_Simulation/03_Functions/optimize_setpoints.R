# -------------------------------------------------------------
# Function: optimize_setpoints.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function optimizes heating and cooling setpoints over a
# particular period using a Genetic Algorithm (GA) approach.
# It performs the following steps:
#   1. Defines the optimization vectors based on the number of
#      market slots in the target period.
#   2. Initializes parallelization to speed up the optimization process.
#   3. Calls the GA optimizer to find the optimal setpoint sequence
#      that maximizes the reward function.
#   4. Post-processes the optimization results to extract the optimal
#      heating and cooling setpoints for each market period.
# -------------------------------------------------------------
# Inputs
#   period_chunk   : Data frame. Simulation data for the optimization
#                    horizon. Must contain a 'MarketUTC' column used to
#                    determine the number of market periods (horizon),
#                    plus all columns required by period_calculation()
#                    (called inside evaluate_control()).
#   timestamps     : Named list. Timestamp metadata. Must contain:
#                      timestamps$target_periods : POSIXct vector of
#                                                  market period timestamps.
#   parameters     : Named list. Model parameters passed through to
#                    period_calculation() and reward_function().
#                    The following sub-elements are extracted internally:
#                      parameters$control$set_point_range_heating
#                      parameters$control$set_point_range_cooling
#                      parameters$control$Deadband
#                      parameters$optimization (population_size,
#                        iteration_number, run_number, pcrossover, pmutation,
#                        parallel, as returned by load_optimization_parameters())
#   indexes        : Named list. Index metadata (passed through to
#                    fitness function for interface consistency).
#
# Outputs
#   set_point_optimized : Data frame with setpoint columns and hysteresis
#                         deadbands for the optimal heating and cooling
#                         setpoints, as returned by convert_setpoints().
# -------------------------------------------------------------
# Code outline
# 1. Build lower and upper bounds for heating/cooling setpoints
# 2. Configure genetic algorithm (GA) parameters
# 3. Run GA optimization with fitness function
# 4. Extract best setpoint solution
# 5. Evaluate final control with best setpoints
# -------------------------------------------------------------
# Usage instructions
# result <- optimize_setpoints(period_chunk, timestamps, parameters, indexes)
# -------------------------------------------------------------
# Where this function/script is used
# Called by optimize_control_step.R when control_type is "setpoint".
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - Parallelization uses all available logical cores minus one. The cluster
#     is stopped and sequential execution restored after the GA run.
#   - On Windows (PSOCK clusters), required functions and variables are
#     explicitly exported to worker processes via clusterExport().
#   - The GA uses real-valued encoding: 2 * horizon real genes, where the
#     first 'horizon' genes are heating setpoints and the next 'horizon'
#     genes are cooling setpoints.
#   - The GA optimization vector has lower bounds set to set_point_range_heating[1]
#     and set_point_range_cooling[1], and upper bounds to set_point_range_heating[2]
#     and set_point_range_cooling[2].
#   - Only the first solution row of the GA result (ga_result@solution[1,])
#     is used if multiple equally-fit solutions exist.
# -------------------------------------------------------------
# functions/scripts called
#   fitness_funct_optimize_setpoint() - GA fitness function
#   convert_setpoints()               - converts raw setpoints to data frame
#                                       with hysteresis deadbands
#   evaluate_control()                - building simulation and reward
#                                       (called inside fitness function)
#   period_calculation()              - core building physics simulation
#                                       (called inside evaluate_control)
#   flex_evaluation()                 - flexibility event simulation
#                                       (called inside evaluate_control)
#   reward_function()                 - reward calculation
#                                       (called inside evaluate_control)
# -------------------------------------------------------------
optimize_setpoints <- function(period_chunk,
                               timestamps,
                               parameters,
                               indexes
                               ) {
  # Optimization vector definition
  {
    horizon <- length(timestamps$target_periods)
    
    lower_bounds <- c(rep(parameters$control$set_point_range_heating[1], horizon),
                      rep(parameters$control$set_point_range_cooling[1], horizon))
    upper_bounds <- c(rep(parameters$control$set_point_range_heating[2], horizon),
                      rep(parameters$control$set_point_range_cooling[2], horizon))
    
  }

  # Create parameters2 with parallel disabled to avoid nested parallelism conflicts
  parameters2 <- parameters
  parameters2$optimization <- as.list(parameters$optimization)
  parameters2$debug_and_config <- as.list(parameters$debug_and_config)
  parameters2$debug_and_config$parallel <- 0
  
  # Parallelization initialization
  {
    if (parameters$debug_and_config$parallel == 1) {
      n_cores <- parallel::detectCores(logical = TRUE) - 1  # leave 1 core free
      cl <- makeCluster(n_cores)                             # works on Windows and Linux
      registerDoParallel(cl)                                 # register cluster for foreach
      
      # Important for Windows (PSOCK clusters) because child processes don't inherit the global environment
      clusterExport(
        cl,
        varlist = c(
          "evaluate_control",
          "convert_setpoints",
          "period_calculation",
          "flex_evaluation",
          "reward_function",
          "period_chunk",
          "parameters2",
          "horizon",
          "timestamps"
        ),
        envir = environment()
      )
    }
  }

  # Optimization (real-valued GA)
  ga_result <- ga(
    type       = "real-valued",
    fitness    = function(x) fitness_funct_optimize_setpoint(
                               setpoint_array = x,
                               period_chunk   = period_chunk,
                               parameters     = parameters2,
                               timestamps     = timestamps
                             ),
    lower      = lower_bounds,
    upper      = upper_bounds,
    popSize    = parameters$optimization$population_size,
    maxiter    = parameters$optimization$iteration_number,
    run        = parameters$optimization$run_number,
    pcrossover = parameters$optimization$pcrossover,
    pmutation  = parameters$optimization$pmutation,
    parallel   = (parameters$debug_and_config$parallel == 1),
    monitor    = FALSE
  )
  
  # Stop cluster
  if (parameters$debug_and_config$parallel == 1) {
    stopCluster(cl)   # Stop cluster to free resources
    registerDoSEQ()   # Return to sequential execution
  }
  
  # Postprocessing
  {
    set_point_optimized <- ga_result@solution[1, ]
    rm(ga_result)
    
    set_point_optimized <- convert_setpoints(
      setpoints_heating = set_point_optimized[1:horizon],
      setpoints_cooling = set_point_optimized[(horizon + 1):(2 * horizon)],
      Deadband          = parameters$control$Deadband,
      target_periods    = timestamps$target_periods
    )
  }
  
  return(set_point_optimized)
}
