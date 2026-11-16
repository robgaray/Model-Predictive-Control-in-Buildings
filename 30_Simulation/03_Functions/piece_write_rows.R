# -------------------------------------------------------------
# Function: piece_write_rows.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Writes some columns of a piece of a market into another piece,
# table by table: the rows source_rows of source go to the rows
# rows of piece. A column that the table of an asset holds is
# written in the table of each asset that holds it. When it is the
# net electricity of the system in an itinerary
# (system_net_energy_columns()) and the table of the system holds
# it too, it is written again as the sum over the assets
# (sum_asset_energy()). Any other column is a column of the system:
# it is written in the table of the system, and created there first
# when it does not exist yet.
# The structure of the piece is described in build_market_piece().
# -------------------------------------------------------------
# Inputs
#   piece       : List. The piece written.
#   rows        : Integer vector. The rows of piece to write.
#   source      : List. The piece read.
#   source_rows : Integer vector. The rows of source to read, as
#                 many as rows.
#   columns     : Character vector. The columns to write.
# -------------------------------------------------------------
# Outputs
#   List. The piece with the columns written.
# -------------------------------------------------------------
# Code outline
# 1. Write each column in the table that holds it
# -------------------------------------------------------------
# Usage instructions
# piece <- piece_write_rows(
#   piece       = piece,
#   rows        = idx_ctrl,
#   source      = optimization_piece,
#   source_rows = idx_inject,
#   columns     = inject_cols
# )
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - A column that no table of the source holds stops the run.
# -------------------------------------------------------------

piece_write_rows <- function(piece,
                             rows,
                             source,
                             source_rows,
                             columns
                             ) {

  # -------------------------------------------------------------
  # 1. Write each column in the table that holds it
  # -------------------------------------------------------------
  {
    # system_net_energy_columns is called to name the columns of the
    # net electricity, the only ones summed over the assets.
    net_energy_columns <- system_net_energy_columns()
    for (CONT_001 in columns) {
      held_by <- Filter(function(CONT_002) {
        CONT_001 %in% names(piece$assets[[CONT_002]]$df)
      }, names(piece$assets))

      if (length(held_by) > 0) {
        for (CONT_003 in held_by) {
          piece$assets[[CONT_003]]$df[[CONT_001]][rows] <-
            source$assets[[CONT_003]]$df[[CONT_001]][source_rows]
        }
        if (CONT_001 %in% names(piece$system) &&
            CONT_001 %in% net_energy_columns) {
          # sum_asset_energy is called to write the net electricity
          # of the system as the sum of that of the assets.
          piece$system[[CONT_001]][rows] <- sum_asset_energy(
            assets  = piece$assets,
            columns = CONT_001,
            rows    = rows
          )[[1]]
        }
      } else {
        if (!(CONT_001 %in% names(source$system))) {
          stop("piece_write_rows: no table of the source holds the ",
               "column ", CONT_001)
        }
        if (!(CONT_001 %in% names(piece$system))) {
          piece$system[[CONT_001]] <-
            source$system[[CONT_001]][rep(NA_integer_, nrow(piece$system))]
        }
        piece$system[[CONT_001]][rows] <-
          source$system[[CONT_001]][source_rows]
      }
      rm(list = "held_by")
    }
    rm(list = intersect(c("CONT_001", "CONT_003", "net_energy_columns"),
                        ls()))
  }

  return(piece)
}
