# -------------------------------------------------------------
# Script: load_03_physical_properties.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads physical properties from 03_Physical_properties.csv,
# validates the values against Parameter_config.csv, applies
# the domain-specific validate_physical_properties() check,
# and stores the result in parameters$physical_properties.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 03_Physical_properties.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$physical_properties_file, "03_Physical_properties.csv", validation_config
  )

  parameters$physical_properties <- lapply(raw_values, as.numeric)
  rm(raw_values)

  # validate_physical_properties is called to apply the
  # domain-specific consistency checks that go beyond the generic
  # type/range validation already performed above.
  validate_physical_properties(parameters$physical_properties)

  cat("Physical properties loaded\n")
}
