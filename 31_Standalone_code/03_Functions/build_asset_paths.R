# -------------------------------------------------------------
# Function: build_asset_paths.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the path of every configuration file of one asset. Each
# asset has its own configuration folder, named by the asset id
# inside the folder of the assets (the file of the key
# asset_config_folder in 00_Inner_parameters/05_File_paths.csv).
# The files it holds are the rows of the file paths table whose
# scope is the type of model of the asset. The paths have the same
# form as the ones build_config_paths() gives for the system, so
# that the code that loads a file reads asset_paths$model_file as
# it would read paths$model_file.
# -------------------------------------------------------------
# Inputs
#   config_path : Character. Path of the configuration folder, the
#                 one that holds 00_Inner_parameters/.
#   asset_id    : Character. The id of the asset, for example
#                 "Building_001".
#   asset_type  : Character. The type of model of the asset, for
#                 example "Building".
# -------------------------------------------------------------
# Outputs
#   Named list of character values, one path per key of the type of
#   model, built as the folder of the asset plus the file name of
#   the key. The run stops, naming the asset, if the type has no
#   file in the table, if the folder of the asset does not exist, or
#   if one of its files does not exist.
# -------------------------------------------------------------
# Code outline
# 1. Read the table of file names and select the files of the type
# 2. Check the folder of the asset
# 3. Build and check one path per key
# -------------------------------------------------------------
# Usage instructions
# asset_paths <- build_asset_paths(
#   config_path = file.path("31_Standalone_code", "02_Config"),
#   asset_id    = "Building_001",
#   asset_type  = "Building"
# )
# asset_paths$model_file
# -------------------------------------------------------------

build_asset_paths <- function(config_path,
                              asset_id,
                              asset_type) {

  # -------------------------------------------------------------
  # 1. Read the table of file names and select the files of the type
  # -------------------------------------------------------------
  {
    # read_file_paths_table is called to read the table of file names
    # and check that it holds one row per file, with a unique key.
    file_paths_table <- read_file_paths_table(config_path = config_path)

    folder_row <- which(file_paths_table$key == "asset_config_folder")
    if (length(folder_row) != 1) {
      stop("05_File_paths.csv must hold the key asset_config_folder ",
           "once, to name the folder of each asset")
    }

    type_files <- file_paths_table[file_paths_table$scope == asset_type, ]
    if (nrow(type_files) == 0) {
      stop("05_File_paths.csv holds no file for the type of model '",
           asset_type, "' of the asset ", asset_id)
    }
  }

  # -------------------------------------------------------------
  # 2. Check the folder of the asset
  # -------------------------------------------------------------
  {
    asset_folder <- file.path(config_path,
                              file_paths_table$filename[folder_row],
                              asset_id)
    if (!dir.exists(asset_folder)) {
      stop("The configuration folder of the asset ", asset_id,
           " does not exist: ", asset_folder)
    }
  }

  # -------------------------------------------------------------
  # 3. Build and check one path per key
  # -------------------------------------------------------------
  {
    asset_paths <- list()
    for (CONT_001 in seq_len(nrow(type_files))) {
      asset_file <- file.path(asset_folder, type_files$filename[CONT_001])
      if (!file.exists(asset_file)) {
        stop("The file ", type_files$filename[CONT_001], " of the asset ",
             asset_id, " does not exist: ", asset_file)
      }
      asset_paths[[type_files$key[CONT_001]]] <- asset_file
    }

    rm(list = c("file_paths_table", "folder_row", "type_files", "asset_folder",
                "asset_file", "CONT_001"))
  }

  return(asset_paths)
}
