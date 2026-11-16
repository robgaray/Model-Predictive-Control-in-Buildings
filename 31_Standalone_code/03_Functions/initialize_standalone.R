# -------------------------------------------------------------
# Function: initialize_standalone.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Prepares an R session to run the standalone market script. It
# builds the list of paths of the script folder, loads the libraries
# the script needs, sources every function of 03_Functions and of the
# 03_Functions folder of each type of model under 05_Models into the
# global environment, and compiles the C++ module of each type of
# model that has one, from the 03_1_Functions_Cpp folder of the
# type: the building and the battery.
# Everything is read relative to the script folder, so the folder
# works the same wherever it is copied.
# When 03_Run_config.csv asks for parallel = 1, it also creates the
# worker cluster of the genetic algorithm, once for the whole R
# session: start_worker_cluster() exports every function and
# compiles the C++ modules on every worker. Every later call to
# optimize_market() reuses it, and close_standalone() stops it.
# -------------------------------------------------------------
# Inputs
#   standalone_path : Character. Path of the 31_Standalone_code folder.
#   config_path     : Character or NULL. Configuration folder to use
#                     instead of standalone_path/02_Config.
# -------------------------------------------------------------
# Outputs
#   Named list, invisibly:
#     - standalone_path
#     - config_path
#     - functions_path
#     - models_path
#     - cpp_source_path: character vector, the C++ modules of the
#       types of model, one .cpp file each
#     - library_file
#     - worker_cluster: the cluster of worker processes, or NULL
#       when parallel = 0
# -------------------------------------------------------------
# Code outline
# 1. Build and check the paths
# 2. Load the libraries
# 3. Source the functions
# 4. Compile the C++ modules
# 5. Start the worker cluster, when parallel = 1
# -------------------------------------------------------------
# Usage instructions
# source(file.path(standalone_path, "03_Functions",
#                  "initialize_standalone.R"))
# paths <- initialize_standalone(standalone_path, NULL)
# result <- optimize_market(inputs, paths)
# close_standalone(paths)
# -------------------------------------------------------------

initialize_standalone <- function(standalone_path,
                                  config_path
                                  ) {

  # -------------------------------------------------------------
  # 1. Build and check the paths
  # -------------------------------------------------------------
  {
    standalone_path <- normalizePath(standalone_path, mustWork = TRUE)

    if (is.null(config_path)) {
      config_path <- file.path(standalone_path, "02_Config")
    }

    paths <- list(
      standalone_path = standalone_path,
      config_path     = normalizePath(config_path, mustWork = TRUE),
      functions_path  = file.path(standalone_path, "03_Functions"),
      models_path     = file.path(standalone_path, "05_Models"),
      cpp_source_path = list.files(
        Sys.glob(file.path(standalone_path, "05_Models", "*",
                           "03_1_Functions_Cpp")),
        pattern    = "\\.cpp$",
        full.names = TRUE
      ),
      library_file    = file.path(config_path, "00_Inner_parameters",
                                  "00_Libraries.txt")
    )

    if (length(paths$cpp_source_path) == 0) {
      stop("No C++ module found in the types of model of ",
           paths$models_path)
    }

    missing_files <- unlist(paths)[!file.exists(unlist(paths))]
    if (length(missing_files) > 0) {
      stop("Missing required files or folders:\n",
           paste(missing_files, collapse = "\n"))
    }
    rm(list = "missing_files")
  }

  # -------------------------------------------------------------
  # 2. Load the libraries
  # -------------------------------------------------------------
  # A missing library is reported, not installed: setup.R installs
  # them, once, before the first call.
  # -------------------------------------------------------------
  {
    library_lines <- readLines(paths$library_file)
    library_lines <- trimws(library_lines[!grepl("^#", library_lines)])
    library_lines <- library_lines[nchar(library_lines) > 0]

    missing_libraries <- library_lines[
      !vapply(library_lines, requireNamespace, logical(1), quietly = TRUE)
    ]
    if (length(missing_libraries) > 0) {
      stop("Missing R packages: ", paste(missing_libraries, collapse = ", "),
           ". Run setup.R once to install them.")
    }

    for (CONT_001 in library_lines) {
      suppressPackageStartupMessages(
        library(CONT_001, character.only = TRUE)
      )
    }
    rm(list = c("library_lines", "missing_libraries", "CONT_001"))
  }

  # -------------------------------------------------------------
  # 3. Source the functions
  # -------------------------------------------------------------
  {
    function_files <- c(
      list.files(paths$functions_path,
                 pattern    = "\\.R$",
                 full.names = TRUE),
      unlist(lapply(
        Sys.glob(file.path(paths$models_path, "*", "03_Functions")),
        list.files,
        pattern    = "\\.R$",
        full.names = TRUE
      ))
    )
    for (CONT_002 in function_files) {
      # source() is called to define each function of the script in
      # the global environment, where the parallel workers of the
      # optimizer look for them.
      source(CONT_002, local = globalenv())
    }
    rm(list = c("function_files", "CONT_002"))
  }

  # -------------------------------------------------------------
  # 4. Compile the C++ modules
  # -------------------------------------------------------------
  {
    assign("cpp_source_path", paths$cpp_source_path, envir = globalenv())

    for (CONT_003 in paths$cpp_source_path) {
      # Rcpp::sourceCpp() is called to compile one C++ module into the
      # global environment. For the building, period_simulation_cpp.cpp
      # gives the time step loop of its physics, which
      # period_calculation() calls, and the electrical model of the
      # heat pump that the R functions share with it. For the battery,
      # battery_trajectory_cpp.cpp gives its trajectories, the
      # correction of its Recovery Phase and the search of its factor.
      Rcpp::sourceCpp(CONT_003, env = globalenv())
    }
    rm(list = "CONT_003")
  }

  # -------------------------------------------------------------
  # 5. Start the worker cluster, when parallel = 1
  # -------------------------------------------------------------
  # It comes after the functions and the C++ modules, because the
  # workers receive every function of the global environment.
  # -------------------------------------------------------------
  {
    # load_parameters is called to read and validate the
    # configuration, which says whether the optimizer runs in
    # parallel and with how many workers.
    run_parameters <- load_parameters(paths$config_path)$debug_and_config

    paths["worker_cluster"] <- list(NULL)
    if (run_parameters$parallel == 1) {
      # start_worker_cluster is called to create the worker processes
      # and prepare them once for every market of the session.
      paths$worker_cluster <- start_worker_cluster(
        parallel_workers = run_parameters$parallel_workers,
        cpp_source_path  = paths$cpp_source_path
      )
    }
    rm(list = "run_parameters")
  }

  return(invisible(paths))
}
