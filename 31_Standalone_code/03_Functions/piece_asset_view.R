# -------------------------------------------------------------
# Function: piece_asset_view.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the view of one asset of a piece: one plain data frame that
# joins the table of the system and the table of the asset, over
# all the rows of the piece. It is the table that the operations of
# the type of model of the asset work on
# (see join_asset_tables()), with the row names of the table of the
# system of the piece. It is the table that join_asset_tables() gives
# over every row of the piece.
# The view is built from the whole columns of the tables of the
# piece, without copying them: R copies a column only when it is
# modified, so a write into the view never reaches the piece. For the
# same reason a view shall never be written with data.table::set(),
# which modifies the columns in place.
# The position of each column comes from the layout of the piece
# (piece_layout()) when it still describes the tables of the piece,
# and is worked out from the names of the tables otherwise
# (piece_asset_layout()).
# The structure of the piece is described in build_market_piece().
# Its internal objects are removed with rm(list = ), which does not
# call match.call() as rm() with names does: this function runs
# several times for every candidate of the genetic algorithm.
# -------------------------------------------------------------
# Inputs
#   piece        : List. The piece of a market.
#   asset_id     : Character scalar. The asset to give the view of.
#   column_order : Character vector. The order of the columns of the
#                  view (parameters$joined_cols).
# -------------------------------------------------------------
# Outputs
#   Data frame. The columns of the system and of the asset, each
#   once, one row per row of the piece.
# -------------------------------------------------------------
# Code outline
# 1. Check the asset
# 2. The layout of the view
# 3. Join the system and the asset
# -------------------------------------------------------------
# Usage instructions
# view <- piece_asset_view(piece, "Building_001", parameters$joined_cols)
# -------------------------------------------------------------

piece_asset_view <- function(piece,
                             asset_id,
                             column_order
                             ) {

  # -------------------------------------------------------------
  # 1. Check the asset
  # -------------------------------------------------------------
  {
    if (!(asset_id %in% names(piece$assets))) {
      stop("piece_asset_view: the piece holds no asset ", asset_id)
    }
  }

  # -------------------------------------------------------------
  # 2. The layout of the view
  # The layout of the piece is used only if it still describes the
  # tables of the piece.
  # -------------------------------------------------------------
  {
    asset_df <- piece$assets[[asset_id]]$df
    layout   <- piece$layout$assets[[asset_id]]
    if (is.null(layout) ||
        !identical(piece$layout$column_order, column_order) ||
        !identical(piece$layout$system_columns, names(piece$system)) ||
        !identical(layout$asset_columns, names(asset_df))) {
      # piece_asset_layout is called to lay out the view, because
      # the piece holds no layout that still describes its tables.
      layout <- piece_asset_layout(
        system_columns = names(piece$system),
        asset_columns  = names(asset_df),
        column_order   = column_order
      )
    }
  }

  # -------------------------------------------------------------
  # 3. Join the system and the asset
  # A column held by both tables is taken from the asset.
  # -------------------------------------------------------------
  {
    view <- c(unclass(piece$system), unclass(asset_df))[layout$view_index]
    attr(view, "row.names") <- attr(piece$system, "row.names")
    class(view) <- "data.frame"
    rm(list = c("asset_df", "layout"))
  }

  return(view)
}
