# -------------------------------------------------------------
# Function: initialize_standalone.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Prepares an R session to run the standalone market script. It
# builds the list of paths of the script folder, loads the libraries
# the script needs, sources every function of 03_Functions into the
# global environment and compiles the C++ simulation module.
# Everything is read relative to the script folder, so the folder
# works the same wherever it is copied.
# The path of the C++ source is also left in the global environment
# as cpp_source_path, because optimize_modes() compiles the module
# again on each parallel worker from that object.
# -------------------------------------------------------------
# Inputs
#   standalone_path : Character. Path of the 31_Standalone_code folder.
#   config_path     : Character or NULL. Configuration folder to use
#                     instead of standalone_path/02_Config.
# -------------------------------------------------------------
# Outputs
#   Named list of paths, invisibly:
#     - standalone_path
#     - config_path
#     - functions_path
#     - cpp_source_path
#     - library_file
# -------------------------------------------------------------
# Code outline
# 1. Build and check the paths
# 2. Load the libraries
# 3. Source the functions
# 4. Compile the C++ module
# -------------------------------------------------------------
# Usage instructions
# source(file.path(standalone_path, "03_Functions",
#                  "initialize_standalone.R"))
# paths <- initialize_standalone(standalone_path, NULL)
# -------------------------------------------------------------
# Where this function/script is used
#   - call_script_console.R: before reading the input file.
#   - call_script_from_R.R and call_script_from_Python_rpy2.py:
#     before calling optimize_market() directly.
# -------------------------------------------------------------
# functions/scripts called
#   - source(): loads every function file of 03_Functions
#   - Rcpp::sourceCpp(): compiles period_simulation_cpp.cpp
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
      cpp_source_path = file.path(standalone_path, "03_1_Functions_Cpp",
                                  "period_simulation_cpp.cpp"),
      library_file    = file.path(config_path, "00_Inner_parameters",
                                  "00_Libraries.txt")
    )

    missing_files <- unlist(paths)[!file.exists(unlist(paths))]
    if (length(missing_files) > 0) {
      stop("Missing required files or folders:\n",
           paste(missing_files, collapse = "\n"))
    }
    rm(missing_files)
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
    rm(library_lines, missing_libraries, CONT_001)
  }

  # -------------------------------------------------------------
  # 3. Source the functions
  # -------------------------------------------------------------
  {
    function_files <- list.files(paths$functions_path,
                                 pattern    = "\\.R$",
                                 full.names = TRUE)
    for (CONT_002 in function_files) {
      # source() is called to define each function of the script in
      # the global environment, where the parallel workers of the
      # optimizer look for them.
      source(CONT_002, local = globalenv())
    }
    rm(function_files, CONT_002)
  }

  # -------------------------------------------------------------
  # 4. Compile the C++ module
  # -------------------------------------------------------------
  {
    assign("cpp_source_path", paths$cpp_source_path, envir = globalenv())

    # Rcpp::sourceCpp() is called to compile the time step loop of the
    # building physics, which period_calculation() calls.
    Rcpp::sourceCpp(paths$cpp_source_path, env = globalenv())
  }

  return(invisible(paths))
}
