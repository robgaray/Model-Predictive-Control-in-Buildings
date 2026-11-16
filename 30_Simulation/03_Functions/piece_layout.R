# -------------------------------------------------------------
# Function: piece_layout.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives a piece with the layout of the view of each of its assets
# (see piece_asset_layout()), in the element layout. The layout is
# optional: a piece without it works the same, only slower. It is
# worth computing before a loop that takes many views of a piece
# whose columns do not change, such as the evaluation of the
# candidates of the genetic algorithm.
# The layout is checked at every use: a view or an absorb uses it
# only if the names of the tables and the column order are those it
# was built for, and works the positions out again otherwise. So a
# function that changes the columns of a table does not need to
# update it, and a stale layout can never change a result.
# A piece whose layout still describes it is returned untouched.
# The structure of the piece is described in build_market_piece().
# Its internal objects are removed with rm(list = ), which does not
# call match.call() as rm() with names does.
# -------------------------------------------------------------
# Inputs
#   piece        : List. The piece of a market.
#   column_order : Character vector. The order of the columns of the
#                  views (parameters$joined_cols).
# -------------------------------------------------------------
# Outputs
#   List. The piece, with the element layout:
#     - column_order: the column order it was built for.
#     - system_columns: the names of the table of the system.
#     - assets: one layout (piece_asset_layout()) per asset.
# -------------------------------------------------------------
# Code outline
# 1. Keep a layout that still describes the piece
# 2. Lay out the view of each asset
# -------------------------------------------------------------
# Usage instructions
# piece <- piece_layout(piece, parameters$joined_cols)
# -------------------------------------------------------------

piece_layout <- function(piece,
                         column_order
                         ) {

  # -------------------------------------------------------------
  # 1. Keep a layout that still describes the piece
  # -------------------------------------------------------------
  {
    layout_valid <- !is.null(piece$layout) &&
      identical(piece$layout$column_order, column_order) &&
      identical(piece$layout$system_columns, names(piece$system)) &&
      identical(names(piece$layout$assets), names(piece$assets))
    if (layout_valid) {
      for (CONT_001 in names(piece$assets)) {
        if (!identical(piece$layout$assets[[CONT_001]]$asset_columns,
                       names(piece$assets[[CONT_001]]$df))) {
          layout_valid <- FALSE
        }
      }
      rm(list = "CONT_001")
    }
  }

  # -------------------------------------------------------------
  # 2. Lay out the view of each asset
  # -------------------------------------------------------------
  {
    if (!layout_valid) {
      asset_layouts <- list()
      for (CONT_002 in names(piece$assets)) {
        # piece_asset_layout is called to lay out the view of the
        # asset, from the names of the tables of the piece.
        asset_layouts[[CONT_002]] <- piece_asset_layout(
          system_columns = names(piece$system),
          asset_columns  = names(piece$assets[[CONT_002]]$df),
          column_order   = column_order
        )
      }
      piece$layout <- list(
        column_order   = column_order,
        system_columns = names(piece$system),
        assets         = asset_layouts
      )
      rm(list = c("asset_layouts", "CONT_002"))
    }
    rm(list = "layout_valid")
  }

  return(piece)
}
