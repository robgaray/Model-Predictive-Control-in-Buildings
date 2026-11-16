# -------------------------------------------------------------
# Function: validate_asset_state_gui.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Validates the state of one asset before anything is saved: each of
# its files against the rules of the catalogue (or of its own table,
# for the modes and the occupancy profiles), and then the relations
# between parameters that involve the files of the asset together
# with the files of the system. The relations are checked once for
# each asset, with the files of the system and the files of the
# asset, as the simulation does. Every message starts with the id of
# the asset, so that the user knows which tab to correct.
# -------------------------------------------------------------
# Inputs
#   asset_rv            : reactiveValues. The state of the asset.
#   asset_id            : Character. The id of the asset.
#   files               : Data frame (key, filename). The files of
#                         the asset.
#   validation_config   : List. The catalogue.
#   parameter_relations : Data frame. The relations between
#                         parameters.
#   system_values       : Named list. The values of the files of the
#                         system that the relations may use, named by
#                         the file name.
# -------------------------------------------------------------
# Outputs
#   Character vector of messages, empty when the asset is valid.
# -------------------------------------------------------------
# Code outline
# 1. Validate each file of the asset by its kind.
# 2. When all are valid, check the relations between parameters.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   validate_asset_state_gui(asset_rv, asset_id, files, validation_config,
#                            parameter_relations, system_values)
# -------------------------------------------------------------

validate_asset_state_gui <- function(asset_rv, asset_id, files,
                                     validation_config, parameter_relations,
                                     system_values) {

  kinds    <- asset_file_kind(files$key)
  messages <- character(0)

  # -------------------------------------------------------------
  # 1. Validate each file of the asset by its kind
  # -------------------------------------------------------------
  {
    for (CONT_001 in seq_len(nrow(files))) {
      key       <- files$key[CONT_001]
      file_name <- basename(files$filename[CONT_001])
      if (kinds[CONT_001] == "flat") {
        # validate_param_df_gui is called to check each value of the
        # file against its rule of the catalogue.
        messages <- c(messages, validate_param_df_gui(
          asset_rv[[key]], file_name, validation_config
        ))
      } else if (kinds[CONT_001] == "modes") {
        # validate_param_df_gui is called to check the block of the
        # file, and validate_modes_df_gui its table of modes.
        messages <- c(
          messages,
          validate_param_df_gui(asset_rv[[paste0(key, "__block")]],
                                file_name, validation_config),
          validate_modes_df_gui(asset_rv[[paste0(key, "__table")]])
        )
      } else {
        # validate_occupancy_dfs_gui is called to check the hourly
        # profiles and the monthly mapping that refers to them.
        messages <- c(messages, validate_occupancy_dfs_gui(
          asset_rv[[paste0(key, "__type")]],
          asset_rv[[paste0(key, "__month")]]
        ))
      }
      rm(key, file_name)
    }
    rm(CONT_001)
  }

  # -------------------------------------------------------------
  # 2. When all are valid, check the relations between parameters
  # The values of the asset join those of the system, each under the
  # name of its file. The file of occupancy takes no part in any
  # relation.
  # -------------------------------------------------------------
  {
    if (length(messages) == 0) {
      values <- system_values
      for (CONT_002 in seq_len(nrow(files))) {
        key       <- files$key[CONT_002]
        file_name <- basename(files$filename[CONT_002])
        if (kinds[CONT_002] == "flat") {
          values[[file_name]] <- asset_rv[[key]]
        } else if (kinds[CONT_002] == "modes") {
          values[[file_name]] <- list(
            parameters = asset_rv[[paste0(key, "__block")]],
            table      = asset_rv[[paste0(key, "__table")]]
          )
        }
        rm(key, file_name)
      }

      # check_parameter_relations_gui is called with the relations the
      # simulation also checks, now that every value is valid on its
      # own.
      messages <- check_parameter_relations_gui(parameter_relations, values)
      rm(values, CONT_002)
    }
  }

  if (length(messages) > 0) {
    messages <- paste0(asset_id, ": ", messages)
  }

  return(messages)
}
