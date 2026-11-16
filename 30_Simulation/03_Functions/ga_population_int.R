# -------------------------------------------------------------
# Function: ga_population_int.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Custom population generator for the genetic algorithm that creates
# initial population with integer values representing mode indices.
# Each gene is a valid mode index in the range [1, n_modes].
# It is one of the three integer operators that optimize_modes()
# hands to ga(): the modes are whole numbers, and these operators
# keep every gene a whole mode number inside its bounds.
# -------------------------------------------------------------
# Inputs
#   object : GA object (from ga package) containing lower and upper bounds
# -------------------------------------------------------------
# Outputs
#   matrix : Population matrix where each row is an individual (chromosome)
#            and each column is a gene (mode index for one market period).
#            All values are integers in the range defined by lower/upper bounds.
# -------------------------------------------------------------
# Usage instructions
# population <- ga_population_int(object)
# -------------------------------------------------------------
# Code outline
# 1. Read the integer bounds and the population size from the GA
#    object.
# 2. Draw one whole mode number per gene and per individual,
#    uniformly between those bounds.
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
