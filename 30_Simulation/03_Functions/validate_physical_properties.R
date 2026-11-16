# -------------------------------------------------------------
# Function: validate_physical_properties.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function validates the physical properties loaded from
# 03_Physical_properties.csv. Their presence and range, and those of
# the reference values of Validation_03_Physical_properties.csv, are
# already checked at Error level against the parameter catalogue by
# read_and_validate_parameter_csv(). What is left here:
#   - Cp_air and dens_air must be strictly positive: their ranges in
#     the parameter catalogue include 0.
#   - A warning is raised if their values differ from the reference
#     values held in Validation_03_Physical_properties.csv. The
#     reference values are read from that file rather than written
#     here, so the standard properties of air are stated once, where
#     the rest of the configuration is.
#   - The reference conditions of photovoltaic modules (the standard
#     test conditions and the conditions of the NOCT) and the solar
#     constant are checked only against their reference values: a
#     warning is raised if one differs, because a change of them
#     changes the meaning of the catalogue data of the modules or
#     the radiation the sun can give.
# -------------------------------------------------------------
# Inputs
#   physical_properties : Named list. Physical properties loaded
#                         from 03_Physical_properties.csv via
#                         load_03_physical_properties.R. Expected entries:
#                           Cp_air   - Specific heat of air (kJ/kg·K)
#                           dens_air - Density of air (kg/m3)
#                           PV_STC_irradiance
#                           PV_STC_cell_temperature
#                           PV_NOCT_irradiance
#                           PV_NOCT_ambient_temperature
#                           Solar_constant
#   reference_values    : Named list. Reference values loaded from
#                         Validation_03_Physical_properties.csv by
#                         load_03_physical_properties.R. Expected
#                         entries: Cp_air_ref, dens_air_ref, and the
#                         _ref value of each reference condition of
#                         the photovoltaic modules and of
#                         Solar_constant.
# -------------------------------------------------------------
# Outputs
#   Invisibly returns TRUE if all checks pass.
#   Raises an error (stop) if a parameter is non-positive. Issues a
#   warning if values differ from their reference values.
# -------------------------------------------------------------
# Code outline
# 1. Validate Cp_air
# 2. Validate dens_air
# 3. Compare the reference conditions of photovoltaic modules and
#    the solar constant
# -------------------------------------------------------------
# Usage instructions
# validate_physical_properties(physical_properties, reference_values)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - The comparison carries no tolerance. A configured value that
#     differs from its reference in any digit raises a warning, and
#     the simulation continues with the configured value.
# -------------------------------------------------------------

validate_physical_properties <- function(physical_properties, reference_values) {

  # -------------------------------------------------------------
  # 1. Validate Cp_air
  # Must be positive (error otherwise). Warning if it differs from
  # Cp_air_ref, the reference value of the validation file.
  # -------------------------------------------------------------
  {
    Cp_air_ref <- reference_values$Cp_air_ref

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
      ), call. = FALSE)
    }

    rm(list = "Cp_air_ref")
  }

  # -------------------------------------------------------------
  # 2. Validate dens_air
  # Must be positive (error otherwise). Warning if it differs from
  # dens_air_ref, the reference value of the validation file.
  # -------------------------------------------------------------
  {
    dens_air_ref <- reference_values$dens_air_ref

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
      ), call. = FALSE)
    }

    rm(list = "dens_air_ref")
  }

  # -------------------------------------------------------------
  # 3. Compare the reference conditions of photovoltaic modules and
  #    the solar constant
  # Warning if one differs from its reference value, the
  # corresponding _ref value of the validation file.
  # -------------------------------------------------------------
  {
    for (CONT_001 in c("PV_STC_irradiance", "PV_STC_cell_temperature",
                       "PV_NOCT_irradiance",
                       "PV_NOCT_ambient_temperature",
                       "Solar_constant")) {
      reference_value <- reference_values[[paste0(CONT_001, "_ref")]]

      if (physical_properties[[CONT_001]] != reference_value) {
        warning(paste(
          "Parameter", CONT_001, "differs from the reference value",
          reference_value, ". Current value:",
          physical_properties[[CONT_001]]
        ), call. = FALSE)
      }
    }

    rm(list = c("CONT_001", "reference_value"))
  }

  invisible(TRUE)
}
