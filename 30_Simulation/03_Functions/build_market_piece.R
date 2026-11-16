# -------------------------------------------------------------
# Function: build_market_piece.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the piece a market works on: the rows of the period of the
# market, taken from Main_df and from the table of every asset, each
# in a table of its own.
# The piece is a list:
#   piece <- list(
#     system = <data.frame>,
#     assets = list(
#       Building_001 = list(df = <data.frame>)
#     )
#   )
#   - system : the rows of Main_df, with every column of Main_df.
#     It holds the net electricity of the system in each itinerary
#     (the sum over the assets), the commitments of the two
#     flexibility legs, and the working columns of the market that
#     no table of an asset holds and that are created along the way
#     (the phases of the flexibility windows, the reward). Any
#     column that is not a column of the table of an asset is a
#     column of the system.
#   - assets : one entry per asset, in the order of the asset
#     registry, each with df, the rows of the table of the asset,
#     with the key time first.
#   - layout : optional. The layout of the view of each asset
#     (piece_layout()), which build_market_piece() does not build. A
#     view and an absorb use it only after checking that it still
#     describes the tables, so a function that changes the columns
#     of a table does not need to update it.
# Every table is a plain data frame, never a data table, and all
# of them have the same number of rows: row r of every table is
# the same time. They are plain data frames because a candidate of
# the search copies the piece, and a write by reference into a
# table that the copies share would be seen by all of them.
# -------------------------------------------------------------
# Inputs
#   Main_df : Data table. The common and system columns.
#   assets  : Named list, one entry per asset, each with df, the
#             table of the asset (a data table).
#   rows    : Integer vector. The rows to take, rows of Main_df and
#             of the table of every asset alike.
# -------------------------------------------------------------
# Outputs
#   List with system and assets, as described above.
# -------------------------------------------------------------
# Code outline
# 1. Check the time and the shared columns of the tables
# 2. Build the table of the system
# 3. Build the table of each asset
# -------------------------------------------------------------
# Usage instructions
# piece <- build_market_piece(
#   Main_df = Main_df,
#   assets  = assets,
#   rows    = simulation_control$indexes_global$idx_period
# )
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - A table of an asset whose time differs from that of Main_df
#     on the rows stops the run.
#   - A column that Main_df and the table of an asset both hold, other
#     than time and the net electricity of the system, whose values on
#     the rows differ between the two stops the run.
#   - A column that Main_df and the table of an asset both hold, other
#     than time and the net electricity of the system, whose values on
#     the rows differ between the two stops the run.
# -------------------------------------------------------------

build_market_piece <- function(Main_df,
                               assets,
                               rows
                               ) {

  # -------------------------------------------------------------
  # 1. Check the time and the shared columns of the tables
  # The row r of the table of an asset is read as the row r of
  # Main_df, so both shall hold the same time on the rows taken.
  # A column that both hold, other than the net electricity of the
  # system, is an input that the asset holds a copy of, and the copy
  # shall equal Main_df on the rows taken: a model reads it from the
  # table of the asset, and the system reads it from Main_df.
  # -------------------------------------------------------------
  {
    # system_net_energy_columns is called to name the shared columns
    # that are not copies, which hold a sum in Main_df.
    net_columns <- system_net_energy_columns()

    for (CONT_001 in names(assets)) {
      if (!identical(as.numeric(assets[[CONT_001]]$df$time[rows]),
                     as.numeric(Main_df$time[rows]))) {
        stop("build_market_piece: the time of the table of ",
             CONT_001, " is not the time of Main_df on the rows taken")
      }

      shared_columns <- setdiff(
        intersect(names(Main_df), names(assets[[CONT_001]]$df)),
        c("time", net_columns)
      )
      for (CONT_002 in shared_columns) {
        if (!identical(Main_df[[CONT_002]][rows],
                       assets[[CONT_001]]$df[[CONT_002]][rows])) {
          stop("build_market_piece: the column ", CONT_002,
               " of the table of ", CONT_001, " is not the column of ",
               "Main_df on the rows taken")
        }
      }
      rm(list = "shared_columns")
    }
    rm(list = intersect(c("CONT_001", "CONT_002", "net_columns"), ls()))
  }

  # -------------------------------------------------------------
  # 2. Build the table of the system
  # Each column is the subset of the column of Main_df. The result
  # is a plain data frame with the row names 1 to the number of
  # rows.
  # -------------------------------------------------------------
  {
    system_columns        <- lapply(names(Main_df), function(CONT_002) {
      Main_df[[CONT_002]][rows]
    })
    names(system_columns) <- names(Main_df)
    system_df <- structure(system_columns,
                           row.names = .set_row_names(length(rows)),
                           class     = "data.frame")
    rm(list = "system_columns")
  }

  # -------------------------------------------------------------
  # 3. Build the table of each asset
  # The same construction over the table of each asset, in the
  # order of the asset registry.
  # -------------------------------------------------------------
  {
    asset_tables <- list()
    for (CONT_003 in names(assets)) {
      asset_df      <- assets[[CONT_003]]$df
      asset_columns <- lapply(names(asset_df), function(CONT_004) {
        asset_df[[CONT_004]][rows]
      })
      names(asset_columns) <- names(asset_df)
      asset_tables[[CONT_003]] <- list(
        df = structure(asset_columns,
                       row.names = .set_row_names(length(rows)),
                       class     = "data.frame")
      )
      rm(list = c("asset_df", "asset_columns"))
    }
    rm(list = "CONT_003")
  }

  return(list(system = system_df, assets = asset_tables))
}
