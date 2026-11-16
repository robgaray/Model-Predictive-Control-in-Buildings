# -------------------------------------------------------------
# Function: asset_pending_tabs.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Tells which tabs of one asset have something pending for the user:
# values that took a default, parameters found twice, or edits that
# are not saved. It gives one answer for each inner tab of the asset,
# named with the title that build_asset_tab() gave the tab. The
# parameters that the Reward Function tab holds for the asset are
# not counted in its inner tabs, because the user edits them in that
# tab. They are given apart, so that the Reward Function tab can
# count them.
# -------------------------------------------------------------
# Inputs
#   asset_id          : Character. The id of the asset.
#   files             : Data frame (key, filename). The files of the
#                       type of the asset.
#   asset_rv          : reactiveValues. The state of the asset.
#   baseline          : List. The state of the asset as last read from
#                       disk or saved.
#   input             : The Shiny input object.
#   hidden_parameters : Named list of character vectors, by key of
#                       file. The parameters held by the Reward
#                       Function tab.
# -------------------------------------------------------------
# Outputs
#   Named list with the elements:
#     - tabs: named logical vector, by title of inner tab.
#     - reward: logical. TRUE when a parameter that the Reward
#       Function tab holds is pending.
# -------------------------------------------------------------
# Code outline
# 1. Check each file by its kind.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions. Called
# from a reactive of the server.
#   asset_pending_tabs(asset_id, files, asset_rv, baseline, input,
#                      hidden_parameters)
# -------------------------------------------------------------

asset_pending_tabs <- function(asset_id, files, asset_rv, baseline, input,
                               hidden_parameters) {

  kinds       <- asset_file_kind(files$key)
  tabs        <- setNames(logical(0), character(0))
  reward_flag <- FALSE

  # -------------------------------------------------------------
  # 1. Check each file by its kind
  # -------------------------------------------------------------
  {
    for (CONT_001 in seq_len(nrow(files))) {
      key   <- files$key[CONT_001]
      # asset_tab_title is called to name the tab as its inner tab.
      title <- asset_tab_title(files$filename[CONT_001])

      if (kinds[CONT_001] == "flat") {
        df     <- asset_rv[[key]]
        shared <- as.character(hidden_parameters[[key]])
        flagged <- c(asset_rv[[paste0(key, "__defaulted")]],
                     asset_rv[[paste0(key, "__duplicated")]])
        prefix  <- paste0(asset_id, "__", key, "__")
        # param_file_pending is called twice: for the parameters of
        # the inner tab, and for those of the Reward Function tab.
        tabs[[title]] <- param_file_pending(
          df          = df,
          baseline_df = baseline[[key]],
          prefix      = prefix,
          input       = input,
          flagged     = flagged,
          include     = setdiff(as.character(df$parameter), shared)
        )
        reward_flag <- reward_flag || param_file_pending(
          df          = df,
          baseline_df = baseline[[key]],
          prefix      = prefix,
          input       = input,
          flagged     = flagged,
          include     = shared
        )
        rm(df, shared, flagged, prefix)
      } else if (kinds[CONT_001] == "modes") {
        block_key <- paste0(key, "__block")
        table_key <- paste0(key, "__table")
        # param_file_pending is called for the block of parameters
        # above the table of modes, and table_pending for the table.
        tabs[[title]] <- param_file_pending(
          df          = asset_rv[[block_key]],
          baseline_df = baseline[[block_key]],
          prefix      = paste0(asset_id, "__", key, "__block__"),
          input       = input,
          flagged     = c(asset_rv[[paste0(block_key, "__defaulted")]],
                          asset_rv[[paste0(block_key, "__duplicated")]]),
          include     = as.character(asset_rv[[block_key]]$parameter)
        ) || table_pending(
          df             = asset_rv[[table_key]],
          baseline_df    = baseline[[table_key]],
          defaulted_rows = asset_rv[[paste0(table_key, "__defaulted_rows")]]
        )
        rm(block_key, table_key)
      } else {
        tabs[[title]] <- FALSE
        for (CONT_002 in c("type", "month")) {
          slot <- paste0(key, "__", CONT_002)
          # table_pending is called for each table of occupancy.
          tabs[[title]] <- tabs[[title]] || table_pending(
            df             = asset_rv[[slot]],
            baseline_df    = baseline[[slot]],
            defaulted_rows = asset_rv[[paste0(slot, "__defaulted_rows")]]
          )
          rm(slot)
        }
        rm(CONT_002)
      }
      rm(key, title)
    }
    rm(kinds, CONT_001)
  }

  return(list(tabs = tabs, reward = reward_flag))
}
