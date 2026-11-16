# -------------------------------------------------------------
# Script: load_11_model_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads model parameters from 11_Model_parameters.csv,
# validates them against the parameter catalogue, applies the
# domain-specific validate_model_parameters() check, computes
# Rvent parameters via compute_Rvent(), and stores the result
# in parameters$model.
# Sourced from load_building_parameters(), which supplies the paths
# of the asset.
# Requires parameters$physical_properties to be already loaded.
# -------------------------------------------------------------
# Inputs
#   paths$model_file : path of
#     11_Model_parameters.csv, in the configuration
#     folder of the asset, as build_asset_paths() gives it.
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$model, populated. Nothing else is
#     modified.
#   load_building_parameters() gathers the group into the groups of
#   the building.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value against the parameter
#    catalogue.
# 2. Check the building volume (validate_model_parameters()).
# 3. Resolve the ventilation resistance of each regime.
# 4. Store the result in parameters$model.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by load_building_parameters(), which
#   supplies paths, the paths of the asset, and parameters, and
#   takes the updated parameters back.
# -------------------------------------------------------------

{
  # load_parameter_file is called to read 11_Model_parameters.csv,
  # check every value against the parameter catalogue and return each
  # one as a number.
  model_params_raw <- load_parameter_file(
    paths$model_file,
    validation_config
  )

  # validate_model_parameters is called to apply the domain-specific
  # consistency checks that go beyond the generic type/range
  # validation already performed above.
  model_params_raw <- validate_model_parameters(
    model_parameters           = model_params_raw,
    bounding_validation_config = bounding_validation_config,
    model_file_name            = basename(paths$model_file)
  )
  # compute_Rvent is called to derive the ventilation resistance
  # parameters from the raw model parameters and the already-loaded
  # physical properties, before the model list is stored.
  model_params_raw <- compute_Rvent(model_params_raw, parameters$physical_properties)

  parameters$model <- model_params_raw
  rm(list = "model_params_raw")
}
