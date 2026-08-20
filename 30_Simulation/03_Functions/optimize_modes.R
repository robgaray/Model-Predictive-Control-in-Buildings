# -------------------------------------------------------------
# File: optimize_modes.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This file contains the main function optimize_modes() and auxiliary
# functions for genetic algorithm operations with integer mode variables.
# Functions in this file:
#   - optimize_modes() : Main optimization function
#   - ga_population_int() : Custom population generator for integer modes
#   - ga_crossover_int() : Custom crossover operator for integer modes
#   - ga_mutation_int() : Custom mutation operator for integer modes
# Used by: optimize_control_step.R when control_type is "modes".
# Purpose: Optimize control modes over a period using GA with native
#          integer handling (no one-hot encoding or artificial clipping).
# -------------------------------------------------------------

# -------------------------------------------------------------
# Function: ga_population_int
# -------------------------------------------------------------
# Custom population generator for the genetic algorithm that creates
# initial population with integer values representing mode indices.
# Each gene is a valid mode index in the range [1, n_modes].
# -------------------------------------------------------------
# Inputs
#   object : GA object (from ga package) containing lower and upper bounds
#
# Outputs
#   matrix : Population matrix where each row is an individual (chromosome)
#            and each column is a gene (mode index for one market period).
#            All values are integers in the range defined by lower/upper bounds.
# -------------------------------------------------------------
# Usage instructions
# population <- ga_population_int(object)
# -------------------------------------------------------------
# Where this function/script is used
# Called by ga() as the population argument in optimize_modes().
# -------------------------------------------------------------
# functions/scripts called
#   (none - uses only base R)
# -------------------------------------------------------------
ga_population_int <- function(object) {
  
  # Extract bounds from GA object
  lower <- as.integer(object@lower)
  upper <- as.integer(object@upper)
  
  # Number of genes (market periods)
  n_genes <- length(lower)
  
  # Population size
  pop_size <- object@popSize
  
  # Initialize population matrix
  population <- matrix(0L, nrow = pop_size, ncol = n_genes)
  
  # Generate random integers for each individual
  {
    for (CONT_001 in seq_len(pop_size)) {
      for (CONT_002 in seq_len(n_genes)) {
        population[CONT_001, CONT_002] <- sample(
          x    = seq.int(lower[CONT_002], upper[CONT_002]),
          size = 1
        )
      }
    }
  }
  
  return(population)
}

# -------------------------------------------------------------
# Function: ga_crossover_int
# -------------------------------------------------------------
# Custom crossover operator for integer mode variables.
# Performs uniform crossover using the actual parent chromosomes
# selected by GA from object@population.
# All output values remain integers within the same discrete domain
# already present in the parent chromosomes.
# -------------------------------------------------------------
# Inputs
#   object   : GA object (from ga package)
#   parents  : Integer vector with the row indexes of the selected parents
#              in object@population.
#
# Outputs
#   list with two elements:
#     children : Matrix with 2 rows (offspring chromosomes) and n_genes columns,
#                containing integer mode indices.
#     fitness  : Numeric vector of length 2 with NA values (fitness will be
#                evaluated separately by GA).
# -------------------------------------------------------------
# Usage instructions
# offspring <- ga_crossover_int(object, parents)
# -------------------------------------------------------------
# Where this function/script is used
# Called by ga() as the crossover argument in optimize_modes().
# -------------------------------------------------------------
# functions/scripts called
#   (none - uses only base R)
# -------------------------------------------------------------
ga_crossover_int <- function(object, parents, ...) {
  
  # Extract parent chromosomes from current GA population
  parent1 <- object@population[parents[1], ]
  parent2 <- object@population[parents[2], ]
  
  # Number of genes
  n_genes <- length(parent1)
  
  # Initialize offspring
  child1 <- integer(n_genes)
  child2 <- integer(n_genes)
  
  # Uniform crossover: for each gene, randomly select parent
  {
    for (CONT_001 in seq_len(n_genes)) {
      if (runif(1) < 0.5) {
        child1[CONT_001] <- as.integer(parent1[CONT_001])
        child2[CONT_001] <- as.integer(parent2[CONT_001])
      } else {
        child1[CONT_001] <- as.integer(parent2[CONT_001])
        child2[CONT_001] <- as.integer(parent1[CONT_001])
      }
    }
  }
  
  # Return offspring
  offspring <- list(
    children = rbind(child1, child2),
    fitness  = c(NA_real_, NA_real_)
  )
  
  return(offspring)
}

