# -------------------------------------------------------------
# Function: build_column_lists.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Reads the variable registries of the system and of the types of
# model of the assets, and gives the two lists of columns that the
# functions of the market process read from parameters:
#   - joined_cols: the order of the columns of the view of an asset
#     (piece_asset_view()). It holds every column of the registry of
#     the system and of the registry of each type, each once: first
#     those of the system, then those of each type in the order of
#     the types.
#   - itinerary_variables: for each type of model, the variables of
#     its registry that are expanded into the three itineraries
#     (scenario "yes"), in registry order. itinerary_columns() builds
#     the columns of an itinerary from them.
# The columns of every registry are those variable_registry_columns()
# gives, so the registries are the only files that declare them. The
# registry of a type is the one the operation variable_registry of
# its contract names.
# -------------------------------------------------------------
# Inputs
#   paths       : Named list. The paths of the system files, as
#                 build_config_paths() returns them. Uses
#                 system_variables_file and the registry file of each
#                 type.
#   asset_types : Character vector. The types of model of the assets
#                 of the asset registry, each once.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     - joined              : Character vector. The columns of the
#                             view of an asset, in order.
#     - itinerary_variables : Named list, one element per type, each
#                             a character vector of variables.
# -------------------------------------------------------------
# Code outline
# 1. Columns of the system
# 2. Columns of each type of model
# -------------------------------------------------------------
# Usage instructions
# column_lists <- build_column_lists(paths, c("Building", "Photovoltaic"))
# -------------------------------------------------------------

build_column_lists <- function(paths,
                               asset_types
                               ) {

  # -------------------------------------------------------------
  # 1. Columns of the system
  # -------------------------------------------------------------
  {
    # variable_registry_columns is called to expand the registry of
    # the system into its columns.
    system_columns <- variable_registry_columns(paths$system_variables_file)
    joined         <- system_columns$column

    rm(list = "system_columns")
  }

  # -------------------------------------------------------------
  # 2. Columns of each type of model
  # -------------------------------------------------------------
  {
    itinerary_variables <- list()

    for (CONT_001 in asset_types) {
      # model_type_contract is called to take the operations of the
      # type of model, one of which names its variable registry.
      model <- model_type_contract(CONT_001)

      # variable_registry_columns is called to expand the registry of
      # the type into its columns.
      type_columns <- variable_registry_columns(model$variable_registry(paths))

      joined                           <- union(joined, type_columns$column)
      itinerary_variables[[CONT_001]] <- unique(
        type_columns$variable[type_columns$scenario == "yes"]
      )
      rm(list = c("model", "type_columns"))
    }
    rm(list = "CONT_001")
  }

  return(list(
    joined              = joined,
    itinerary_variables = itinerary_variables
  ))
}
