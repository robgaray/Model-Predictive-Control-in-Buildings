# -------------------------------------------------------------
# Script: load_03_physical_properties.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads physical properties from 03_Physical_properties.csv,
# validates the values against the parameter catalogue, applies
# the domain-specific validate_physical_properties() check against
# the reference values of Validation_03_Physical_properties.csv,
# and stores the result in parameters$physical_properties.
# Sourced from load_all_parameters().
# -------------------------------------------------------------
# Inputs
#   paths$physical_properties_file : path of 03_Physical_properties.csv,
#     resolved by initialize_simulator().
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
#   Not called: sourced by load_all_parameters(), which supplies
#   paths and parameters and takes the updated parameters back.
# -------------------------------------------------------------

{
  # load_parameter_file is called to read 03_Physical_properties.csv,
  # check every value against the parameter catalogue and return each
  # one as a number.
  parameters$physical_properties <- load_parameter_file(
    paths$physical_properties_file,
    validation_config
  )

  # load_parameter_file is called a second time to read the reference
  # values of Validation_03_Physical_properties.csv, which are the
  # contrast values the check below compares against.
  reference_values <- load_parameter_file(
    paths$physical_properties_validation_file,
    validation_config
  )

  # validate_physical_properties is called to apply the
  # domain-specific consistency checks that go beyond the generic
  # type/range validation already performed above.
  validate_physical_properties(parameters$physical_properties, reference_values)
  rm(list = "reference_values")
}
