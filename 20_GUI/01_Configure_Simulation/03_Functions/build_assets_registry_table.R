# -------------------------------------------------------------
# Function: build_assets_registry_table.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the read-only list of the assets of the registry that the
# Assets tab shows: one row per asset, with its id, its type and its
# status. The list is managed by the app (the user changes it with
# the number of assets of each type), so it has no input widgets.
# The rows that come from the default registry, because the file
# of the registry held no valid asset, are painted in red until the
# registry is saved.
# -------------------------------------------------------------
# Inputs
#   registry_df    : Data frame (asset_id, asset_type). The registry
#                    as it is now, in its order.
#   status         : Named character vector. The status of each
#                    asset, named by its asset id.
#   defaulted_rows : Integer vector. The rows of registry_df that
#                    come from the default registry.
#   file_label     : Character. The name of the registry file, which
#                    the catalogue uses to give the units of its
#                    columns.
# -------------------------------------------------------------
# Outputs
#   A Shiny tag, the table, ready to be returned by renderUI().
# -------------------------------------------------------------
# Code outline
# 1. Build the header with the units of the columns.
# 2. Build one row for each asset.
# 3. Join them in the table.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   build_assets_registry_table(registry_df, status, defaulted_rows,
#                               file_label)
# -------------------------------------------------------------

build_assets_registry_table <- function(registry_df, status, defaulted_rows,
                                        file_label) {

  # -------------------------------------------------------------
  # 1. Build the header with the units of the columns
  # -------------------------------------------------------------
  {
    header <- tags$tr(
      # label_with_unit is called to write each column with its unit
      # in square brackets, from the catalogue.
      tags$th(label_with_unit("asset_id", file_label)),
      tags$th(label_with_unit("asset_type", file_label)),
      tags$th("status")
    )
  }

  # -------------------------------------------------------------
  # 2. Build one row for each asset
  # -------------------------------------------------------------
  {
    rows <- lapply(
      seq_len(nrow(registry_df)),
      function(CONT_001) {
        row_style <- if (CONT_001 %in% defaulted_rows) "color:#c0392b;" else NULL
        tags$tr(
          style = row_style,
          tags$td(registry_df$asset_id[CONT_001]),
          tags$td(registry_df$asset_type[CONT_001]),
          tags$td(unname(status[registry_df$asset_id[CONT_001]]))
        )
      }
    )
  }

  # -------------------------------------------------------------
  # 3. Join them in the table
  # -------------------------------------------------------------
  {
    registry_table <- tags$table(
      class = "table table-condensed",
      style = "width:auto;",
      tags$thead(header),
      do.call(tags$tbody, rows)
    )
    rm(header, rows)
  }

  return(registry_table)
}
