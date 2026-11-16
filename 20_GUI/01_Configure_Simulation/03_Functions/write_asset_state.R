# -------------------------------------------------------------
# Function: write_asset_state.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Writes the configuration files of one asset in its folder. The
# folder is created when it does not exist, with an empty .gitkeep
# file so that the folder is kept by the repository. A file that
# exists keeps its comments, its order and its units, and only its
# values change; a file that does not exist is written from the
# catalogue, with a header that names it. The files are written
# according to their kind (see asset_file_kind()). The values must
# have been validated before.
# It reads config_path, the configuration folder GUI_config.R
# resolves at start.
# -------------------------------------------------------------
# Inputs
#   asset_rv     : reactiveValues. The state of the asset.
#   asset_id     : Character. The id of the asset.
#   asset_type   : Character. The type of the asset, for the header
#                  of its new files.
#   files        : Data frame (key, filename). The files of the
#                  asset.
#   asset_folder : Character. Folder of the asset, relative to
#                  config_path.
# -------------------------------------------------------------
# Outputs
#   None. The files are written.
# -------------------------------------------------------------
# Code outline
# 1. Create the folder of the asset.
# 2. Write each file by its kind.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   write_asset_state(asset_rv, asset_id, asset_type, files,
#                     asset_folder)
# -------------------------------------------------------------

write_asset_state <- function(asset_rv, asset_id, asset_type, files,
                              asset_folder) {

  # -------------------------------------------------------------
  # 1. Create the folder of the asset
  # -------------------------------------------------------------
  {
    folder_path <- file.path(config_path, asset_folder)
    if (!dir.exists(folder_path)) {
      dir.create(folder_path, recursive = TRUE, showWarnings = FALSE)
      file.create(file.path(folder_path, ".gitkeep"))
    }
    rm(folder_path)
  }

  # -------------------------------------------------------------
  # 2. Write each file by its kind
  # -------------------------------------------------------------
  {
    kinds <- asset_file_kind(files$key)
    for (CONT_001 in seq_len(nrow(files))) {
      key  <- files$key[CONT_001]
      path <- file.path(asset_folder, files$filename[CONT_001])
      file_header <- c(
        paste0("# ", basename(path)),
        paste0("# Configuration file: ", asset_type, " asset ", asset_id),
        paste0("# ", strrep("-", 61))
      )

      if (kinds[CONT_001] == "flat") {
        # write_param_file is called to write the values of the file,
        # keeping its lines when it exists.
        write_param_file(path, file_header, asset_rv[[key]])
      } else if (kinds[CONT_001] == "modes") {
        # write_mixed_file is called to write the block of parameters,
        # one blank line and the table of modes.
        asset_rv[[paste0(key, "__table")]]$mode <-
          seq_len(nrow(asset_rv[[paste0(key, "__table")]]))
        write_mixed_file(
          path,
          file_header,
          asset_rv[[paste0(key, "__block")]],
          asset_rv[[paste0(key, "__table")]]
        )
      } else {
        # write_use_patterns_file is called to write the two tables of
        # occupancy profiles.
        write_use_patterns_file(
          path,
          asset_rv[[paste0(key, "__type")]],
          asset_rv[[paste0(key, "__month")]]
        )
      }
      rm(key, path, file_header)
    }
    rm(kinds, CONT_001)
  }

  return(invisible(NULL))
}
