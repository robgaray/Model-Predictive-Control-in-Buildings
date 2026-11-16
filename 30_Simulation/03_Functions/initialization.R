# -------------------------------------------------------------
# Function: initialization.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function performs the initialization steps required before
# running the MPC simulation. It carries out two tasks:
#   1. Sources all R function files found in the specified function
#      directories into the environment given by envir, making them
#      available there.
#   2. Loads all required R packages listed in a plain-text library
#      file (one package name per line, comment lines starting with
#      '#' are ignored). The startup messages of the packages are
#      suppressed.
# The functions are sourced first, so that a package that has to be
# installed is reported with console_message().
# -------------------------------------------------------------
# Inputs
#   library_file    : Character. Path to a plain-text file listing the
#                     names of required R packages, one per line.
#                     Lines beginning with '#' and empty lines are ignored.
#   function_paths  : Character vector. Paths of the directories that
#                     hold the R function files (.R) to be sourced:
#                     the functions of the system and those of every
#                     type of model.
#   envir           : Environment. The environment the function files
#                     are sourced into: their functions are defined
#                     there, and call each other there.
#   lib_path        : Character or NULL. Optional path to a custom R library
#                     location passed to library() as 'lib.loc'. If NULL
#                     (default), the default library paths are used.
# -------------------------------------------------------------
# Outputs
#   None (called for side effects). Writes one LOAD line to the
#   console on completion, with the packages and the number of
#   function files loaded. When a package has to be installed, a
#   LOAD line says so first.
# -------------------------------------------------------------
# Code outline
# 1. Source all function files from the function directories
# 2. Load required libraries from file
# 3. Report
# -------------------------------------------------------------
# Usage instructions
# initialization(library_file, function_paths, envir = sim)
# initialization(library_file, function_paths, envir = sim,
#                lib_path = "/path/to/libs")
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If a package listed in library_file is not installed, it is
#     installed from CRAN before it is loaded.
#   - If lib_path is NULL, packages are loaded from the default R
#     library paths.
#   - All .R files in function_paths are sourced unconditionally,
#     folder by folder in the order given and, inside each folder, in
#     the order returned by list.files(); file ordering may matter if
#     functions depend on each other.
# -------------------------------------------------------------

initialization <- function(library_file,
                           function_paths,
                           envir,
                           lib_path = NULL) {

  # -------------------------------------------------------------
  # 1. Source all function files from the function directories
  # -------------------------------------------------------------
  {
    function_count <- 0

    for (CONT_001 in seq_along(function_paths)) {
      files.source <- list.files(
        function_paths[CONT_001],
        full.names = TRUE
      )
      for (CONT_002 in seq_along(files.source)) {
        # source() is called to load each function file of the folder
        # into envir, making its function(s) available to the rest of
        # the simulation.
        source(files.source[CONT_002], local = envir)
      }
      function_count <- function_count + length(files.source)
      rm(list = c("files.source", "CONT_002"))
    }
    rm(list = "CONT_001")
  }

  # -------------------------------------------------------------
  # 2. Load required libraries from file
  # The packages are loaded in the order of the file, and their
  # startup messages are suppressed. A package that is not installed
  # is installed first.
  # -------------------------------------------------------------
  {
    raw_lines <- readLines(library_file)
    raw_lines <- raw_lines[!grepl("^#", raw_lines)]
    raw_lines <- raw_lines[nchar(raw_lines) > 0]

    required_libraries <- raw_lines
    rm(list = "raw_lines")

    for (CONT_003 in required_libraries) {
      is_installed <- FALSE

      # Check if package is installed
      {
        if (is.null(lib_path)) {
          is_installed <- requireNamespace(
            CONT_003,
            quietly = TRUE
          )
        } else {
          is_installed <- requireNamespace(
            CONT_003,
            lib.loc = lib_path,
            quietly = TRUE
          )
        }
      }

      # Install package if missing
      {
        if (!is_installed) {
          # console_message is called to tell that the package is
          # missing and is going to be installed. It is the one
          # defined in envir by step 1.
          console_message <- envir$console_message
          console_message(
            label = "LOAD",
            text  = paste0("Package ", CONT_003,
                           " not found. Installing...")
          )
          if (is.null(lib_path)) {
            install.packages(
              CONT_003,
              dependencies = TRUE,
              repos        = "https://cloud.r-project.org"
            )
          } else {
            install.packages(
              CONT_003,
              lib          = lib_path,
              dependencies = TRUE,
              repos        = "https://cloud.r-project.org"
            )
          }
        }
      }

      # Load package
      {
        if (is.null(lib_path)) {
          suppressPackageStartupMessages(
            library(
              CONT_003,
              character.only = TRUE
            )
          )
        } else {
          suppressPackageStartupMessages(
            library(
              CONT_003,
              lib.loc        = lib_path,
              character.only = TRUE
            )
          )
        }
      }

      rm(list = c("CONT_003", "is_installed"))
    }
  }

  # -------------------------------------------------------------
  # 3. Report
  # -------------------------------------------------------------
  {
    # console_message, the one defined in envir by step 1, is called
    # to write the only line of the function: the packages loaded and
    # the function files sourced.
    console_message <- envir$console_message
    console_message(
      label = "LOAD",
      text  = paste0("Libraries: ", paste(required_libraries,
                                          collapse = ", "),
                     ". Functions: ", function_count, " files")
    )
    rm(list = c("required_libraries", "function_count", "console_message"))
  }
}
