# -------------------------------------------------------------
# Function: piece_absorb_asset.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Takes back into a piece what the functions of a market have done
# to the view of an asset (see piece_asset_view()). The columns of
# the table of the asset come back to that table. For each of them
# that is the net electricity of the system in an itinerary
# (system_net_energy_columns()) and that the table of the system
# holds too, the column of the system is written again
# as the sum over the assets (sum_asset_energy(), once for all of
# them), so the energy of the system is always the sum of the energy
# of its assets. With a single asset that sum is the column of the
# asset, unchanged.
# The other columns of the view are not taken back: the columns of
# the system are written by the functions of the system in its table.
# It stops when the view lacks a column of the table of the asset.
# The columns are taken by position from the layout of the piece
# (piece_layout()) when it still describes the tables of the piece,
# and by name otherwise.
# The structure of the piece is described in build_market_piece().
# Its internal objects are removed with rm(list = ), which does not
# call match.call() as rm() with names does: this function runs
# several times for every candidate of the genetic algorithm.
# -------------------------------------------------------------
# Inputs
#   piece    : List. The piece of a market.
#   asset_id : Character scalar. The asset the view belongs to.
#   view     : Data frame. The view of the asset, with as many rows
#              as the piece.
# -------------------------------------------------------------
# Outputs
#   List. The piece with the table of the asset updated and the net
#   electricity of the system summed again.
# -------------------------------------------------------------
# Code outline
# 1. Check the asset and the view
# 2. The columns of the asset come back to its table
# 3. The net electricity
# -------------------------------------------------------------
# Usage instructions
# piece <- piece_absorb_asset(piece, "Building_001", view)
# -------------------------------------------------------------

piece_absorb_asset <- function(piece,
                               asset_id,
                               view
                               ) {

  # -------------------------------------------------------------
  # 1. Check the asset and the view
  # -------------------------------------------------------------
  {
    if (!(asset_id %in% names(piece$assets))) {
      stop("piece_absorb_asset: the piece holds no asset ", asset_id)
    }
    asset_df <- piece$assets[[asset_id]]$df
    # .row_names_info(x, 2L) is the number of rows, as nrow() reads it.
    if (.row_names_info(view, 2L) != .row_names_info(asset_df, 2L)) {
      stop("piece_absorb_asset: the view has ", nrow(view),
           " rows and the table of ", asset_id, " has ",
           nrow(asset_df))
    }
    layout       <- piece$layout$assets[[asset_id]]
    layout_asset <- !is.null(layout) &&
      identical(layout$asset_columns, names(asset_df))
    if (layout_asset && identical(layout$view_columns, names(view))) {
      own_columns <- layout$own_columns
      own_in_view <- layout$own_in_view
    } else {
      own_columns <- names(asset_df)[names(asset_df) != "time"]
      own_in_view <- match(own_columns, names(view))
    }
    if (anyNA(own_in_view)) {
      stop("piece_absorb_asset: the view lacks the columns ",
           paste(own_columns[is.na(own_in_view)], collapse = ", "),
           " of the table of ", asset_id)
    }
  }

  # -------------------------------------------------------------
  # 2. The columns of the asset come back to its table
  # The key time is not written. The columns are written on the
  # list of columns of the table, by position, without copying the
  # others.
  # -------------------------------------------------------------
  {
    columns <- unclass(asset_df)
    columns[names(asset_df) != "time"] <- unclass(view)[own_in_view]
    attr(columns, "row.names") <- attr(asset_df, "row.names")
    class(columns) <- "data.frame"
    piece$assets[[asset_id]]$df <- columns
  }

  # -------------------------------------------------------------
  # 3. The net electricity
  # The net columns are those of the asset that are the net
  # electricity of the system and that the system holds.
  # -------------------------------------------------------------
  {
    if (layout_asset &&
        identical(piece$layout$system_columns, names(piece$system))) {
      net_columns <- layout$net_columns
    } else {
      # system_net_energy_columns is called to name the columns of
      # the net electricity, the only ones summed over the assets.
      net_columns <- own_columns[
        own_columns %in% names(piece$system) &
          own_columns %in% system_net_energy_columns()
      ]
    }
    columns <- unclass(piece$system)
    # sum_asset_energy is called to write the net electricity of the
    # system as the sum of that of the assets, for every net column
    # at once.
    columns[net_columns] <- sum_asset_energy(
      assets  = piece$assets,
      columns = net_columns,
      rows    = seq_len(.row_names_info(piece$system, 2L))
    )
    class(columns) <- "data.frame"
    piece$system <- columns
    rm(list = c("asset_df", "layout", "layout_asset", "own_columns",
                "own_in_view", "net_columns", "columns"))
  }

  return(piece)
}