# -------------------------------------------------------------
# Function: ga_mutation_int
# -------------------------------------------------------------
# Custom mutation operator for integer mode variables.
# Receives the selected parent chromosome from object@population and,
# for each gene, with probability pmutation, replaces the current
# mode index with a randomly selected valid mode index.
# All output values remain integers within the declared bounds.
# -------------------------------------------------------------
# Inputs
#   object   : GA object (from ga package) containing lower and upper bounds
#   parent   : Integer scalar with the row index of the selected parent
#              in object@population.
#
# Outputs
#   Numeric vector representing the mutated chromosome (integer mode indices)
# -------------------------------------------------------------
# Usage instructions
# mutated <- ga_mutation_int(object, parent)
# -------------------------------------------------------------
# Where this function/script is used
# Called by ga() as the mutation argument in optimize_modes().
# -------------------------------------------------------------
# functions/scripts called
#   (none - uses only base R)
# -------------------------------------------------------------
ga_mutation_int <- function(object, parent, ...) {
  
  # Extract bounds
  lower <- as.integer(object@lower)
  upper <- as.integer(object@upper)
  
  # Mutation probability
  pmutation <- object@pmutation
  
  # Extract parent chromosome from current GA population
  mutant <- as.integer(object@population[parent, ])
  
  # Number of genes
  n_genes <- length(mutant)
  
  # Apply mutation
  {
    for (CONT_001 in seq_len(n_genes)) {
      if (runif(1) < pmutation) {
        mutant[CONT_001] <- sample(
          x    = seq.int(lower[CONT_001], upper[CONT_001]),
          size = 1
        )
      }
    }
  }
  
  return(mutant)
}

