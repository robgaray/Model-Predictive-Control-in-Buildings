# -------------------------------------------------------------
# Function: load_asset_state.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads every configuration file of one asset with the safe loaders
# of the app, according to the kind of each file (see
# asset_file_kind()). Whatever the folder of the asset lacks, or
# holds invalid, takes its default value, and is flagged so that the
# interface paints it in red until it is saved. An asset whose
# folder does not exist gets the default values of every file, the
# same ones the simulator writes for a new asset. Nothing is written.
# The state is a flat named list, one element per piece of a file.
# For the file with key K:
#   - a flat file: K (data frame of parameter and value),
#     K__defaulted and K__duplicated (parameter names).
#   - a file of modes: K__block (the block of parameters) with
#     K__block__defaulted and K__block__duplicated, K__table (the
#     modes) with K__table__defaulted_rows (row numbers).
#   - a file of occupancy: K__type (the hourly profiles) and
#     K__month (the monthly mapping), with K__type__defaulted_rows
#     and K__month__defaulted_rows.
# It reads config_path, the configuration folder GUI_config.R
# resolves at start.
# -------------------------------------------------------------
# Inputs
#   asset_id          : Character. The id of the asset, used in the
#                       messages.
#   files             : Data frame (key, filename). The files of the
#                       type of the asset, from asset_type_files().
#   asset_folder      : Character. Folder of the asset, relative to
#                       config_path.
#   validation_config : List. The catalogue, from load_gui_catalogue().
# -------------------------------------------------------------
# Outputs
#   Named list with the elements:
#     - state: the flat named list described above.
#     - origin: folder when the folder of the asset exists, defaults
#       when it does not.
#     - messages: Character vector, each one starting with the id.
# -------------------------------------------------------------
# Code outline
# 1. Find out where the values come from.
# 2. Load each file by its kind.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   load_asset_state(asset_id, files, asset_folder, validation_config)
# -------------------------------------------------------------

load_asset_state <- function(asset_id, files, asset_folder,
                             validation_config) {

  # -------------------------------------------------------------
  # 1. Find out where the values come from
  # -------------------------------------------------------------
  {
    origin   <- if (dir.exists(file.path(config_path, asset_folder))) {
      "folder"
    } else {
      "defaults"
    }
    kinds    <- asset_file_kind(files$key)
    state    <- list()
    messages <- character(0)
  }

  # -------------------------------------------------------------
  # 2. Load each file by its kind
  # -------------------------------------------------------------
  {
    for (CONT_001 in seq_len(nrow(files))) {
      key       <- files$key[CONT_001]
      path      <- file.path(asset_folder, files$filename[CONT_001])
      file_name <- basename(files$filename[CONT_001])

      if (kinds[CONT_001] == "flat") {
        # load_param_file_safe is called to read the file and fill what
        # is missing or invalid with the defaults of the catalogue.
        loaded <- load_param_file_safe(
          filename          = path,
          file_label        = file_name,
          validation_config = validation_config,
          reader            = read_param_file
        )
        state[[key]]                         <- loaded$df
        state[[paste0(key, "__defaulted")]]  <- loaded$defaulted
        state[[paste0(key, "__duplicated")]] <- loaded$duplicated
        messages <- c(messages, loaded$messages)
        rm(loaded)
      } else if (kinds[CONT_001] == "modes") {
        # load_param_file_safe is called to read the block of
        # parameters of the file of modes, with the defaults of the
        # catalogue for what is missing or invalid.
        block_loaded <- load_param_file_safe(
          filename          = path,
          file_label        = file_name,
          validation_config = validation_config,
          reader            = read_param_block
        )
        # load_modes_file_safe is called to read the table of modes
        # row by row, with the rows of its Default_ file as defaults.
        table_loaded <- load_modes_file_safe(path, default_file_for(path))
        state[[paste0(key, "__block")]]              <- block_loaded$df
        state[[paste0(key, "__block__defaulted")]]   <- block_loaded$defaulted
        state[[paste0(key, "__block__duplicated")]]  <- block_loaded$duplicated
        state[[paste0(key, "__table")]]              <- table_loaded$df
        state[[paste0(key, "__table__defaulted_rows")]] <-
          table_loaded$defaulted_rows
        messages <- c(messages, block_loaded$messages, table_loaded$messages)
        rm(block_loaded, table_loaded)
      } else {
        # load_occupancy_file_safe is called to read the two tables of
        # occupancy profiles, with those of the Default_ file as
        # defaults.
        loaded <- load_occupancy_file_safe(path, default_file_for(path))
        state[[paste0(key, "__type")]]  <- loaded$day_types
        state[[paste0(key, "__month")]] <- loaded$month_profiles
        state[[paste0(key, "__type__defaulted_rows")]] <-
          loaded$defaulted_type_rows
        state[[paste0(key, "__month__defaulted_rows")]] <-
          loaded$defaulted_month_rows
        messages <- c(messages, loaded$messages)
        rm(loaded)
      }
      rm(key, path, file_name)
    }

    if (length(messages) > 0) {
      messages <- paste0(asset_id, ": ", messages)
    }
    rm(kinds, CONT_001)
  }

  return(list(state = state, origin = origin, messages = messages))
}
