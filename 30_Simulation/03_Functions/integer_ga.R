# -------------------------------------------------------------
# Function: integer_ga.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function implements a Genetic Algorithm (GA) that operates
# natively on integer-valued chromosomes. Every individual in the
# population is a vector of integers, each gene independently
# bounded in [lower[j], upper[j]]. No continuous relaxation or
# rounding is performed at any stage: initialisation, crossover,
# mutation, and selection all work directly with integers.
#
# The algorithm follows a standard generational GA with elitism:
#   - One elite individual (the current best) is always carried over
#     unchanged to the next generation.
#   - The remaining offspring are produced by tournament selection,
#     single-point crossover (applied with probability pcrossover),
#     and single-gene mutation (applied with probability pmutation).
#   - Convergence is declared when the best fitness has not improved
#     for 'run' consecutive generations.
# -------------------------------------------------------------
# Inputs
#   fitness      : Function. fitness(x) -> numeric scalar. The
#                  objective to maximise. x is an integer vector of
#                  length n_genes.
#   n_genes      : Integer scalar. Chromosome length (number of genes).
#   lower        : Integer vector of length n_genes. Minimum allowed
#                  value for each gene.
#   upper        : Integer vector of length n_genes. Maximum allowed
#                  value for each gene.
#   pop_size     : Integer scalar. Number of individuals in the
#                  population.
#   max_iter     : Integer scalar. Maximum number of generations.
#   run          : Integer scalar. Early-stopping threshold: the
#                  algorithm halts when the best fitness has not
#                  improved for this many consecutive generations.
#   pcrossover   : Numeric scalar in [0, 1]. Probability that two
#                  selected parents undergo single-point crossover.
#                  If no crossover occurs, the first parent is copied.
#   pmutation    : Numeric scalar in [0, 1]. Probability that an
#                  offspring undergoes single-gene mutation (one
#                  randomly selected gene is replaced by a new random
#                  integer drawn from its allowed range).
#   parallel_cl  : Cluster object or NULL. If a parallel cluster is
#                  supplied, fitness evaluations are distributed across
#                  workers using parApply(). If NULL (default),
#                  fitness is evaluated sequentially with apply().
#
# Outputs
#   best_solution : Integer vector of length n_genes. The chromosome
#                   with the highest fitness found during the run.
# -------------------------------------------------------------
# Code outline
# 1. Initialise integer population
# 2. Evaluate initial population fitness
# 3. Generational loop
#    3.1 Select elite individual
#    3.2 Build new population via selection, crossover, mutation
#    3.3 Evaluate new population fitness
#    3.4 Check convergence
# 4. Return best solution
# -------------------------------------------------------------
# Usage instructions
# best <- integer_ga(fitness    = my_fitness,
#                    n_genes    = 24L,
#                    lower      = rep(1L, 24),
#                    upper      = rep(7L, 24),
#                    pop_size   = 50L,
#                    max_iter   = 100L,
#                    run        = 20L,
#                    pcrossover = 0.8,
#                    pmutation  = 0.1)
# -------------------------------------------------------------
# Where this function/script is used
# Called by optimize_modes.R as the core optimisation engine for
# mode-based MPC control.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If lower[j] == upper[j] for some gene j, that gene is fixed
#     at lower[j] in every individual; crossover and mutation leave
#     it unchanged (sample of a length-1 vector always returns that
#     value).
#   - If pop_size == 1, no crossover or tournament selection is
#     possible; the single individual is mutated each generation.
#   - When parallel_cl is supplied, all objects needed by fitness()
#     must already be exported to the cluster workers by the caller
#     (e.g., via clusterExport()) before integer_ga() is invoked.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
integer_ga <- function(fitness,
                       n_genes,
                       lower,
                       upper,
                       pop_size,
                       max_iter,
                       run,
                       pcrossover,
                       pmutation,
                       parallel_cl = NULL
                       ) {

  # 1. Initialise integer population
  # ---------------------------------------------------
  # Each gene is drawn independently and uniformly from its integer
  # range [lower[j], upper[j]]. The population is stored as a
  # pop_size x n_genes integer matrix (one individual per row).
  # ---------------------------------------------------
  {
    pop <- matrix(
      data = as.integer(
               mapply(function(lo, hi) sample(lo:hi, pop_size, replace = TRUE),
                      lower,
                      upper
                      )
               ),
      nrow = pop_size,
      ncol = n_genes
    )
  }

  # 2. Evaluate initial population fitness
  # ---------------------------------------------------
  # Parallel evaluation is used when a cluster is supplied; otherwise
  # sequential apply() is used.
  # ---------------------------------------------------
  {
    if (!is.null(parallel_cl)) {
      fitness_vec <- parApply(parallel_cl, pop, 1, fitness)
    } else {
      fitness_vec <- apply(pop, 1, fitness)
    }

    best_fitness         <- max(fitness_vec)
    no_improvement_count <- 0L
  }

  # 3. Generational loop
  # ---------------------------------------------------
  # Sections:
  #   3.1 Select elite individual
  #   3.2 Build new population via selection, crossover, mutation
  #   3.3 Evaluate new population fitness
  #   3.4 Check convergence
  # ---------------------------------------------------
  for (CONT_001 in seq_len(max_iter)) {

    # ---------------------------------------------------
    # 3.1 Select elite individual
    # ---------------------------------------------------
    {
      elite_idx  <- which.max(fitness_vec)
      new_pop    <- matrix(0L, nrow = pop_size, ncol = n_genes)
      new_pop[1, ] <- pop[elite_idx, ]
    }

    # ---------------------------------------------------
    # 3.2 Build new population via selection, crossover, mutation
    # ---------------------------------------------------
    {
      CONT_002 <- 2L
      while (CONT_002 <= pop_size) {

        # Tournament selection for parent 1: pick the better of two random individuals
        cand1 <- sample(pop_size, 2L)
        p1    <- pop[cand1[if (fitness_vec[cand1[1]] >= fitness_vec[cand1[2]]) 1L else 2L], ]

        # Crossover with probability pcrossover
        if (runif(1) < pcrossover && pop_size > 1L) {
          cand2 <- sample(pop_size, 2L)
          p2    <- pop[cand2[if (fitness_vec[cand2[1]] >= fitness_vec[cand2[2]]) 1L else 2L], ]

          cut_point <- sample(n_genes - 1L, 1L)
          child     <- c(p1[seq_len(cut_point)],
                         p2[seq(cut_point + 1L, n_genes)]
                         )
        } else {
          child <- p1
        }

        # Single-gene mutation with probability pmutation
        if (runif(1) < pmutation) {
          mut_gene        <- sample(n_genes, 1L)
          child[mut_gene] <- sample(lower[mut_gene]:upper[mut_gene], 1L)
        }

        new_pop[CONT_002, ] <- as.integer(child)
        CONT_002             <- CONT_002 + 1L
      }
      rm(CONT_002, cand1, p1, child)
    }

    # ---------------------------------------------------
    # 3.3 Evaluate new population fitness
    # ---------------------------------------------------
    {
      pop <- new_pop
      rm(new_pop)

      if (!is.null(parallel_cl)) {
        fitness_vec <- parApply(parallel_cl, pop, 1, fitness)
      } else {
        fitness_vec <- apply(pop, 1, fitness)
      }
    }

    # ---------------------------------------------------
    # 3.4 Check convergence
    # ---------------------------------------------------
    {
      current_best <- max(fitness_vec)

      if (current_best > best_fitness) {
        best_fitness         <- current_best
        no_improvement_count <- 0L
      } else {
        no_improvement_count <- no_improvement_count + 1L
      }

      if (no_improvement_count >= run) {
        break
      }

      rm(current_best)
    }
  }

  rm(CONT_001, no_improvement_count, best_fitness)

  # 4. Return best solution
  # ---------------------------------------------------
  # fitness_vec from the last evaluated generation is still available;
  # use it directly to identify the best individual without any
  # additional fitness evaluation.
  # ---------------------------------------------------
  {
    best_solution <- as.integer(pop[which.max(fitness_vec), ])
    rm(fitness_vec)
  }

  return(best_solution)
}
