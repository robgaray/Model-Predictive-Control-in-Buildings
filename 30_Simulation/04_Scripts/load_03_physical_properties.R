# -------------------------------------------------------------
# Script: load_03_physical_properties.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads physical properties from 03_Physical_properties.csv,
# validates the values against Parameter_config.csv, applies
# the domain-specific validate_physical_properties() check against
# the reference values of Validation_03_Physical_properties.csv,
# and stores the result in parameters$physical_properties.
# Sourced from 02_load_all_parameters.R.
# -------------------------------------------------------------
# Inputs
#   paths$physical_properties_file : path of 03_Physical_properties.csv, resolved by
#     01_initialization.R.
#   Its validation table, Validation_03_Physical_properties.csv,
#     read alongside it.
#   parameters : the list being assembled, to which this script
#     adds one sub-list.
# -------------------------------------------------------------
# Outputs
#   parameters$physical_properties, populated. Nothing else is
#     modified.
# -------------------------------------------------------------
# Code outline
# 1. Read the file and validate every value.
# 2. Check the properties against their physical ranges.
# 3. Store the result in parameters$physical_properties.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by 02_load_all_parameters.R, which supplies
#   paths and parameters and takes the updated parameters back.
# -------------------------------------------------------------
# Where this function/script is used
# Sourced by 02_load_all_parameters.R.
# -------------------------------------------------------------
# functions/scripts called
#   read_and_validate_parameter_csv() - reads a configuration
#                                       file and validates
#                                       every value
#   validate_physical_properties() - checks the physical
#                                    properties against their
#                                    ranges
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

  # read_and_validate_parameter_csv is called a second time to read
  # the reference values of Validation_03_Physical_properties.csv,
  # which are the contrast values the check below compares against.
  reference_values <- read_and_validate_parameter_csv(
    paths$physical_properties_validation_file,
    "Validation_03_Physical_properties.csv",
    validation_config
  )
  reference_values <- lapply(reference_values, as.numeric)

  # validate_physical_properties is called to apply the
  # domain-specific consistency checks that go beyond the generic
  # type/range validation already performed above.
  validate_physical_properties(parameters$physical_properties, reference_values)
  rm(reference_values)

  cat("Physical properties loaded\n")
}
