# -------------------------------------------------------------
# Function: add_to_table_cells.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Adds values to cells of an accumulator table, in place. The
# accumulator tables are the tables that the simulation loop adds the
# result of each market to:
#   - the twelve tables of market_commitments
#   - the market, decision and slot tables of economic_analysis
# The cells are read and written in the table itself, with set() of
# data.table, so no column is copied. A table of the loop has one row
# per market event or per market slot of the whole simulation, so
# copying a column at every addition, as an ordinary assignment does,
# would cost more the longer the simulation is.
# The values are added in the order they are given. When a cell
# receives several values, they are added to it one after the other,
# as a sequence of ordinary assignments would do, so the result is the
# same to the last bit.
# Because the table is changed in place, every object that holds the
# same table sees the change. The accumulator tables are built with
# columns of their own (prepare_commitments() and
# prepare_economic_analysis() copy them), so no other object shares
# their columns.
# -------------------------------------------------------------
# Inputs
# table   : Data frame. The accumulator table. Its columns must be
#           numeric (double).
# rows    : Integer vector. The row of each cell.
# columns : Character vector. The column of each cell.
# values  : Numeric vector. The value to add to each cell.
# rows, columns and values are recycled to the longest of them, so
# that, for example, one row and several columns give one cell per
# column.
# -------------------------------------------------------------
# Outputs
# The same table, invisibly, with the values added to its cells. The
# table passed in is changed too.
# -------------------------------------------------------------
# Code outline
# 1. One entry per cell, and the current value of each cell (with
#    no cell, the table is returned as it is)
# 2. The new value of each cell, adding its values in order
# 3. Write the new values, in place
# -------------------------------------------------------------
# Usage instructions
# add_to_table_cells(
#   table   = economic_analysis$slot,
#   rows    = slot_pos,
#   columns = "Cash_flow",
#   values  = cash_flow
# )
# -------------------------------------------------------------

add_to_table_cells <- function(table,
                               rows,
                               columns,
                               values
                               ) {

  # -------------------------------------------------------------
  # 1. One entry per cell, and the current value of each cell
  # .subset2() reads a column without the method of data frames.
  # -------------------------------------------------------------
  {
    n_cells <- max(length(rows), length(columns), length(values))
    rows    <- rep_len(rows, n_cells)
    columns <- rep_len(columns, n_cells)
    values  <- rep_len(values, n_cells)

    # With no cell, there is nothing to add.
    if (n_cells == 0) {
      return(invisible(table))
    }

    one_column <- all(columns == columns[1])
    if (one_column) {
      current <- .subset2(table, columns[1])[rows]
    } else {
      current <- vapply(seq_len(n_cells), function(CONT_001) {
        .subset2(table, columns[CONT_001])[rows[CONT_001]]
      }, numeric(1))
    }
  }

  # -------------------------------------------------------------
  # 2. The new value of each cell, adding its values in order
  # When no cell repeats, each new value is its current value plus
  # its own value. When a cell repeats, its values are added one
  # after the other, in the order given, on its first entry, and its
  # other entries are dropped.
  # -------------------------------------------------------------
  {
    if (one_column) {
      first_cell <- match(rows, rows)
    } else {
      first_cell <- match(paste(rows, columns, sep = "|"),
                          paste(rows, columns, sep = "|"))
    }

    if (all(first_cell == seq_len(n_cells))) {
      updated <- current + values
    } else {
      updated <- current
      for (CONT_002 in seq_len(n_cells)) {
        updated[first_cell[CONT_002]] <-
          updated[first_cell[CONT_002]] + values[CONT_002]
      }
      kept    <- first_cell == seq_len(n_cells)
      rows    <- rows[kept]
      columns <- columns[kept]
      updated <- updated[kept]
      rm(list = c("CONT_002", "kept"))
    }

    rm(list = c("first_cell", "current", "n_cells"))
  }

  # -------------------------------------------------------------
  # 3. Write the new values, in place
  # set() writes the cells without copying the columns. The cells of a
  # single column are written with one call; so are the cells of a
  # single row, one column each; otherwise each column is written
  # with one call.
  # -------------------------------------------------------------
  {
    if (one_column) {
      set(table,
          i     = rows,
          j     = columns[1],
          value = updated)
    } else if (all(rows == rows[1])) {
      set(table,
          i     = rows[1],
          j     = columns,
          value = as.list(updated))
    } else {
      for (CONT_003 in unique(columns)) {
        in_column <- columns == CONT_003
        set(table,
            i     = rows[in_column],
            j     = CONT_003,
            value = updated[in_column])
        rm(list = "in_column")
      }
      rm(list = "CONT_003")
    }
    rm(list = "one_column")
  }

  return(invisible(table))
}
