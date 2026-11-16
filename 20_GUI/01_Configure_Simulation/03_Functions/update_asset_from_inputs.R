# -------------------------------------------------------------
# Function: update_asset_from_inputs.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Brings the edits of the user into the state of one asset: the
# pending edits of the cells of its tables and the current value of
# each input of its flat files and of the block of its file of
# modes. The state is a reactiveValues object, so it is changed in
# place. The tables of the occupancy file are turned to text, as the
# validation and the writers expect.
# -------------------------------------------------------------
# Inputs
#   asset_rv : reactiveValues. The state of the asset, as built from
#              load_asset_state().
#   asset_id : Character. The id of the asset, which starts the id of
#              each of its inputs.
#   files    : Data frame (key, filename). The files of the asset.
#   input    : The Shiny input object.
# -------------------------------------------------------------
# Outputs
#   None. The state of the asset is changed.
# -------------------------------------------------------------
# Code outline
# 1. Apply the pending edits of the cells of the tables.
# 2. Read the inputs of the flat files and of the block of modes.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   update_asset_from_inputs(asset_rv, asset_id, files, input)
# -------------------------------------------------------------

update_asset_from_inputs <- function(asset_rv, asset_id, files, input) {

  kinds <- asset_file_kind(files$key)

  # -------------------------------------------------------------
  # 1. Apply the pending edits of the cells of the tables
  # -------------------------------------------------------------
  {
    for (CONT_001 in seq_len(nrow(files))) {
      key <- files$key[CONT_001]
      if (kinds[CONT_001] == "modes") {
        slots <- paste0(key, "__table")
      } else if (kinds[CONT_001] == "occupancy") {
        slots <- paste0(key, c("__type", "__month"))
      } else {
        next
      }
      for (CONT_002 in slots) {
        prefix <- paste0(asset_id, "__", CONT_002)
        # apply_text_table_edit is called to apply the last edit of a
        # cell of the table that the browser has sent.
        asset_rv[[CONT_002]] <- apply_text_table_edit(
          asset_rv[[CONT_002]],
          input[[paste0(prefix, "_cell_text_edit")]]
        )
        if (kinds[CONT_001] == "occupancy") {
          asset_rv[[CONT_002]][] <- lapply(asset_rv[[CONT_002]], as.character)
        }
        rm(prefix)
      }
      rm(key, slots)
    }
  }

  # -------------------------------------------------------------
  # 2. Read the inputs of the flat files and of the block of modes
  # -------------------------------------------------------------
  {
    for (CONT_002 in seq_len(nrow(files))) {
      key <- files$key[CONT_002]
      if (kinds[CONT_002] == "flat") {
        slot   <- key
        prefix <- paste0(asset_id, "__", key, "__")
      } else if (kinds[CONT_002] == "modes") {
        slot   <- paste0(key, "__block")
        prefix <- paste0(asset_id, "__", key, "__block__")
      } else {
        next
      }
      # update_df_from_inputs is called to take the value of each
      # input of the file back into its data frame.
      asset_rv[[slot]] <- update_df_from_inputs(asset_rv[[slot]], prefix, input)
      rm(key, slot, prefix)
    }
    rm(kinds, CONT_001, CONT_002)
  }

  return(invisible(NULL))
}
