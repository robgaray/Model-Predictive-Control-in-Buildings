# -------------------------------------------------------------
# Function: piece_rows.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Cuts a piece of a market by rows: every table of the piece, the
# table of the system and the table of each asset, keeps the same
# rows. The cut is made with the indexing of a data frame, so the
# row names are the ones that cutting a single joined table by the
# same rows gives (for example the rows i_begin_horizon to
# i_end_horizon of the period).
# It keeps the layout of the piece, if any: the columns do not
# change.
# The structure of the piece is described in build_market_piece().
# -------------------------------------------------------------
# Inputs
#   piece : List. The piece of a market, as build_market_piece()
#           returns it.
#   rows  : Integer vector. The rows to keep, rows of every table of
#           the piece alike.
# -------------------------------------------------------------
# Outputs
#   List. The piece with the rows asked.
# -------------------------------------------------------------
# Code outline
# 1. Cut the table of the system
# 2. Cut the table of each asset
# -------------------------------------------------------------
# Usage instructions
# optimization_piece <- piece_rows(piece, i_begin:i_end)
# -------------------------------------------------------------

piece_rows <- function(piece,
                       rows
                       ) {

  # -------------------------------------------------------------
  # 1. Cut the table of the system
  # -------------------------------------------------------------
  {
    piece$system <- piece$system[rows, , drop = FALSE]
  }

  # -------------------------------------------------------------
  # 2. Cut the table of each asset
  # -------------------------------------------------------------
  {
    for (CONT_001 in names(piece$assets)) {
      piece$assets[[CONT_001]]$df <-
        piece$assets[[CONT_001]]$df[rows, , drop = FALSE]
    }
    rm(list = "CONT_001")
  }

  return(piece)
}
