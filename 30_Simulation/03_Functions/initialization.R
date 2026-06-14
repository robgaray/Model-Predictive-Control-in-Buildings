# -------------------------------------------------------------
# Function: initialization.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function performs the initialization steps required before
# running the MPC simulation. It carries out two tasks:
#   1. Loads all required R packages listed in a plain-text library
#      file (one package name per line, comment lines starting with
#      '#' are ignored).
#   2. Sources all R function files found in the specified functions
#      directory, making them available in the calling environment.
# -------------------------------------------------------------
# Inputs
#   library_file    : Character. Path to a plain-text file listing the
#                     names of required R packages, one per line.
#                     Lines beginning with '#' and empty lines are ignored.
#   functions_path  : Character. Path to the directory containing the R
#                     function files (.R) to be sourced.
#   lib_path        : Character or NULL. Optional path to a custom R library
#                     location passed to library() as 'lib.loc'. If NULL
#                     (default), the default library paths are used.
#
# Outputs
#   None (called for side effects). Prints "libraries loaded" and
#   "functions loaded" to the console upon completion.
# -------------------------------------------------------------
# Code outline
# 1. Load required libraries from file
# 2. Source all function files from the functions directory
# -------------------------------------------------------------
# Usage instructions
# initialization(library_file, functions_path)
# initialization(library_file, functions_path, lib_path = "/path/to/libs")
# -------------------------------------------------------------
# Where this function/script is used
# Called by 30_Simulation/04_Scripts/initialization.R and
# 31_SCC_Simulation/initialization_SCC.R
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If a package listed in library_file is not installed, library()
#     will raise an error. No automatic installation is attempted.
#   - If lib_path is NULL, packages are loaded from the default R
#     library paths.
#   - All .R files in functions_path are sourced unconditionally and
#     in the order returned by list.files(); file ordering may matter
#     if functions depend on each other.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

initialization <- function(library_file,
                           functions_path,
                           lib_path = NULL) {
  # Loading libraries
  {
    raw_lines <- readLines(library_file)
    raw_lines <- raw_lines[!grepl("^#", raw_lines)]  # remove comments
    raw_lines <- raw_lines[nchar(raw_lines) > 0]     # remove empty lines
    
    required_libraries <- raw_lines
    rm(raw_lines)
    
    for (CONT_001 in required_libraries) {
      if (is.null(lib_path)) {
        library(CONT_001, character.only = TRUE)
      } else {
        library(CONT_001, lib.loc = lib_path, character.only = TRUE)
      }
      rm(CONT_001)
    }
    rm(required_libraries)
  }
  
  cat("libraries loaded\n")
  
  # Load functions
  {
    files.source <- list.files(functions_path)
    for (CONT_002 in seq_along(files.source)) {
      source(file.path(functions_path, files.source[CONT_002]))
    }
    rm(files.source, CONT_002)
  }
  
  cat("functions loaded\n")
}
