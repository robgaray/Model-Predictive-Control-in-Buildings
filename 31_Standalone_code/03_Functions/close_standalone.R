# -------------------------------------------------------------
# Function: close_standalone.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Stops the worker cluster that initialize_standalone() started
# for the R session, when parallel = 1, and returns foreach to
# sequential execution. It is called once, after the last call to
# optimize_market(). Without it the workers end anyway when the R
# session ends.
# -------------------------------------------------------------
# Inputs
#   paths : Named list, as returned by initialize_standalone().
# -------------------------------------------------------------
# Outputs
#   None (invisible NULL). The worker processes are stopped.
# -------------------------------------------------------------
# Code outline
# 1. Stop the worker cluster, if there is one
# -------------------------------------------------------------
# Usage instructions
# paths  <- initialize_standalone(standalone_path, NULL)
# result <- optimize_market(inputs, paths)
# close_standalone(paths)
# -------------------------------------------------------------
close_standalone <- function(paths
                             ) {

  # -------------------------------------------------------------
  # 1. Stop the worker cluster, if there is one
  # -------------------------------------------------------------
  {
    if (!is.null(paths$worker_cluster)) {
      stopCluster(paths$worker_cluster)
      registerDoSEQ()
    }
  }

  return(invisible(NULL))
}
