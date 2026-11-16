# -------------------------------------------------------------
# Function: apply_table_writes.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Applies a list of writes, in order, to the table that holds each
# column: a column of the asset goes to the table of the asset,
# assets[[asset_id]]$df, and any other column to Main_df.
# When a write changes the net electricity of the asset in an
# itinerary (system_net_energy_columns()), the column of the same
# name of Main_df, the net electricity of the system, is written
# again on the same rows as the sum over the assets
# (sum_asset_energy()). So the energy of the system is always the sum
# of the energy of its assets.
# With asset_id NULL the writes are all of the system: every one goes
# to Main_df, and a column that the table of an asset holds is not
# written there, so the net electricity of the system is only ever
# written as the sum of that of the assets.
# Every write goes through data.table::set(), which writes into the
# existing columns of the table, so neither table is copied.
# -------------------------------------------------------------
# Inputs
#   writes   : List of writes, each a list with:
#                - column : Character scalar. The column written.
#                - rows   : Integer vector. The rows written.
#                - value  : Vector, one value per row.
#                - mode   : "assign" to replace the values, or "add" to
#                           add value to them.
#   Main_df  : Data table. The common and system columns.
#   assets   : Named list, one entry per asset, each with df, the
#              table of the asset (a data table).
#   asset_id : Character scalar. The asset the writes of asset
#              columns belong to. NULL for a list of writes of the
#              system only.
# -------------------------------------------------------------
# Outputs
#   Named list with Main_df and assets, written in place.
# -------------------------------------------------------------
# Code outline
# 1. The columns of the asset and of every asset
# 2. Apply each write to its table, and the sum of the assets to
#    Main_df
# -------------------------------------------------------------
# Usage instructions
# tables <- apply_table_writes(
#   writes   = itinerary_writes,
#   Main_df  = Main_df,
#   assets   = assets,
#   asset_id = asset_id
# )
# Main_df <- tables$Main_df
# assets  <- tables$assets
#
# tables <- apply_table_writes(
#   writes   = system_writes,
#   Main_df  = Main_df,
#   assets   = assets,
#   asset_id = NULL
# )
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - A write to a column that neither table holds stops the run.
#   - The key time is never written.
#   - With asset_id NULL, a write to a column held by the table of
#     any asset stops the run: those writes need the asset_id.
# -------------------------------------------------------------

apply_table_writes <- function(writes,
                               Main_df,
                               assets,
                               asset_id
                               ) {

  # -------------------------------------------------------------
  # 1. The columns of the asset and of every asset
  # The columns of the asset the writes belong to (none when there
  # is no asset_id), and the columns any asset holds, which are not
  # written to Main_df without an asset_id.
  # -------------------------------------------------------------
  {
    if (is.null(asset_id)) {
      asset_df      <- NULL
      asset_columns <- character(0)
    } else {
      asset_df      <- assets[[asset_id]]$df
      asset_columns <- setdiff(names(asset_df), "time")
    }
    # system_net_energy_columns is called to name the columns of the
    # net electricity, the only ones summed over the assets.
    net_energy_columns <- system_net_energy_columns()
    held_columns <- setdiff(
      unique(unlist(lapply(assets, function(CONT_002) names(CONT_002$df)))),
      "time"
    )
  }

  # -------------------------------------------------------------
  # 2. Apply each write to its table, and the sum of the assets to
  #    Main_df
  # -------------------------------------------------------------
  {
    for (CONT_001 in writes) {
      if (CONT_001$column %in% asset_columns) {
        target <- asset_df
      } else if (CONT_001$column %in% setdiff(names(Main_df), "time")) {
        if (is.null(asset_id) && CONT_001$column %in% held_columns) {
          stop("apply_table_writes: the column ", CONT_001$column,
               " is held by the table of an asset; its writes need ",
               "the asset_id")
        }
        target <- Main_df
      } else {
        stop("apply_table_writes: no table holds the column ",
             CONT_001$column)
      }

      value <- if (CONT_001$mode == "add") {
        target[[CONT_001$column]][CONT_001$rows] + CONT_001$value
      } else {
        CONT_001$value
      }
      set(target,
          i     = CONT_001$rows,
          j     = CONT_001$column,
          value = value)

      if (CONT_001$column %in% asset_columns &&
          CONT_001$column %in% names(Main_df) &&
          CONT_001$column %in% net_energy_columns) {
        # sum_asset_energy is called to write again the net
        # electricity of the system on the rows the asset changed.
        set(Main_df,
            i     = CONT_001$rows,
            j     = CONT_001$column,
            value = sum_asset_energy(
              assets  = assets,
              columns = CONT_001$column,
              rows    = CONT_001$rows
            )[[1]])
      }
      rm(list = c("target", "value"))
    }

    rm(list = intersect(c("CONT_001", "asset_df", "asset_columns",
                           "held_columns", "net_energy_columns"), ls()))
  }

  return(list(Main_df = Main_df, assets = assets))
}
