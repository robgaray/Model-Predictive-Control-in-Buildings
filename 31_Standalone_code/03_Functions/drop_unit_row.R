# -------------------------------------------------------------
# Function: drop_unit_row.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Removes the units row of a configuration table, read as a data
# frame. The configuration format puts the units row right after the
# header, so it is the first row of the data frame, whatever it
# holds: "text", a unit, or "-".
# A file written without its units row would lose its first data row
# here, so the row is checked first. It has to be told apart from a
# data row by the columns that hold data of a known kind:
#   - number_columns: a data row has a number in all of them, and a
#     units row has a unit in at least one;
#   - or reference_values: the values a data row may hold in
#     reference_columns, such as the day types a month refers to; a
#     units row holds something else in at least one of them.
# When the row looks like data, the run stops: the file breaks the
# format, and dropping the row would silently lose data.
# -------------------------------------------------------------
# Inputs
#   table             : Data frame. The table, as read.csv() returns it
#                       from the file, comment rows skipped.
#   file_name         : Character scalar. Name of the file, for the
#                       message.
#   number_columns    : Character vector. Columns that hold numbers in
#                       a data row. May be empty when reference_columns
#                       is given.
#   reference_columns : Character vector. Columns that hold one of
#                       reference_values in a data row. May be empty.
#   reference_values  : Character vector. The values allowed in
#                       reference_columns.
# -------------------------------------------------------------
# Outputs
#   The data frame without its first row.
# -------------------------------------------------------------
# Code outline
# 1. Check that the first row is a units row
# 2. Drop it
# -------------------------------------------------------------
# Usage instructions
# modes <- drop_unit_row(modes, "13_Modes_setpoints.csv",
#                        c("heating", "cooling"), character(0),
#                        character(0))
# -------------------------------------------------------------

drop_unit_row <- function(table, file_name, number_columns,
                          reference_columns, reference_values) {

  # 1. Check that the first row is a units row
  # -------------------------------------------------------------
  {
    if (nrow(table) == 0) {
      stop(file_name, " has no units row under its header")
    }

    first_numbers    <- trimws(as.character(unlist(table[1, number_columns])))
    first_references <- trimws(as.character(unlist(table[1, reference_columns])))

    holds_unit <-
      any(nzchar(first_numbers) & is.na(suppressWarnings(as.numeric(first_numbers)))) ||
      any(!first_references %in% trimws(reference_values))

    if (!holds_unit) {
      stop(file_name, ": the row right after the header must be the units ",
           "row, but it holds data (", paste(unlist(table[1, ]), collapse = ","),
           ")")
    }

    rm(list = c("first_numbers", "first_references", "holds_unit"))
  }

  # 2. Drop it
  # -------------------------------------------------------------
  {
    table <- table[-1, , drop = FALSE]
  }

  return(table)
}
