# -------------------------------------------------------------
# Function: read_file_paths_table.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads and checks the table of file names of a configuration
# folder, 00_Inner_parameters/04_File_paths.csv: the one list of
# file names that the simulation, the GUI and the verification
# battery share. Every file has a scope: "system" for a file common
# to the whole simulation, or the type of model (for example
# "Building") whose every asset holds the file.
# -------------------------------------------------------------
# Inputs
#   config_path : Character. Path of the configuration folder, the
#                 one that holds 00_Inner_parameters/.
# -------------------------------------------------------------
# Outputs
#   Data frame with the character columns key, scope and filename,
#   one row per file, in the order of the file. The run stops if
#   the file lacks one of the columns, if a key, a scope or a file
#   name is empty, or if a key is repeated.
# -------------------------------------------------------------
# Code outline
# 1. Read the table
# 2. Check the table
# -------------------------------------------------------------
# Usage instructions
# file_paths_table <- read_file_paths_table(
#   config_path = file.path("30_Simulation", "02_Config")
# )
# file_paths_table$filename[file_paths_table$key == "reward_file"]
# -------------------------------------------------------------

read_file_paths_table <- function(config_path) {

  # -------------------------------------------------------------
  # 1. Read the table
  # -------------------------------------------------------------
  {
    file_paths_table <- read.csv(
      file.path(config_path, "00_Inner_parameters", "04_File_paths.csv"),
      comment.char     = "#",
      stringsAsFactors = FALSE,
      strip.white      = TRUE
    )
  }

  # -------------------------------------------------------------
  # 2. Check the table
  # -------------------------------------------------------------
  {
    if (!all(c("key", "scope", "filename") %in% names(file_paths_table)) ||
        any(!nzchar(file_paths_table$key)) ||
        any(!nzchar(file_paths_table$scope)) ||
        any(!nzchar(file_paths_table$filename)) ||
        anyDuplicated(file_paths_table$key) > 0) {
      stop("04_File_paths.csv must hold one row per file, with a unique ",
           "key, a scope and a file name")
    }
  }

  return(file_paths_table[, c("key", "scope", "filename")])
}
