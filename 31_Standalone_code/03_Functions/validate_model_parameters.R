# -------------------------------------------------------------
# Function: validate_model_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function checks the building volume loaded from
# 11_Model_parameters.csv beyond what a range can say. The presence
# and range of every model parameter (Volume, Efi_Vent_Rec,
# inertial_fact, RENvent01/RENvent1/RENvent2 and the rest) are already
# checked at Error level against Parameter_config.csv by
# read_and_validate_parameter_csv(). What is left here:
#   - Volume must be strictly positive: its range in
#     Parameter_config.csv includes 0, and a building of no volume
#     would make the ventilation resistances infinite.
#   - Volume is reported when it is unusually small, against the
#     plausibility bound of Validation_bounding_simulation.csv.
# -------------------------------------------------------------
# Inputs
#   model_parameters : Named list. Model parameters as loaded from
#                      11_Model_parameters.csv via load_parameters().
#                      Uses:
#                        Volume - Building volume (m3)
#   bounding_validation_config : Data frame. Content of
#                      Validation_bounding_simulation.csv, holding the
#                      plausibility bound below which the building
#                      volume is reported as unusually small.
# -------------------------------------------------------------
# Outputs
#   model_parameters : Named list. The input list, unchanged. A
#                      non-positive Volume stops the simulation.
# -------------------------------------------------------------
# Code outline
# 1. Validate Volume parameter
# -------------------------------------------------------------
# Usage instructions
# model_parameters <- validate_model_parameters(model_parameters, bounding_validation_config)
# -------------------------------------------------------------
# Where this function/script is used
#   - load_parameters()
# -------------------------------------------------------------
# functions/scripts called
#   get_validation_bounds()
# -------------------------------------------------------------

validate_model_parameters <- function(model_parameters,
                                      bounding_validation_config
                                      ) {

  # -------------------------------------------------------------
  # 1. Validate Volume parameter
  # Must be positive (error if not).
  # Below its plausibility bound: warning.
  # -------------------------------------------------------------
  {
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

  return(model_parameters)
}
