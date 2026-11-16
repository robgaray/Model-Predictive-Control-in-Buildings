# -------------------------------------------------------------
# Function: register_asset_observers.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Connects the tab of one asset to its state, inside the server of
# the app. For each file of the asset it fills the outputs that
# build_asset_tab() declared, with the values of the state of the
# asset and their red flags, and for each table of the asset it
# creates the observers of the edit of a cell and of the buttons to
# add a row above, add a row below and delete a row. The ids of the
# inputs of the asset start with its id, so that the assets do not
# share any input. It also creates the observer of the save button
# of the asset, which calls the function given.
# The modes of a table of modes are numbered again after a row is
# added or deleted.
# -------------------------------------------------------------
# Inputs
#   asset_id         : Character. The id of the asset.
#   files            : Data frame (key, filename). The files of the
#                      type of the asset.
#   asset_rv         : reactiveValues. The state of the asset.
#   input            : The Shiny input object.
#   output           : The Shiny output object.
#   save_prefix      : Character. The start of the id of the save
#                      button.
#   on_save          : Function without arguments, called when the
#                      save button of the asset is pressed.
#   validation_config: List. The catalogue.
#   table_callback   : The JavaScript callback of the editable
#                      tables.
#   hidden_parameters: Named list of character vectors, by key of
#                      file. The parameters of each file that the
#                      tab does not show, because another tab holds
#                      their inputs.
# -------------------------------------------------------------
# Outputs
#   List of the observers created, so that they can be destroyed when
#   the asset is removed.
# -------------------------------------------------------------
# Code outline
# 1. Prepare the table renderer and the observers of a table.
# 2. Connect each file by its kind.
# 3. Connect the save button.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions. Called
# from the server of the app.
#   register_asset_observers(asset_id, files, asset_rv, input, output,
#                            save_prefix, on_save, validation_config,
#                            table_callback, hidden_parameters)
# -------------------------------------------------------------

