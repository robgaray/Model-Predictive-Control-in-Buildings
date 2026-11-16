# -------------------------------------------------------------
# Function: start_worker_cluster.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Creates the cluster of worker processes in which the genetic
# algorithm evaluates its candidates when parallel = 1, and
# prepares it for every market of the R session:
#   - it registers the cluster as the foreach backend;
#   - it exports every function of the global environment;
#   - it compiles the C++ modules of the types of model on every
#     worker.
# These steps are the expensive part of using workers: compiling
# the C++ modules alone takes several seconds per worker. They are
# done once per session, by initialize_standalone(), and every
# call to optimize_market() then only sends the data of its own
# market (see optimize_modes()).
# The random streams of the workers are not set here: each market
# brings its own seed, and optimize_modes() sets them per market.
# -------------------------------------------------------------
# Inputs
#   parallel_workers : Numeric. Number of worker processes. With 0,
#                      all logical cores but one are used.
#   cpp_source_path  : Character vector. The C++ modules of the types
#                      of model, one .cpp file each, compiled on every
#                      worker.
# -------------------------------------------------------------
# Outputs
#   The cluster object returned by makeCluster(), registered as the
#   foreach backend. close_standalone() stops it.
# -------------------------------------------------------------
# Code outline
# 1. Create the cluster and register it as the foreach backend
# 2. Export every function of the global environment
# 3. Compile the C++ modules on every worker
# -------------------------------------------------------------
# Usage instructions
# worker_cluster <- start_worker_cluster(
#   parallel_workers = parameters$debug_and_config$parallel_workers,
#   cpp_source_path  = paths$cpp_source_path
# )
# -------------------------------------------------------------
start_worker_cluster <- function(parallel_workers,
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
  # 2. Export every function of the global environment
  # A worker process starts with none of the functions of the
  # script. All of them are exported, rather than a list kept by
  # hand: a hand-kept list silently misses the next function
  # added, and the call then stops inside a worker. The C++ entry
  # points travel too, but block 3 replaces them.
  # -------------------------------------------------------------
  {
    project_functions <- Filter(
      function(name) is.function(get(name, envir = globalenv())),
      ls(globalenv())
    )
    clusterExport(
      worker_cluster,
      varlist = project_functions,
      envir   = globalenv()
    )
    rm(list = "project_functions")
  }

  # -------------------------------------------------------------
  # 3. Compile the C++ modules on every worker
  # A compiled function cannot be exported to another process, so
  # every worker compiles each module itself.
  # -------------------------------------------------------------
  {
    for (CONT_001 in cpp_source_path) {
      # clusterCall is called to run Rcpp::sourceCpp on every worker
      # for one C++ module.
      clusterCall(
        worker_cluster,
        function(path) Rcpp::sourceCpp(path),
        CONT_001
      )
    }
    rm(list = "CONT_001")
  }

  return(worker_cluster)
}
