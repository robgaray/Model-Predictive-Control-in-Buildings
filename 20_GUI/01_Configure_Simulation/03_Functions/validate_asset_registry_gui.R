# -------------------------------------------------------------
# Function: validate_asset_registry_gui.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Validates the asset registry before it is saved. Each value is
# checked against its rule of the catalogue. Each id must be a type,
# an underscore and three digits, must start with its own type, and
# must not be repeated. The registry holds at least one asset.
# -------------------------------------------------------------
# Inputs
#   registry          : Data frame (asset_id, asset_type). The rows
#                       of the registry, without a units row.
#   file_name         : Character. Name of the registry file, as the
#                       catalogue names it.
#   validation_config : List. The catalogue.
# -------------------------------------------------------------
# Outputs
#   Character vector of messages, empty when the registry is valid.
# -------------------------------------------------------------
# Code outline
# 1. Check that the registry holds an asset.
# 2. Check each row.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   validate_asset_registry_gui(registry, file_name, validation_config)
# -------------------------------------------------------------

validate_asset_registry_gui <- function(registry, file_name,
                                        validation_config) {

  messages <- character(0)

  # -------------------------------------------------------------
  # 1. Check that the registry holds an asset
  # -------------------------------------------------------------
  {
    if (nrow(registry) == 0) {
      messages <- c(messages, sprintf(
        "%s: the registry must hold at least one asset.", file_name
      ))
    }
  }

  # -------------------------------------------------------------
  # 2. Check each row
  # -------------------------------------------------------------
  {
    for (CONT_001 in seq_len(nrow(registry))) {
      row_id   <- registry$asset_id[CONT_001]
      row_type <- registry$asset_type[CONT_001]

      # check_param_valid is called for each value to check it
      # against its rule of the catalogue.
      values_ok <- check_param_valid(
        value             = row_id,
        file_name         = file_name,
        param_name        = "asset_id",
        validation_config = validation_config
      ) && check_param_valid(
        value             = row_type,
        file_name         = file_name,
        param_name        = "asset_type",
        validation_config = validation_config
      )
      format_ok <- values_ok && grepl("^[A-Za-z]+_[0-9]{3}$", row_id) &&
        sub("_[0-9]+$", "", row_id) == row_type

      if (!format_ok) {
        messages <- c(messages, sprintf(
          "%s: the asset '%s' of type '%s' is not valid.",
          file_name, row_id, row_type
        ))
      } else if (row_id %in% registry$asset_id[seq_len(CONT_001 - 1)]) {
        messages <- c(messages, sprintf(
          "%s: the asset id '%s' is repeated.", file_name, row_id
        ))
      }
      rm(row_id, row_type, values_ok, format_ok)
    }
  }

  return(messages)
}