# -------------------------------------------------------------
# Function: optimize_modes
# -------------------------------------------------------------
# This function optimizes the control modes over a particular period
# using a Genetic Algorithm (GA) approach with real-type genes that
# are constrained to integer values through custom population,
# crossover, and mutation operators.
# It performs the following steps:
#   1. Defines the optimization vector based on the number of modes
#      and the number of market periods in the target period.
#   2. Initializes parallelization to speed up the optimization process.
#   3. Calls the GA optimizer with custom integer-handling operators
#      to find the optimal control mode sequence that maximizes the
#      reward function.
#   4. Post-processes the optimization results to extract the optimal
#      control modes for each market period.
# -------------------------------------------------------------
# Inputs
#   period_chunk   : Data frame. Simulation data for the optimization
#                    horizon. Must contain a 'MarketUTC' column used to
#                    derive the set of target periods, plus all columns
#                    required by period_calculation() (called inside
#                    evaluate_control()).
#   timestamps     : Named list. Timestamp metadata. Must contain:
#                      timestamps$target_periods : POSIXct vector of
#                                                  market period timestamps.
#   parameters     : Named list. Model parameters passed through to
#                    period_calculation() and reward_function().
#                    The following sub-elements are extracted internally:
#                      parameters$setpoint_modes
#                      parameters$control$Deadband
#                      parameters$optimization (population_size,
#                        iteration_number, run_number, pcrossover, pmutation,
#                        parallel, as returned by load_optimization_parameters())
#   simulation_control : Named list. Index/step metadata (passed through for
#                    interface consistency).
#   marginal_context : Named list or NULL. Passed through to the fitness
#                    function and, via clusterExport(), to worker processes.
#
# Outputs
#   set_point_optimized : Data frame with setpoint columns and hysteresis
#                         deadbands for the optimal control modes,
#                         as returned by convert_modes_to_setpoints().
# -------------------------------------------------------------
# Code outline
# 1. Define GA chromosome structure for mode selection (integer vector)
# 2. Configure genetic algorithm parameters with custom operators
# 3. Initialize parallelization
# 4. Run GA optimization with mode fitness function
# 5. Stop cluster (if parallel)
# 6. Post-process: extract best mode solution and convert to setpoints
# -------------------------------------------------------------
# Usage instructions
# result <- optimize_modes(period_chunk, timestamps, parameters, simulation_control)
# -------------------------------------------------------------
# Where this function/script is used
# Called by optimize_control_step.R when control_type is "modes".
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - Parallelization uses all available logical cores minus one. The
#     cluster is stopped and sequential execution restored after the GA run.
#   - On Windows (PSOCK clusters), required functions and variables are
#     explicitly exported to worker processes via clusterExport().
#   - The GA uses real-type encoding with custom integer operators: n_periods
#     genes, each representing a mode index (1 to n_modes).
#   - The custom operators read the selected parent chromosomes from the
#     current GA population to keep the representation valid from the start.
#   - Only the first solution row of the GA result (ga_result@solution[1,])
#     is used if multiple equally-fit solutions exist.
# -------------------------------------------------------------
# functions/scripts called
#   ga_population_int()            - custom population generator (this file)
#   ga_crossover_int()             - custom crossover operator (this file)
#   ga_mutation_int()              - custom mutation operator (this file)
#   fitness_funct_optimize_mode()  - GA fitness function
#   maxmode()                      - pairs the best GA solution with target_periods
#   convert_modes_to_setpoints()   - maps mode selections to setpoint values
#   evaluate_control()             - building simulation and reward
#                                    (called inside fitness function)
#   period_calculation()           - core building physics simulation
#                                    (called inside evaluate_control)
#   flex_evaluation()              - flexibility event simulation
#                                    (called inside evaluate_control)
#   reward_function()              - reward calculation
#                                    (called inside evaluate_control)
#   compute_marginal_energy_cost() - marginal cash flow, base-energy term
#                                    (called inside reward_function, when
#                                    marginal_context is provided)
#   compute_marginal_distribution_cost() - marginal distribution cost
#                                    (called inside reward_function, when
#                                    marginal_context is provided)
#   compute_marginal_flex_revenue() - marginal cash flow, explicit
#                                    flexibility term (called inside
#                                    reward_function, flexibility/
#                                    operationflex modes only)
# -------------------------------------------------------------
optimize_modes <- function(period_chunk,
                           timestamps,
                           parameters,
                           simulation_control,
                           marginal_context = NULL
                           ) {
  
  # 1. Define GA chromosome structure for mode selection (integer vector)
  # -------------------------------------------------------------
  # One integer gene per market period, bounded in [1, n_modes].
  # Each gene directly encodes a valid mode index.
  # -------------------------------------------------------------
  {
    n_periods    <- length(timestamps$target_periods)
    n_modes      <- length(unique(parameters$setpoint_modes$mode))
    lower_bounds <- rep(1, n_periods)
    upper_bounds <- rep(n_modes, n_periods)
  }

  # 2. Configure genetic algorithm parameters with custom operators
  # -------------------------------------------------------------
  # Create parameters2 with parallel disabled to avoid nested
  # parallelism conflicts inside fitness function evaluations.
  # -------------------------------------------------------------
  {
    parameters2                           <- parameters
    parameters2$optimization              <- as.list(parameters$optimization)
    parameters2$debug_and_config          <- as.list(parameters$debug_and_config)
    parameters2$debug_and_config$parallel <- 0
  }

  # 3. Initialize parallelization
  # -------------------------------------------------------------
  # If parallel is enabled, create a cluster and export all objects
  # needed by the fitness function to the worker processes.
  # On Windows (PSOCK clusters), child processes do not inherit the
  # global environment, so explicit export is required.
  # -------------------------------------------------------------
  {
    if (parameters$debug_and_config$parallel == 1) {
      n_cores <- parallel::detectCores(logical = TRUE) - 1
      cl      <- makeCluster(n_cores)
      registerDoParallel(cl)

      clusterExport(
        cl,
        varlist = c(
          "fitness_funct_optimize_mode",
          "evaluate_control",
          "maxmode",
          "convert_modes_to_setpoints",
          "period_calculation",
          "flex_evaluation",
          "reward_function",
          "compute_marginal_energy_cost",
          "compute_marginal_distribution_cost",
          "compute_marginal_flex_revenue",
          "calc_differential_cost",
          "split_market_operation",
          "value_flex_operation",
          "initialize_plan_flex_columns",
          "period_chunk",
          "parameters2",
          "timestamps",
          "n_periods",
          "n_modes",
          "simulation_control",
          "marginal_context"
          ),
        envir = environment()
        )

      # Compile C++ simulation module on each worker process
      clusterExport(
        cl,
        "cpp_source_path",
        envir = globalenv()
      )
      clusterEvalQ(
        cl,
        Rcpp::sourceCpp(cpp_source_path)
      )
    }
  }

  # 4. Run GA optimization with mode fitness function
  # -------------------------------------------------------------
  # ga() is called with type="real-valued" and custom population,
  # crossover, and mutation functions that preserve the integer
  # representation by operating on chromosomes stored in the GA population.
  # -------------------------------------------------------------
  {
    ga_result <- ga(
      type       = "real-valued",
      lower      = lower_bounds,
      upper      = upper_bounds,
      popSize    = parameters$optimization$population_size,
      maxiter    = parameters$optimization$iteration_number,
      run        = parameters$optimization$run_number,
      pcrossover = parameters$optimization$pcrossover,
      pmutation  = parameters$optimization$pmutation,
      population = ga_population_int,
      crossover  = ga_crossover_int,
      mutation   = ga_mutation_int,
      parallel   = if (parameters$debug_and_config$parallel == 1) cl else FALSE,
      monitor    = FALSE,
      # fitness_funct_optimize_mode is wired in as the GA's fitness
      # function so every candidate chromosome is scored through the
      # same period_calculation()/evaluate_control()/reward_function()
      # pipeline used elsewhere, keeping the reward calculation
      # consistent across optimization paths.
      fitness    = function(x) fitness_funct_optimize_mode(
                                 x                 = as.integer(round(x)),
                                 n_modes           = n_modes,
                                 n_periods         = n_periods,
                                 timestamps        = timestamps,
                                 parameters        = parameters2,
                                 period_chunk      = period_chunk,
                                 simulation_control = simulation_control,
                                 marginal_context  = marginal_context
                               )
    )
  }

  # 5. Stop cluster (if parallel)
  # -------------------------------------------------------------
  # rm(cl) + gc() force the PSOCK connection objects to be released
  # right away; otherwise R's automatic gc cycles may not reach them
  # before the session ends, and they get closed with a warning at exit.
  # -------------------------------------------------------------
  {
    if (parameters$debug_and_config$parallel == 1) {
      stopCluster(cl)
      registerDoSEQ()
      rm(cl)
      gc(verbose = FALSE)
    }
  }

  # 6. Post-process: extract best mode solution and convert to setpoints
  # -------------------------------------------------------------
  # Extract best solution as integer vector, pair with target_periods
  # to build mode data frame, then convert to setpoints.
  # -------------------------------------------------------------
  {
    best_solution <- as.integer(round(ga_result@solution[1, ]))

    # Create mode data frame
    setpoint_modes_df_optimized <- maxmode(
      x              = best_solution,
      n_modes        = n_modes,
      n_periods      = n_periods,
      target_periods = timestamps$target_periods
    )
    rm(ga_result, best_solution)

    # Convert modes to setpoints with deadbands
    setpoint_modes_df_optimized <- convert_modes_to_setpoints(
      setpoint_modes_df = setpoint_modes_df_optimized,
      setpoint_modes    = parameters$setpoint_modes,
      Deadband          = parameters$control$Deadband,
      target_periods    = timestamps$target_periods
    )
  }

  return(setpoint_modes_df_optimized)
}
