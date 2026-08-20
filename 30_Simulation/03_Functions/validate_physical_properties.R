# -------------------------------------------------------------
# Function: validate_physical_properties.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function validates the physical properties loaded from
# 03_Physical_properties.csv. It checks that Cp_air and dens_air
# exist and are positive (error otherwise), and warns if their
# values differ from the standard reference values.
# -------------------------------------------------------------
# Inputs
#   physical_properties : Named list. Physical properties loaded
#                         from 03_Physical_properties.csv via
#                         load_03_physical_properties.R. Expected entries:
#                           Cp_air   - Specific heat of air (kJ/kg·K)
#                                      Reference value: 1.005
#                           dens_air - Density of air (kg/m3)
#                                      Reference value: 1.204
# -------------------------------------------------------------
# Outputs
#   Invisibly returns TRUE if all checks pass.
#   Raises an error (stop) if any required parameter is missing
#   or non-positive. Issues a warning if values differ from
#   the standard reference values.
# -------------------------------------------------------------
# Code outline
# 1. Validate Cp_air
# 2. Validate dens_air
# -------------------------------------------------------------
# Usage instructions
# validate_physical_properties(physical_properties)
# -------------------------------------------------------------
# Where this function/script is used
# Called by load_03_physical_properties.R after loading physical_properties.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

validate_physical_properties <- function(physical_properties) {

  # -------------------------------------------------------------
  # 1. Validate Cp_air
  # Must exist and be positive (error otherwise).
  # Reference value: 1.005 kJ/(kg·K). Warning if different.
  # -------------------------------------------------------------
  {
    Cp_air_ref <- 1.005

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
  # Must exist and be positive (error otherwise).
  # Reference value: 1.204 kg/m3. Warning if different.
  # -------------------------------------------------------------
  {
    dens_air_ref <- 1.204

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
