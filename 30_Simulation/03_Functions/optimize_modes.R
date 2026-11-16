# -------------------------------------------------------------
# Function: optimize_modes.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function optimizes the control modes over a particular period
# using a Genetic Algorithm (GA) approach with real-type genes that
# are constrained to integer values through custom population,
# crossover, and mutation operators.
# It performs the following steps:
#   1. Lays out the chromosome (chromosome_layout()): one block per
#      asset with genes, one block after the other, each with one
#      gene per market period of the target period, bounded by the
#      number of options of the genes of its asset.
#      It also sizes the elitism against the number of distinct
#      chromosomes the space holds, because ga()'s own default can
#      exceed it and inject an NA row into the population.
#      It also adds to the table of the system the working columns
#      every evaluation writes (piece_working_columns()), and lays
#      out the view of each asset of the piece (piece_layout()),
#      once, so that every evaluation of the genetic algorithm
#      reuses it and adds no column.
#   2. Sends the data of this optimization to the worker cluster
#      of the simulation, when parallel = 1.
#   3. Calls the GA optimizer with custom integer-handling operators
#      to find the optimal control mode sequence that maximizes the
#      reward function.
#   4. Post-processes the optimization results: the best chromosome
#      is decoded into the control of each asset
#      (decode_chromosome()).
# When no asset of the registry has genes (for example a system of
# photovoltaic installations only), the chromosome is empty: there
# is nothing to search, the genetic algorithm is not called, and
# the function returns an empty control list.
# -------------------------------------------------------------
# Inputs
#   piece          : List. The piece of the optimization horizon, as
#                    build_market_piece() gives it: the table of the
#                    system and the table of each asset. The table of
#                    the system holds a 'MarketUTC' column used to
#                    derive the set of target periods. Together the
#                    tables hold the columns required by
#                    period_calculation() (called inside
#                    evaluate_control()). Its working columns are
#                    added and it is laid out (piece_layout()) once,
#                    before the genetic algorithm.
#   timestamps     : Named list. Timestamp metadata. Must contain:
#                      timestamps$target_periods : POSIXct vector of
#                                                  market period timestamps.
#   parameters     : Named list. Model parameters passed through to
#                    period_calculation() and reward_function().
#                    The following sub-elements are extracted internally:
#                      parameters$assets, the asset registry: each
#                        asset with genes takes a block of the
#                        chromosome (for a building, its
#                        setpoint_modes and its control$Deadband)
#                      parameters$optimization, as loaded from
#                        01_Optimization_parameters.csv:
#                          - population_size
#                          - iteration_number
#                          - run_number
#                          - pcrossover
#                          - pmutation
#                          - parallel
#   simulation_control : Named list. Index/step metadata (passed through for
#                    interface consistency).
#   marginal_context : Named list or NULL. Passed through to the fitness
#                    function and, via clusterExport(), to worker processes.
#   worker_cluster : Cluster of worker processes, as returned by
#                    start_worker_cluster(), when parallel = 1;
#                    NULL otherwise. It is used, not stopped.
# -------------------------------------------------------------
# Outputs
#   controls : Named list, one element per asset with genes, named
#              by its asset_id (an empty list when no asset has
#              genes): the control of the asset for the best
#              chromosome, as returned by the operation decode_genes
#              of its type of model (for a Building, the setpoint
#              columns with their hysteresis deadbands, from
#              convert_modes_to_setpoints()).
# -------------------------------------------------------------
# Code outline
# 1. Lay out the chromosome and the views of the piece
# 1a. Leave when the chromosome is empty
# 1b. Size the elitism against the search space
# 2. Configure genetic algorithm parameters with custom operators
# 3. Initialize parallelization
# 4. Run GA optimization with mode fitness function
# 5. Release the cluster reference
# 6. Post-process: decode the best chromosome into the control of
#    each asset
# -------------------------------------------------------------
# Usage instructions
# controls <- optimize_modes(piece, timestamps, parameters,
#                            simulation_control, marginal_context,
#                            worker_cluster)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - With parallel = 1, the GA runs on worker_cluster, created
#     once for the whole simulation by start_worker_cluster(). This
#     function only sends it the data of this optimization, and
#     does not stop it.
#   - ga() always receives a cluster, so that it always
#     evaluates its population through doRNG's %dorng%,
#     which draws one random number of the main process per
#     generation. In series it is an empty object of class
#     "cluster", with the sequential foreach backend
#     registered. The result is then the same in series and
#     in parallel, whatever the number of workers.
#   - Worker processes (PSOCK clusters) do not inherit the global
#     environment: start_worker_cluster() exports every function of
#     the simulator, and this function the data of this
#     optimization by name, via clusterExport(). With parallel = 1
#     the fitness function is given the global environment as its
#     own, so that the workers find both there.
#   - The GA uses real-type encoding with custom integer operators:
#     one block of genes per asset with genes, each gene a whole
#     number from 1 to the number of options of its asset (for a
#     building, a mode index from 1 to its number of modes). The
#     operators read the bounds of each gene separately, so blocks
#     with different bounds need nothing of them.
#   - The custom operators read the selected parent chromosomes from the
#     current GA population to keep the representation valid from the start.
#   - Only the first solution row of the GA result (ga_result@solution[1,])
#     is used if multiple equally-fit solutions exist.
# -------------------------------------------------------------
optimize_modes <- function(piece,
                           timestamps,
                           parameters,
                           simulation_control,
                           marginal_context = NULL,
                           worker_cluster
                           ) {
  
  # 1. Lay out the chromosome and the views of the piece
  # -------------------------------------------------------------
  # One block per asset with genes, one block after the other, in
  # the order of the asset registry. A block holds one integer gene
  # per market period, bounded in [1, number of options of its
  # asset]. What a gene means belongs to the type of model of its
  # asset: the genes of a building are its setpoint modes. With a
  # single building, the chromosome is one gene per market period.
  # The working columns of the system are added to the piece and the
  # view of each asset is laid out once, so that every evaluation of
  # the genetic algorithm reuses the layout and adds no column.
  # -------------------------------------------------------------
  {
    # chromosome_layout is called to give the blocks of the
    # chromosome, which the fitness function and step 6 decode, and
    # the bounds of each gene, which ga() and its operators keep.
    gene_layout <- chromosome_layout(
      parameters  = parameters,
      n_intervals = length(timestamps$target_periods)
    )

    # piece_working_columns is called to add to the table of the
    # system the working columns every evaluation writes, so that no
    # evaluation adds a column and the layout below describes the
    # piece in all of them, here and in the worker processes.
    piece <- piece_working_columns(
      piece = piece
    )

    # piece_layout is called to lay out the view of each asset of the
    # piece once, before the genetic algorithm evaluates its
    # candidates on it, here and in the worker processes, which
    # receive this piece.
    piece <- piece_layout(
      piece        = piece,
      column_order = parameters$joined_cols
    )
  }

  # 1a. Leave when the chromosome is empty
  # -------------------------------------------------------------
  # With no gene there is nothing to search: ga() is not called, no
  # random number is drawn, and the control of every asset is the one
  # its plan already holds.
  # -------------------------------------------------------------
  {
    if (gene_layout$n_genes == 0) {
      return(list())
    }
  }

  # 1b. Size the elitism against the search space
  # -------------------------------------------------------------
  # ga() defaults to elitism = max(1, round(popSize * 0.05)) and its
  # elitism step picks those rows among the UNIQUE ones of the sorted
  # population. When the search space holds fewer distinct chromosomes
  # than that elitism, the index runs past the end of the unique rows
  # and comes back NA, which puts an NA row into the population; the
  # next generation hands that row to the fitness function and the run
  # stops in convert_modes_to_setpoints().
  # The space holds the product of the number of options of every
  # gene, which overflows for any realistic horizon, so it is only
  # computed when its logarithm stays small enough to matter: above
  # the population size the cap cannot bind anyway.
  # -------------------------------------------------------------
  {
    population_size <- parameters$optimization$population_size

    distinct_chromosomes <- if (sum(log(gene_layout$upper)) > log(population_size)) {
      population_size
    } else {
      min(prod(gene_layout$upper), population_size)
    }

    elitism_size <- max(1, min(round(population_size * 0.05),
                               distinct_chromosomes))

    rm(list = "distinct_chromosomes")
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
  # ga() evaluates the population in one of two ways. Given a
  # cluster, it runs a foreach loop with doRNG's %dorng%, which
  # draws one random number of the main process per
  # generation. Given FALSE, it runs a plain loop that draws
  # none. The two ways would follow different random
  # sequences, and the result would depend on parallel. So
  # ga() always receives a cluster:
  # - parallel = 1: worker_cluster, the cluster of worker
  #   processes that simulate() creates once for the whole
  #   simulation, with every function exported and the C++
  #   engine compiled. Only the data of this optimization is
  #   sent to it here: on Windows (PSOCK clusters), worker
  #   processes do not inherit the global environment.
  # - parallel = 0: an empty object of class "cluster", which
  #   ga() only stores, with the sequential foreach backend
  #   registered. The loop then runs in this process, one
  #   candidate after another.
  # doRNG is listed in 00_Libraries.txt, so it is always
  # installed.
  # -------------------------------------------------------------
  {
    if (parameters$debug_and_config$parallel == 1) {
      if (is.null(worker_cluster)) {
        stop("parallel = 1 but no worker cluster was started")
      }
      cl <- worker_cluster

      # The data of this optimization, from this function's environment
      clusterExport(
        cl,
        varlist = c(
          "piece",
          "parameters2",
          "timestamps",
          "gene_layout",
          "simulation_control",
          "marginal_context"
        ),
        envir = environment()
      )
    } else {
      registerDoSEQ()
      cl <- structure(list(), class = "cluster")
    }
  }

  # 4. Run GA optimization with mode fitness function
  # -------------------------------------------------------------
  # ga() is called with type="real-valued" and custom population,
  # crossover, and mutation functions that preserve the integer
  # representation by operating on chromosomes stored in the GA population.
  # With parallel = 1 the fitness function is evaluated in the worker
  # processes. It then takes the global environment as its own, where
  # each worker holds the functions of the simulator and the data of
  # this optimization. Defined here, it would carry the environment of
  # the simulator with it, whose compiled functions do not work in
  # another process. In series it keeps this function's environment.
  # -------------------------------------------------------------
  {
    # fitness_funct_optimize_mode is wired in as the GA's fitness
    # function so every candidate chromosome is scored through the
    # same period_calculation()/evaluate_control()/reward_function()
    # pipeline used elsewhere, keeping the reward calculation
    # consistent across optimization paths.
    fitness_function <- function(x) fitness_funct_optimize_mode(
                                      x                  = as.integer(round(x)),
                                      layout             = gene_layout,
                                      timestamps         = timestamps,
                                      parameters         = parameters2,
                                      piece              = piece,
                                      simulation_control = simulation_control,
                                      marginal_context   = marginal_context
                                    )
    if (parameters$debug_and_config$parallel == 1) {
      environment(fitness_function) <- globalenv()
    }

    ga_result <- ga(
      type       = "real-valued",
      lower      = gene_layout$lower,
      upper      = gene_layout$upper,
      popSize    = parameters$optimization$population_size,
      elitism    = elitism_size,
      maxiter    = parameters$optimization$iteration_number,
      run        = parameters$optimization$run_number,
      pcrossover = parameters$optimization$pcrossover,
      pmutation  = parameters$optimization$pmutation,
      population = ga_population_int,
      crossover  = ga_crossover_int,
      mutation   = ga_mutation_int,
      parallel   = cl,
      monitor    = FALSE,
      fitness    = fitness_function
    )
    rm(list = "fitness_function")
  }

  # 5. Release the cluster reference
  # -------------------------------------------------------------
  # The worker cluster belongs to the simulation and stays open for
  # the next optimization: simulate() stops it when the loop
  # ends. Only the local reference is removed here.
  # -------------------------------------------------------------
  {
    rm(list = "cl")
  }

  # 6. Post-process: decode the best chromosome into the control of
  #    each asset
  # -------------------------------------------------------------
  # Extract best solution as integer vector, then decode each of its
  # blocks with the model of its asset.
  # -------------------------------------------------------------
  {
    best_solution <- as.integer(round(ga_result@solution[1, ]))
    rm(list = "ga_result")

    # decode_chromosome is called to turn each block of the best
    # solution into the control of its asset: for a building, the
    # setpoints of each period with their deadbands.
    controls <- decode_chromosome(
      x              = best_solution,
      layout         = gene_layout,
      target_periods = timestamps$target_periods,
      parameters     = parameters
    )
    rm(list = c("best_solution", "gene_layout", "population_size",
                "elitism_size"))
  }

  return(controls)
}
