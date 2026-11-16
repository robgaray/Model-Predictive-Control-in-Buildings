# -------------------------------------------------------------
# Function: ga_crossover_int.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Custom crossover operator for integer mode variables.
# Performs uniform crossover using the actual parent chromosomes
# selected by GA from object@population.
# All output values remain integers within the same discrete domain
# already present in the parent chromosomes.
# It is one of the three integer operators that optimize_modes()
# hands to ga(): the modes are whole numbers, and these operators
# keep every gene a whole mode number inside its bounds.
# -------------------------------------------------------------
# Inputs
#   object   : GA object (from ga package)
#   parents  : Integer vector with the row indexes of the selected parents
#              in object@population.
# -------------------------------------------------------------
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
# Code outline
# 1. Take the two parents out of the population.
# 2. Uniform crossover: for each gene, one child takes it from one
#    parent and the other child from the other, with equal
#    probability, so every gene stays a whole mode number.
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
