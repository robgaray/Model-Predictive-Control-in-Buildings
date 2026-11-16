# -------------------------------------------------------------
# Function: build_asset_tab.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the tab of one asset: a tab titled with its id, with one
# tab inside it for each file of its type of model, and a button
# that saves the whole configuration. Each inner tab holds the
# outputs that register_asset_observers() fills, named after the id
# of the asset and the key of the file:
#   - a flat file: the output <id>__<key>__ui, with the groups of
#     its parameters.
#   - a file of modes: the output <id>__<key>__block_ui, with the
#     block of parameters, and the table <id>__<key>__table.
#   - a file of occupancy: the tables <id>__<key>__type and
#     <id>__<key>__month.
# The button is <save_prefix><id>.
# -------------------------------------------------------------
# Inputs
#   asset_id    : Character. The id of the asset.
#   files       : Data frame (key, filename). The files of the type
#                 of the asset.
#   save_prefix : Character. The start of the id of the save button.
# -------------------------------------------------------------
# Outputs
#   A tabPanel.
# -------------------------------------------------------------
# Code outline
# 1. Build one inner tab for each file.
# 2. Join them in the tab of the asset, with the save button.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   build_asset_tab(asset_id, files, save_prefix)
# -------------------------------------------------------------

build_asset_tab <- function(asset_id, files, save_prefix) {

  kinds <- asset_file_kind(files$key)

  # -------------------------------------------------------------
  # 1. Build one inner tab for each file
  # -------------------------------------------------------------
  {
    inner_tabs <- lapply(
      seq_len(nrow(files)),
      function(CONT_001) {
        id_stem <- paste0(asset_id, "__", files$key[CONT_001])
        # asset_tab_title is called to name the tab after its file.
        title   <- asset_tab_title(files$filename[CONT_001])
        if (kinds[CONT_001] == "flat") {
          tabPanel(title, uiOutput(paste0(id_stem, "__ui")))
        } else if (kinds[CONT_001] == "modes") {
          tabPanel(
            title,
            uiOutput(paste0(id_stem, "__block_ui")),
            DTOutput(paste0(id_stem, "__table"))
          )
        } else {
          tabPanel(
            title,
            h4("Day Type Profiles [0/1 per hour]"),
            DTOutput(paste0(id_stem, "__type")),
            h4("Monthly Weekday Mapping [TYPE reference per weekday]"),
            DTOutput(paste0(id_stem, "__month"))
          )
        }
      }
    )
  }

  # -------------------------------------------------------------
  # 2. Join them in the tab of the asset, with the save button
  # -------------------------------------------------------------
  {
    asset_tab <- tabPanel(
      asset_id,
      do.call(tabsetPanel, c(list(id = paste0("tabs_", asset_id)), inner_tabs)),
      actionButton(paste0(save_prefix, asset_id), "save all",
                   class = "btn-primary")
    )
    rm(inner_tabs, kinds)
  }

  return(asset_tab)
}
