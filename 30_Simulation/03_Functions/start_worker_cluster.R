# -------------------------------------------------------------
# Function: start_worker_cluster.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Creates the cluster of worker processes in which the genetic
# algorithm evaluates its candidates when parallel = 1, and
# prepares it for the whole simulation:
#   - it registers the cluster as the foreach backend;
#   - it gives every worker a reproducible random number stream
#     derived from the run's seed;
#   - it exports every function of the simulator, the environment
#     this function was loaded into;
#   - it compiles the C++ modules on every worker.
# These steps are the expensive part of using workers: compiling
# the C++ engine alone takes several seconds per worker. They are
# done once per simulation, and every optimization then only
# sends the data of its own market (see optimize_modes()).
# -------------------------------------------------------------
# What a worker holds
# A worker is a process of its own, dedicated to the genetic
# algorithm. It holds the functions of the simulator in its global
# environment, where they call each other, and its own compiled C++
# engine there.
# -------------------------------------------------------------
# Inputs
#   parallel_workers : Numeric. Number of worker processes. With 0,
#                      all logical cores but one are used.
#   random_seed      : Numeric. Seed of the run. The worker streams
#                      are only seeded when it is non-zero, following
#                      Main.R's "0 means do not fix" convention.
#   cpp_source_path  : Character vector. The C++ modules of the types
#                      of model, one .cpp file each, compiled on every
#                      worker.
# -------------------------------------------------------------
# Outputs
#   The cluster object returned by makeCluster(), registered as the
#   foreach backend. The caller stops it with stopCluster() when the
#   simulation ends.
# -------------------------------------------------------------
# Code outline
# 1. Create the cluster and register it as the foreach backend
# 2. Seed the random number stream of every worker
# 3. Export every function of the simulator
# 4. Compile the C++ modules on every worker
# -------------------------------------------------------------
# Usage instructions
# worker_cluster <- start_worker_cluster(
#   parallel_workers = parameters$debug_and_config$parallel_workers,
#   random_seed      = parameters$debug_and_config$random_seed,
#   cpp_source_path  = paths$cpp_source_path
# )
# -------------------------------------------------------------
start_worker_cluster <- function(parallel_workers,
                                 random_seed,
                                 cpp_source_path
                                 ) {

  # -------------------------------------------------------------
  # 1. Create the cluster and register it as the foreach backend
  # The number of workers is parallel_workers, or all logical cores
  # but one when it is 0. The result does not depend on it.
  # -------------------------------------------------------------
  {
    n_cores <- parallel_workers
    if (is.null(n_cores) || n_cores == 0) {
      n_cores <- max(1, parallel::detectCores(logical = TRUE) - 1)
    }
    worker_cluster <- makeCluster(n_cores)
    registerDoParallel(worker_cluster)
    rm(list = "n_cores")
  }

  # -------------------------------------------------------------
  # 2. Seed the random number stream of every worker
  # set.seed() in Main.R only affects the main process. The seed is
  # only applied when it is non-zero.
  # -------------------------------------------------------------
  {
    if (!is.null(random_seed) && random_seed != 0) {
      parallel::clusterSetRNGStream(worker_cluster, iseed = random_seed)
    }
  }

  # -------------------------------------------------------------
  # 3. Export every function of the simulator
  # A worker process starts with none of the functions of the
  # simulation. All of them are exported, rather than a list kept
  # by hand: a hand-kept list silently misses the next function
  # added, and the run then stops inside a worker. They are taken
  # from the environment this function was loaded into, which holds
  # every function of the simulator.
  # Each one is sent with the global environment as its own, and is
  # defined in the global environment of the worker. A function sent
  # with the environment of the simulator would carry that whole
  # environment with it, and the compiled functions it holds do not
  # work in another process. The C++ entry points travel too, but
  # block 4 replaces them.
  # -------------------------------------------------------------
  {
    simulator_env     <- environment(start_worker_cluster)
    project_functions <- Filter(
      function(name) is.function(get(name, envir = simulator_env)),
      ls(simulator_env)
    )

    worker_functions <- new.env(parent = emptyenv())
    for (CONT_001 in project_functions) {
      worker_function <- get(CONT_001, envir = simulator_env)
      environment(worker_function) <- globalenv()
      assign(CONT_001, worker_function, envir = worker_functions)
    }

    clusterExport(
      worker_cluster,
      varlist = project_functions,
      envir   = worker_functions
    )
    rm(list = c("simulator_env", "project_functions", "worker_functions",
                "worker_function", "CONT_001"))
  }

  # -------------------------------------------------------------
  # 4. Compile the C++ modules on every worker
  # A compiled function cannot be exported to another process, so
  # every worker compiles each module itself, into its global
  # environment, the default of Rcpp::sourceCpp(). The function of
  # Rcpp is sent as it is: a function defined here would carry the
  # environment of the simulator with it, as block 3 explains.
  # -------------------------------------------------------------
  {
    for (CONT_002 in seq_along(cpp_source_path)) {
      # clusterCall is called to run Rcpp::sourceCpp on every worker
      # for one C++ module.
      clusterCall(
        worker_cluster,
        Rcpp::sourceCpp,
        cpp_source_path[CONT_002]
      )
    }
    rm(list = "CONT_002")
  }

  return(worker_cluster)
}
