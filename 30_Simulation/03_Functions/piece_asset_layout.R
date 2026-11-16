# -------------------------------------------------------------
# Function: piece_asset_layout.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the layout of the view of one asset of a piece: where each
# column of the view comes from. A view (piece_asset_view()) and an
# absorb (piece_absorb_asset()) take columns by position with this
# layout, instead of matching about a hundred column names every
# time.
# The columns of the view are in the order that
# joined_column_order() gives. A column of the table of the asset,
# the net electricity included, is taken from that table. Time and
# every other column are taken from the table of the system.
# The layout is a list with these elements:
#   - asset_columns: the names of the table of the asset, time
#     included, that the layout was built for.
#   - view_columns: the names of the view, in order.
#   - view_index: the position of each column of the view in the list
#     of the columns of the system followed by the columns of the
#     asset.
#   - own_columns: the columns of the asset, without time.
#   - own_in_view: the position of each own column in the view.
#   - net_columns: the own columns that are the net electricity of
#     the system (system_net_energy_columns()) and that the system
#     also holds.
# Its internal objects are removed with rm(list = ), which does not
# call match.call() as rm() with names does: this function runs
# several times for every candidate of the genetic algorithm.
# -------------------------------------------------------------
# Inputs
#   system_columns : Character vector. The names of the table of the
#                    system of the piece.
#   asset_columns  : Character vector. The names of the table of the
#                    asset, time included.
#   column_order   : Character vector. The order of the columns of
#                    the view (parameters$joined_cols).
# -------------------------------------------------------------
# Outputs
#   List. The layout described above.
# -------------------------------------------------------------
# Code outline
# 1. The columns of the view, in order
# 2. Where each column of the view comes from
# 3. The layout
# -------------------------------------------------------------
# Usage instructions
# layout <- piece_asset_layout(names(piece$system),
#                              names(piece$assets$Building_001$df),
#                              parameters$joined_cols)
# -------------------------------------------------------------

piece_asset_layout <- function(system_columns,
                               asset_columns,
                               column_order
                               ) {

  # -------------------------------------------------------------
  # 1. The columns of the view, in order
  # -------------------------------------------------------------
  {
    own_columns  <- asset_columns[asset_columns != "time"]
    # joined_column_order is called to order the columns of the view
    # as join_asset_tables() orders those of the joined table.
    view_columns <- joined_column_order(
      system_columns = system_columns,
      asset_columns  = own_columns,
      column_order   = column_order
    )
  }

  # -------------------------------------------------------------
  # 2. Where each column of the view comes from
  # The view is taken from the list of the columns of the system
  # followed by the columns of the asset. A column of the asset is
  # taken from the asset, and any other column from the system.
  # -------------------------------------------------------------
  {
    from_asset <- match(view_columns, own_columns)
    view_index <- match(view_columns, system_columns)
    view_index[!is.na(from_asset)] <- length(system_columns) +
      match(view_columns[!is.na(from_asset)], asset_columns)
  }

  # -------------------------------------------------------------
  # 3. The layout
  # The net columns are the own columns that are the net electricity
  # of the system. Any other column that both tables hold is not
  # summed over the assets.
  # -------------------------------------------------------------
  {
    # system_net_energy_columns is called to name the columns of the
    # net electricity, the only ones that are summed over the assets.
    net_energy_columns <- system_net_energy_columns()
    layout <- list(
      asset_columns = asset_columns,
      view_columns  = view_columns,
      view_index    = view_index,
      own_columns   = own_columns,
      own_in_view   = match(own_columns, view_columns),
      net_columns   = own_columns[own_columns %in% system_columns &
                                    own_columns %in% net_energy_columns]
    )
    rm(list = c("own_columns", "view_columns", "from_asset",
                "view_index", "net_energy_columns"))
  }

  return(layout)
}
