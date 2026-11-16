# -------------------------------------------------------------
# Function: build_reward_asset_inputs.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the panels of the Reward Function tab that hold a parameter
# of each asset of a type, such as the weight of comfort of each
# building. For each row of the table of those parameters there is
# one panel, titled with the block of the parameter in the
# catalogue, with one input for each asset of the type. The input
# is labelled with the id of the asset and the unit of the
# parameter, takes its value from the state of the asset, and is
# painted red while the value comes from the defaults. Its id is
# the one the tab of the asset would give the parameter, so that
# update_asset_from_inputs() takes the value back into the state of
# the asset when the configuration is saved. A value that the user
# typed and has not saved is kept when the panels are built again.
# -------------------------------------------------------------
# Inputs
#   reward_table      : Data frame. The rows of
#                       GUI_reward_asset_parameters.csv.
#   registry          : Data frame (asset_id, asset_type). The assets
#                       of the registry.
#   asset_files       : List of data frames (key, filename), by
#                       asset id. The files of each asset.
#   asset_rvs         : List of reactiveValues, by asset id. The
#                       state of each asset.
#   typed             : Function of one argument, the id of an
#                       input, returning what the user typed in it
#                       or NULL.
#   validation_config : List. The catalogue.
#   max_per_row       : Integer. Number of inputs on each row.
# -------------------------------------------------------------
# Outputs
#   A tagList with one panel for each row of the table that has at
#   least one asset, or NULL when there is none.
# -------------------------------------------------------------
# Code outline
# 1. Build the input of each asset for one parameter.
# 2. Group the inputs of each parameter in a panel.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions. Called
# from the server of the app.
#   build_reward_asset_inputs(
#     reward_table,
#     registry,
#     asset_files,
#     asset_rvs,
#     typed,
#     validation_config,
#     max_per_row)
# -------------------------------------------------------------

build_reward_asset_inputs <- function(reward_table, registry, asset_files,
                                      asset_rvs, typed, validation_config,
                                      max_per_row) {

  panels <- list()

  for (CONT_001 in seq_len(nrow(reward_table))) {
    type_ids  <- registry$asset_id[registry$asset_type ==
                                     reward_table$asset_type[CONT_001]]
    key       <- reward_table$file_key[CONT_001]
    parameter <- reward_table$parameter[CONT_001]
    type_ids  <- type_ids[vapply(
      type_ids,
      function(asset_id) key %in% asset_files[[asset_id]]$key,
      logical(1)
    )]
    if (length(type_ids) == 0) {
      next
    }

    # -------------------------------------------------------------
    # 1. Build the input of each asset for one parameter
    # -------------------------------------------------------------
    {
      file_label <- basename(
        asset_files[[type_ids[1]]]$filename[
          asset_files[[type_ids[1]]]$key == key
        ]
      )
      unit       <- get_param_unit(file_label, parameter)
      input_defs <- lapply(
        type_ids,
        function(asset_id) {
          input_id <- paste0(asset_id, "__", key, "__", parameter)
          state    <- asset_rvs[[asset_id]][[key]]
          value    <- typed(input_id)
          if (is.null(value)) {
            value <- get_param_value(state, parameter)
          }
          list(
            id           = input_id,
            label        = if (nzchar(unit)) {
              paste0(asset_id, " [", unit, "]")
            } else {
              asset_id
            },
            value        = value,
            options      = NULL,
            is_default   = parameter %in%
              asset_rvs[[asset_id]][[paste0(key, "__defaulted")]],
            is_duplicate = parameter %in%
              asset_rvs[[asset_id]][[paste0(key, "__duplicated")]]
          )
        }
      )
      rules <- validation_config$rules
      block <- rules$block[rules$file == file_label &
                             rules$parameter == parameter]
      rm(file_label, unit, rules)
    }

    # -------------------------------------------------------------
    # 2. Group the inputs of each parameter in a panel
    # -------------------------------------------------------------
    {
      # build_input_grid is called to lay out the inputs of the
      # assets in rows.
      panels[[length(panels) + 1]] <- wellPanel(
        h4(if (length(block) == 1) block else parameter),
        build_input_grid(input_defs, max_per_row = max_per_row)
      )
      rm(input_defs, block)
    }
    rm(type_ids, key, parameter)
  }
  rm(CONT_001)

  if (length(panels) == 0) {
    return(NULL)
  }
  return(do.call(tagList, panels))
}
