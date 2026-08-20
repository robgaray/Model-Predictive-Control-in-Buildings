# -------------------------------------------------------------
# Script: load_11_model_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads model parameters from 11_Model_parameters.csv,
# validates them against Parameter_config.csv, applies the
# domain-specific validate_model_parameters() check, computes
# Rvent parameters via compute_Rvent(), and stores the result
# in parameters$model.
# Sourced from load_all_parameters.R.
# Requires parameters$physical_properties to be already loaded.
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 11_Model_parameters.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$model_file, "11_Model_parameters.csv", validation_config
  )

  model_params_raw <- lapply(raw_values, as.numeric)
  rm(raw_values)

  # validate_model_parameters is called to apply the domain-specific
  # consistency checks that go beyond the generic type/range
  # validation already performed above.
  model_params_raw <- validate_model_parameters(model_params_raw)
  # compute_Rvent is called to derive the ventilation resistance
  # parameters from the raw model parameters and the already-loaded
  # physical properties, before the model list is stored.
  model_params_raw <- compute_Rvent(model_params_raw, parameters$physical_properties)

  parameters$model <- model_params_raw
  rm(model_params_raw)

  cat("Model parameters loaded\n")
}
