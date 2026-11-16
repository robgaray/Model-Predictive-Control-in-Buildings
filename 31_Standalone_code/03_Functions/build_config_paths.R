# -------------------------------------------------------------
# Function: build_config_paths.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the path of every system configuration file of a
# configuration folder. The file names are read from
# 00_Inner_parameters/05_File_paths.csv, the one list of file names
# of the configuration of the script, so that no other code writes
# the name of a configuration file. Only
# the files of scope "system" get a path here: the files that every
# asset of a type of model holds are named per asset.
# -------------------------------------------------------------
# Inputs
#   config_path : Character. Path of the configuration folder, the
#                 one that holds 00_Inner_parameters/ and the
#                 configuration files.
# -------------------------------------------------------------
# Outputs
#   Named list of character values:
#   - one path per system key of 05_File_paths.csv, built as the
#     configuration folder plus the file name of the key;
#   - config_path: the configuration folder itself.
#   The files are not checked for existence. The run stops if the
#   table lacks a key, a scope or a file name, or if a key is
#   repeated.
# -------------------------------------------------------------
# Code outline
# 1. Read and check the table of file names
# 2. Build one path per system key
# -------------------------------------------------------------
# Usage instructions
# config_paths <- build_config_paths(
#   config_path = file.path("31_Standalone_code", "02_Config")
# )
# config_paths$reward_file
# -------------------------------------------------------------

build_config_paths <- function(config_path) {

  # -------------------------------------------------------------
  # 1. Read and check the table of file names
  # -------------------------------------------------------------
  {
    # read_file_paths_table is called to read the table of file names
    # and check that it holds one row per file, with a unique key.
    file_paths_table <- read_file_paths_table(config_path = config_path)
    file_paths_table <- file_paths_table[file_paths_table$scope == "system", ]
  }

  # -------------------------------------------------------------
  # 2. Build one path per system key
  # -------------------------------------------------------------
  {
    config_paths <- list()
    for (CONT_001 in seq_len(nrow(file_paths_table))) {
      config_paths[[file_paths_table$key[CONT_001]]] <-
        file.path(config_path, file_paths_table$filename[CONT_001])
    }
    config_paths$config_path <- config_path

    rm(list = c("file_paths_table", "CONT_001"))
  }

  return(config_paths)
}
