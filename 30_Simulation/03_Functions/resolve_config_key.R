# -------------------------------------------------------------
# Function: resolve_config_key.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the file name of a configuration file named by its key in
# 00_Inner_parameters/04_File_paths.csv. A file common to the whole
# simulation (scope "system") is named by its key, for example
# "reward_file". A file that every asset of a type of model holds
# is named by the asset and the key, <asset_id>/<key>, for example
# "Building_001/model_file". The type of the asset is the part of
# its identifier before the underscore and the number of three
# digits, and it has to be the scope of the key.
# -------------------------------------------------------------
# Inputs
#   key_name    : Character of length one. A key of the file paths
#                 table, or <asset_id>/<key> for a file of an
#                 asset. It carries no leading @.
#   config_path : Character. Path of the configuration folder.
# -------------------------------------------------------------
# Outputs
#   Character of length one: the file name, relative to the
#   configuration folder. For a file of an asset it is the folder
#   of the assets (the file of the key asset_config_folder), the
#   identifier of the asset and the file name of the key. The run
#   stops if the key is not in the table, if a system key carries
#   an asset, if a key of a type of model has no asset, or if the
#   type of the asset is not the scope of the key.
# -------------------------------------------------------------
# Code outline
# 1. Read the table of file names
# 2. Split the asset from the key
# 3. Look up the key and build the file name
# -------------------------------------------------------------
# Usage instructions
# resolve_config_key("reward_file", config_path)
# resolve_config_key("Building_001/model_file", config_path)
# -------------------------------------------------------------

resolve_config_key <- function(key_name, config_path) {

  # -------------------------------------------------------------
  # 1. Read the table of file names
  # -------------------------------------------------------------
  {
    # read_file_paths_table is called to read and check the table of
    # file names that every file of the configuration is named in.
    file_paths_table <- read_file_paths_table(config_path = config_path)
  }

  # -------------------------------------------------------------
  # 2. Split the asset from the key
  # -------------------------------------------------------------
  {
    parts <- strsplit(key_name, "/", fixed = TRUE)[[1]]
    if (length(parts) == 1) {
      asset_id <- NULL
      key_only <- parts
    } else if (length(parts) == 2 && nzchar(parts[1]) && nzchar(parts[2])) {
      asset_id <- parts[1]
      key_only <- parts[2]
    } else {
      stop("'", key_name, "' is not a key of 04_File_paths.csv, nor an ",
           "<asset_id>/<key>")
    }

    rm(list = "parts")
  }

  # -------------------------------------------------------------
  # 3. Look up the key and build the file name
  # -------------------------------------------------------------
  {
    row <- which(file_paths_table$key == key_only)
    if (length(row) != 1) {
      stop("'", key_only, "' is not a key of 04_File_paths.csv")
    }
    scope <- file_paths_table$scope[row]

    if (is.null(asset_id)) {
      if (scope != "system") {
        stop("The key '", key_only, "' belongs to every asset of type ",
             scope, ": write it as <asset_id>/", key_only)
      }
      file_name <- file_paths_table$filename[row]
    } else {
      if (scope == "system") {
        stop("The key '", key_only, "' is a system file: it takes no ",
             "asset ('", asset_id, "')")
      }
      if (!grepl("^.+_[0-9]{3}$", asset_id) ||
          sub("_[0-9]{3}$", "", asset_id) != scope) {
        stop("The asset '", asset_id, "' is not of type ", scope,
             ", the scope of the key '", key_only, "'")
      }
      folder_row <- which(file_paths_table$key == "asset_config_folder")
      if (length(folder_row) != 1) {
        stop("04_File_paths.csv must hold the key asset_config_folder ",
             "once, to name the files of an asset")
      }
      file_name <- paste(file_paths_table$filename[folder_row], asset_id,
                         file_paths_table$filename[row], sep = "/")
      rm(list = "folder_row")
    }

    rm(list = c("file_paths_table", "asset_id", "key_only", "row", "scope"))
  }

  return(file_name)
}
