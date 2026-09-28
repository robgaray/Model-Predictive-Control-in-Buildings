# -------------------------------------------------------------
# Function: validate_physical_properties.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function validates the physical properties loaded from
# 03_Physical_properties.csv. It checks that Cp_air and dens_air
# exist and are positive (error otherwise), and warns if their
# values differ from the reference values held in
# Validation_03_Physical_properties.csv. The reference values are
# read from that file rather than written here, so the standard
# properties of air are stated once, where the rest of the
# configuration is.
# -------------------------------------------------------------
# Inputs
#   physical_properties : Named list. Physical properties loaded
#                         from 03_Physical_properties.csv via
#                         load_03_physical_properties.R. Expected entries:
#                           Cp_air   - Specific heat of air (kJ/kg·K)
#                           dens_air - Density of air (kg/m3)
#   reference_values    : Named list. Reference values loaded from
#                         Validation_03_Physical_properties.csv by
#                         load_03_physical_properties.R. Expected
#                         entries: Cp_air_ref, dens_air_ref.
# -------------------------------------------------------------
# Outputs
#   Invisibly returns TRUE if all checks pass.
#   Raises an error (stop) if any required parameter or reference
#   value is missing, or if a parameter is non-positive. Issues a
#   warning if values differ from their reference values.
# -------------------------------------------------------------
# Code outline
# 1. Validate Cp_air
# 2. Validate dens_air
# -------------------------------------------------------------
# Usage instructions
# validate_physical_properties(physical_properties, reference_values)
# -------------------------------------------------------------
# Where this function/script is used
# Called by load_03_physical_properties.R after loading physical_properties.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - A reference value missing from
#     Validation_03_Physical_properties.csv stops execution: the
#     comparison this function exists for could not be made, and
#     silently skipping it would hide that the file is incomplete.
#   - The comparison carries no tolerance. A configured value that
#     differs from its reference in any digit raises a warning, and
#     the simulation continues with the configured value.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

validate_physical_properties <- function(physical_properties, reference_values) {

  # -------------------------------------------------------------
  # 1. Validate Cp_air
  # Must exist and be positive (error otherwise). Warning if it
  # differs from Cp_air_ref, the reference value of the validation file.
  # -------------------------------------------------------------
  {
    Cp_air_ref <- reference_values$Cp_air_ref

    if (is.null(Cp_air_ref) || is.na(Cp_air_ref)) {
      stop(paste(
        "Reference value Cp_air_ref not found in",
        "Validation_03_Physical_properties.csv. Simulation stopped."
      ))
    }

    if (is.null(physical_properties$Cp_air) ||
        is.na(physical_properties$Cp_air)) {
      stop(paste(
        "Parameter Cp_air not found in physical_properties.",
        "Simulation stopped."
      ))
    }

    if (physical_properties$Cp_air <= 0) {
      stop(paste(
        "Parameter Cp_air must be positive. Value:",
        physical_properties$Cp_air,
        ". Simulation stopped."
      ))
    }

    if (physical_properties$Cp_air != Cp_air_ref) {
      warning(paste(
        "Parameter Cp_air differs from the reference value", Cp_air_ref,
        ". Current value:", physical_properties$Cp_air
      ))
    }

    rm(Cp_air_ref)
  }

  # -------------------------------------------------------------
  # 2. Validate dens_air
  # Must exist and be positive (error otherwise). Warning if it differs
  # from dens_air_ref, the reference value of the validation file.
  # -------------------------------------------------------------
  {
    dens_air_ref <- reference_values$dens_air_ref

    if (is.null(dens_air_ref) || is.na(dens_air_ref)) {
      stop(paste(
        "Reference value dens_air_ref not found in",
        "Validation_03_Physical_properties.csv. Simulation stopped."
      ))
    }

    if (is.null(physical_properties$dens_air) ||
        is.na(physical_properties$dens_air)) {
      stop(paste(
        "Parameter dens_air not found in physical_properties.",
        "Simulation stopped."
      ))
    }

    if (physical_properties$dens_air <= 0) {
      stop(paste(
        "Parameter dens_air must be positive. Value:",
        physical_properties$dens_air,
        ". Simulation stopped."
      ))
    }

    if (physical_properties$dens_air != dens_air_ref) {
      warning(paste(
        "Parameter dens_air differs from the reference value", dens_air_ref,
        ". Current value:", physical_properties$dens_air
      ))
    }

    rm(dens_air_ref)
  }

  invisible(TRUE)
}
