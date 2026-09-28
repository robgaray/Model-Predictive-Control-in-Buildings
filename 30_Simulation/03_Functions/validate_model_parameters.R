# -------------------------------------------------------------
# Function: validate_model_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function validates the ventilation-related model parameters
# loaded from 11_Model_parameters.csv. It checks that Efi_Vent_Rec,
# Volume, and inertial_fact parameters exist and fall within their
# expected ranges. Invalid or missing values either stop the
# simulation (errors) or are replaced with safe defaults (warnings).
# RENvent01/RENvent1/RENvent2 are NOT re-validated here: they are
# already covered by Parameter_config.csv's authoritative hard-stop
# range check ([0, 20], Error level) applied at load time via
# read_and_validate_parameter_csv.R.
# -------------------------------------------------------------
# Inputs
#   model_parameters : Named list. Model parameters as loaded from
#                      11_Model_parameters.csv via load_11_model_parameters.R.
#                      Expected ventilation-related entries:
#                        Efi_Vent_Rec - Heat recovery efficiency (0-1)
#                        Volume      - Building volume (m3), must be positive
#                        inertial_fact - Thermal inertia factor (0-1)
#   bounding_validation_config : Data frame. Content of
#                      Validation_bounding_simulation.csv, holding the
#                      plausibility bound below which the building
#                      volume is reported as unusually small.
# -------------------------------------------------------------
# Outputs
#   model_parameters : Named list. The input list with any missing
#                      Efi_Vent_Rec or inertial_fact entries added
#                      and set to 0 (after issuing a warning). Volume
#                      errors cause the simulation to stop.
# -------------------------------------------------------------
# Code outline
# 1. Validate Efi_Vent_Rec parameter
# 2. Validate Volume parameter
# 3. Validate inertial_fact parameter
# -------------------------------------------------------------
# Usage instructions
# model_parameters <- validate_model_parameters(model_parameters, bounding_validation_config)
# -------------------------------------------------------------
# Where this function/script is used
# Called by load_11_model_parameters.R after loading model_parameters.
# -------------------------------------------------------------
# functions/scripts called
#   get_validation_bounds()
# -------------------------------------------------------------

validate_model_parameters <- function(model_parameters, bounding_validation_config) {

  # -------------------------------------------------------------
  # 1. Validate Efi_Vent_Rec parameter
  # Must exist and be in [0, 1].
  # If missing: warning, set to 0.
  # If out of range: warning.
  # -------------------------------------------------------------
  {
    if (is.null(model_parameters$Efi_Vent_Rec) ||
        is.na(model_parameters$Efi_Vent_Rec)) {
      warning(paste(
        "Parameter Efi_Vent_Rec not found in model_parameters.",
        "Assigning value 0."
      ))
      model_parameters$Efi_Vent_Rec <- 0
    } else if (model_parameters$Efi_Vent_Rec < 0 ||
               model_parameters$Efi_Vent_Rec > 1) {
      warning(paste(
        "Parameter Efi_Vent_Rec is outside the valid range [0, 1]. Value:",
        model_parameters$Efi_Vent_Rec
      ))
    }
  }

  # -------------------------------------------------------------
  # 2. Validate Volume parameter
  # Must exist (error if not). Must be positive (error if not).
  # If value < 50: warning.
  # -------------------------------------------------------------
  {
    if (is.null(model_parameters$Volume) ||
        is.na(model_parameters$Volume)) {
      stop("Parameter Volume not found in model_parameters. Simulation stopped.")
    }

    if (model_parameters$Volume <= 0) {
      stop(paste(
        "Parameter Volume must be positive. Value:",
        model_parameters$Volume,
        ". Simulation stopped."
      ))
    }

    # get_validation_bounds is called to read the plausibility bound of
    # the building volume out of Validation_bounding_simulation.csv, so
    # that the volume below which a building is unusually small is
    # stated in configuration and not here.
    volume_bounds <- get_validation_bounds(
      bounding_validation_config, "11_Model_parameters.csv", "Volume"
    )

    if (!is.na(volume_bounds$min) &&
        model_parameters$Volume < volume_bounds$min) {
      warning(paste(
        "Parameter Volume is below", volume_bounds$min, "m3. Value:",
        model_parameters$Volume,
        ". Please verify the building volume."
      ))
    }

    rm(volume_bounds)
  }

  # -------------------------------------------------------------
  # 3. Validate inertial_fact parameter
  # Must be in [0, 1].
  # If missing: warning, set to 0.
  # If out of range: warning.
  # -------------------------------------------------------------
  {
    if (is.null(model_parameters$inertial_fact) ||
        is.na(model_parameters$inertial_fact)) {
      warning(paste(
        "Parameter inertial_fact not found in model_parameters.",
        "Assigning value 0."
      ))
      model_parameters$inertial_fact <- 0
    } else if (model_parameters$inertial_fact < 0 ||
               model_parameters$inertial_fact > 1) {
      warning(paste(
        "Parameter inertial_fact is outside the valid range [0, 1]. Value:",
        model_parameters$inertial_fact
      ))
    }
  }

  return(model_parameters)
}
