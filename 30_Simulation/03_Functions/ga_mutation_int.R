# -------------------------------------------------------------
# Function: ga_mutation_int.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Custom mutation operator for integer mode variables.
# Receives the selected parent chromosome from object@population and,
# for each gene, with probability pmutation, replaces the current
# mode index with a randomly selected valid mode index.
# All output values remain integers within the declared bounds.
# It is one of the three integer operators that optimize_modes()
# hands to ga(): the modes are whole numbers, and these operators
# keep every gene a whole mode number inside its bounds.
# -------------------------------------------------------------
# Inputs
#   object   : GA object (from ga package) containing lower and upper bounds
#   parent   : Integer scalar with the row index of the selected parent
#              in object@population.
# -------------------------------------------------------------
# Outputs
#   Numeric vector representing the mutated chromosome (integer mode indices)
# -------------------------------------------------------------
# Usage instructions
# mutated <- ga_mutation_int(object, parent)
# -------------------------------------------------------------
# Code outline
# 1. Read the bounds and the mutation probability.
# 2. Redraw each gene that the probability selects, uniformly
#    between its bounds.
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