register_asset_observers <- function(asset_id, files, asset_rv, input, output,
                                     save_prefix, on_save, validation_config,
                                     table_callback, hidden_parameters) {

  kinds     <- asset_file_kind(files$key)
  observers <- list()

  # -------------------------------------------------------------
  # 1. Prepare the table renderer and the observers of a table
  # register_table draws the table of a slot of the state, with a
  # text input in each cell, and creates the observers of its edits.
  # label_key is the file name the catalogue gives the units of the
  # columns, or NULL for a table with no units in its headers.
  # renumber tells whether the first column holds the number of the
  # row, which is then written again after each change.
  # -------------------------------------------------------------
  {
    register_table <- function(slot, defaulted_slot, label_key, readonly_cols,
                               renumber) {
      prefix <- paste0(asset_id, "__", slot)

      output[[prefix]] <- renderDT({
        display_df <- build_table_cell_inputs(
          asset_rv[[slot]], prefix,
          defaulted_rows = asset_rv[[defaulted_slot]],
          readonly_cols  = readonly_cols
        )
        column_names <- if (is.null(label_key)) {
          names(display_df)
        } else {
          sapply(names(display_df), label_with_unit,
                 file_key = label_key, USE.NAMES = FALSE)
        }
        datatable(
          display_df,
          rownames = FALSE,
          escape   = FALSE,
          editable = FALSE,
          callback = table_callback,
          colnames = column_names,
          options  = list(dom = "t", ordering = FALSE,
                          pageLength = max(1, nrow(display_df)))
        )
      })

      renumber_rows <- function() {
        if (renumber) {
          asset_rv[[slot]]$mode <- seq_len(nrow(asset_rv[[slot]]))
        }
      }

      # ignoreInit: when the tab of an asset is built a second time in
      # one session, its inputs still hold their last values, and these
      # shall not be applied to the new state when the observer starts.
      list(
        observeEvent(input[[paste0(prefix, "_cell_text_edit")]], {
          asset_rv[[slot]] <- apply_text_table_edit(
            asset_rv[[slot]],
            input[[paste0(prefix, "_cell_text_edit")]]
          )
        }, ignoreInit = TRUE),
        observeEvent(input[[paste0(prefix, "_add_above")]], {
          row_index <- input[[paste0(prefix, "_add_above")]]
          template  <- asset_rv[[slot]][max(1, row_index), , drop = FALSE]
          asset_rv[[slot]] <- insert_row(asset_rv[[slot]], row_index, template)
          renumber_rows()
        }, ignoreInit = TRUE),
        observeEvent(input[[paste0(prefix, "_add_below")]], {
          row_index <- input[[paste0(prefix, "_add_below")]]
          template  <- asset_rv[[slot]][max(1, row_index), , drop = FALSE]
          asset_rv[[slot]] <- insert_row(asset_rv[[slot]], row_index + 1,
                                         template)
          renumber_rows()
        }, ignoreInit = TRUE),
        observeEvent(input[[paste0(prefix, "_delete")]], {
          if (nrow(asset_rv[[slot]]) <= 1) {
            return()
          }
          asset_rv[[slot]] <- asset_rv[[slot]][
            -input[[paste0(prefix, "_delete")]], , drop = FALSE
          ]
          renumber_rows()
        }, ignoreInit = TRUE)
      )
    }
  }

  # -------------------------------------------------------------
  # 2. Connect each file by its kind
  # -------------------------------------------------------------
  {
    for (CONT_001 in seq_len(nrow(files))) {
      local({
        key       <- files$key[CONT_001]
        kind      <- kinds[CONT_001]
        file_name <- basename(files$filename[CONT_001])
        id_stem   <- paste0(asset_id, "__", key)

        if (kind == "flat") {
          output[[paste0(id_stem, "__ui")]] <- renderUI({
            # build_file_editor is called to build the groups of the
            # file from its rows of the catalogue, with the values of
            # the state of the asset.
            build_file_editor(
              df                = asset_rv[[key]],
              prefix            = paste0(id_stem, "__"),
              file_label        = file_name,
              validation_config = validation_config,
              defaulted         = asset_rv[[paste0(key, "__defaulted")]],
              duplicated        = asset_rv[[paste0(key, "__duplicated")]],
              max_per_row       = 4,
              hidden            = as.character(hidden_parameters[[key]])
            )
          })
        } else if (kind == "modes") {
          output[[paste0(id_stem, "__block_ui")]] <- renderUI({
            # build_file_editor is called to build the group of the
            # block of the file of modes, with the values of the state
            # of the asset.
            build_file_editor(
              df                = asset_rv[[paste0(key, "__block")]],
              prefix            = paste0(id_stem, "__block__"),
              file_label        = file_name,
              validation_config = validation_config,
              defaulted         = asset_rv[[paste0(key, "__block__defaulted")]],
              duplicated        = asset_rv[[paste0(key, "__block__duplicated")]],
              max_per_row       = 4,
              hidden            = character(0)
            )
          })
          observers <<- c(observers, register_table(
            slot           = paste0(key, "__table"),
            defaulted_slot = paste0(key, "__table__defaulted_rows"),
            label_key      = file_name,
            readonly_cols  = "mode",
            renumber       = TRUE
          ))
        } else {
          for (CONT_002 in c("type", "month")) {
            observers <<- c(observers, register_table(
              slot           = paste0(key, "__", CONT_002),
              defaulted_slot = paste0(key, "__", CONT_002, "__defaulted_rows"),
              label_key      = NULL,
              readonly_cols  = character(0),
              renumber       = FALSE
            ))
          }
        }
      })
    }
    rm(kinds, CONT_001)
  }

  # -------------------------------------------------------------
  # 3. Connect the save button
  # -------------------------------------------------------------
  {
    observers <- c(observers, list(
      observeEvent(input[[paste0(save_prefix, asset_id)]], {
        on_save()
      }, ignoreInit = TRUE)
    ))
  }

  return(observers)
}
