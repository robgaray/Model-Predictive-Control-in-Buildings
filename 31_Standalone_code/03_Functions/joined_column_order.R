# -------------------------------------------------------------
# Function: joined_column_order.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the order of the columns of a table that joins the table of
# the system and the table of an asset. Every column appears once:
# first those of column_order, in its order, and then the others, in
# the order of the columns of the system followed by those of the
# asset. It keeps the rule of the order in one place, for every
# function that builds a joined table.
# -------------------------------------------------------------
# Inputs
#   system_columns : Character vector. The columns of the system.
#   asset_columns  : Character vector. The columns of the asset,
#                    without the key time.
#   column_order   : Character vector. The preferred order of the
#                    columns (parameters$joined_cols). A column not
#                    in it goes after those that are.
# -------------------------------------------------------------
# Outputs
#   Character vector. The columns of both tables, each once, in the
#   order of the joined table.
# -------------------------------------------------------------
# Code outline
# 1. Order the columns
# -------------------------------------------------------------
# Usage instructions
# ordered <- joined_column_order(
#   system_columns = names(piece$system),
#   asset_columns  = asset_columns,
#   column_order   = parameters$joined_cols
# )
# -------------------------------------------------------------

joined_column_order <- function(system_columns,
                                asset_columns,
                                column_order
                                ) {

  # -------------------------------------------------------------
  # 1. Order the columns
  # -------------------------------------------------------------
  {
    all_columns <- union(system_columns, asset_columns)
    ordered     <- c(intersect(column_order, all_columns),
                     setdiff(all_columns, column_order))
    rm(list = "all_columns")
  }

  return(ordered)
}
