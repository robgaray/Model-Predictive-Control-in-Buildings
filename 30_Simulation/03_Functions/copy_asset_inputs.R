# -------------------------------------------------------------
# Function: copy_asset_inputs.R
# Part of the Model Predictive Control in buildings repository
# <https://github.com/robgaray/Model-Predictive-Control-in-Buildings>
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Copies into the table of each asset the columns of Main_df that
# the type of the asset declares as inputs (stage input in
# 02_Needed_cols.csv, parameters$asset_input_cols). The table of an
# asset holds its inputs during the whole run, with the same values
# as Main_df on every row, so the models read their inputs from
# their own table.
# There are two ways to copy:
#   - the whole column (rows = NULL): the column is created in the
#     table of the asset as a real copy, never as the same vector
#     that Main_df holds, so a later write into one table can never
#     reach the other. The tables are still data frames;
#   - some rows (rows given): the values of those rows are written
#     into the columns the tables already hold, by reference. The
#     tables are data tables.
# A type with no inputs takes nothing from any copy, and the
# function then changes no table.
# -------------------------------------------------------------
# Inputs
#   Main_df    : Data frame or data table. The table the inputs are
#                taken from.
#   assets     : Named list, one entry per asset, each with df, the
#                table of the asset.
#   parameters : List. It holds the type of each asset
#                (parameters$assets[[asset_id]]$asset_type) and the
#                inputs of each type (parameters$asset_input_cols).
#   rows       : Integer vector, or NULL. The rows to copy, or NULL
#                for the whole column.
#   columns    : Character vector. The columns to copy. Each asset
#                takes those of them that its type declares as
#                inputs.
# -------------------------------------------------------------
# Outputs
#   The list assets, with the copied columns in the table of each
#   asset. With rows given the tables are written by reference too.
# -------------------------------------------------------------
# Code outline
# 1. Copy the inputs into the table of each asset
# -------------------------------------------------------------
# Usage instructions
# assets <- copy_asset_inputs(
#   Main_df    = Main_df,
#   assets     = assets,
#   parameters = parameters,
#   rows       = NULL,
#   columns    = unique(unlist(parameters$asset_input_cols))
# )
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - An input that Main_df does not hold, or, with rows given, that
#     the table of the asset does not hold, stops the run.
# -------------------------------------------------------------

copy_asset_inputs <- function(Main_df,
                              assets,
                              parameters,
                              rows,
                              columns
                              ) {

  # -------------------------------------------------------------
  # 1. Copy the inputs into the table of each asset
  # For each asset, the inputs of its type that are among the
  # columns asked for.
  # -------------------------------------------------------------
  {
    for (CONT_001 in names(assets)) {
      asset_type  <- parameters$assets[[CONT_001]]$asset_type
      input_names <- intersect(columns,
                               parameters$asset_input_cols[[asset_type]])

      for (CONT_002 in input_names) {
        if (!CONT_002 %in% names(Main_df)) {
          stop("copy_asset_inputs: the input ", CONT_002, " of ",
               CONT_001, " is not a column of Main_df")
        }

        if (is.null(rows)) {
          assets[[CONT_001]]$df[[CONT_002]] <-
            data.table::copy(Main_df[[CONT_002]])
        } else {
          if (!CONT_002 %in% names(assets[[CONT_001]]$df)) {
            stop("copy_asset_inputs: the table of ", CONT_001,
                 " has no column ", CONT_002)
          }
          data.table::set(
            assets[[CONT_001]]$df,
            i     = rows,
            j     = CONT_002,
            value = Main_df[[CONT_002]][rows]
          )
        }
      }
      rm(list = c("asset_type", "input_names"))
    }
    rm(list = intersect(c("CONT_001", "CONT_002"), ls()))
  }

  return(assets)
}
