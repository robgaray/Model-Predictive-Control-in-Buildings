# -------------------------------------------------------------
# Function: sum_asset_energy.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the net electricity of the system on some rows, for one or
# more itineraries: the sum over the assets of the column of each
# itinerary in the table of each asset. The table of the system holds this
# sum in the column of the same name (system_net_energy_column()), and it is
# written from here every time the energy of an asset changes. With a
# single asset the sum is that asset's column itself: no value is
# added to it, so it is the same number.
# Its internal objects are removed with rm(list = ), which does not
# call match.call() as rm() with names does: this function runs
# several times for every candidate of the genetic algorithm.
# -------------------------------------------------------------
# Inputs
#   assets : Named list, one entry per asset, each with df, the table
#            of the asset.
#   columns : Character vector. One or more columns of the net
#             electricity of an itinerary, as
#             system_net_energy_column() names them.
#   rows   : Integer vector. The rows to sum, rows of every table of
#            an asset alike.
# -------------------------------------------------------------
# Outputs
#   Named list, one numeric vector per column of columns, with one
#   value per element of rows: the net electricity of the system on
#   each row, in kWh.
# -------------------------------------------------------------
# Code outline
# 1. Check the columns in every table
# 2. Add the columns of every asset
# -------------------------------------------------------------
# Usage instructions
# net <- sum_asset_energy(assets, c("Elec_total_plan"), rows)[[1]]
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - A table of an asset without one of the columns stops the run.
# -------------------------------------------------------------

sum_asset_energy <- function(assets,
                             columns,
                             rows
                             ) {

  # -------------------------------------------------------------
  # 1. Check the columns in every table
  # The first column, in the order of columns, that a table lacks
  # stops the run, with every asset that lacks it.
  # -------------------------------------------------------------
  {
    held <- vapply(assets, function(CONT_001) {
      all(columns %in% names(CONT_001$df))
    }, logical(1))
    if (!all(held)) {
      for (CONT_002 in columns) {
        lacking <- names(assets)[!vapply(assets, function(CONT_003) {
          CONT_002 %in% names(CONT_003$df)
        }, logical(1))]
        if (length(lacking) > 0) {
          stop("sum_asset_energy: the column ", CONT_002, " is missing in ",
               "the table of ", paste(lacking, collapse = ", "))
        }
      }
    }
    rm(list = "held")
  }

  # -------------------------------------------------------------
  # 2. Add the columns of every asset
  # In the order of the registry: ((a1 + a2) + a3) ..., so the sum
  # is the same number wherever it is made. With a single asset the
  # sum is the column of that asset itself.
  # -------------------------------------------------------------
  {
    net_energy        <- vector("list", length(columns))
    names(net_energy) <- columns
    for (CONT_004 in names(assets)) {
      asset_df <- assets[[CONT_004]]$df
      for (CONT_005 in columns) {
        if (is.null(net_energy[[CONT_005]])) {
          net_energy[[CONT_005]] <- .subset2(asset_df, CONT_005)[rows]
        } else {
          net_energy[[CONT_005]] <- net_energy[[CONT_005]] +
            .subset2(asset_df, CONT_005)[rows]
        }
      }
    }
    rm(list = c("CONT_004", "CONT_005", "asset_df"))
  }

  return(net_energy)
}
