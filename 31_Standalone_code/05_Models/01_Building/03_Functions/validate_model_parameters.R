# -------------------------------------------------------------
# Function: validate_model_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function checks what the parameter catalogue cannot express about
# the building volume loaded from 11_Model_parameters.csv. The types
# and ranges of every model parameter are those of
# the parameter catalogue, already applied when the file is read; that
# range admits 0 for Volume, so:
#   - a volume that is not positive stops the simulation;
#   - a volume below the plausibility bound of
#     Validation_bounding_simulation.csv is reported with a warning.
# -------------------------------------------------------------
# Inputs
#   model_parameters : Named list. Model parameters as loaded from
#                      11_Model_parameters.csv via load_11_model_parameters.R.
#   bounding_validation_config : Data frame. Content of
#                      Validation_bounding_simulation.csv, holding the
#                      plausibility bound below which the building
#                      volume is reported as unusually small.
#   model_file_name  : Character. Name of the model parameter file, the
#                      one its rows of Validation_bounding_simulation.csv
#                      carry.
# -------------------------------------------------------------
# Outputs
#   model_parameters : Named list. The input list, unchanged. A volume
#                      that is not positive stops the simulation.
# -------------------------------------------------------------
# Code outline
# 1. Validate Volume parameter
# -------------------------------------------------------------
# Usage instructions
# model_parameters <- validate_model_parameters(model_parameters,
# bounding_validation_config, model_file_name)
# -------------------------------------------------------------

validate_model_parameters <- function(model_parameters,
                                      bounding_validation_config,
                                      model_file_name
) {

  # -------------------------------------------------------------
  # 1. Validate Volume parameter
  # Must be positive (error if not). Below the plausibility bound:
  # warning.
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
      bounding_validation_config, model_file_name, "Volume"
    )

    if (!is.na(volume_bounds$min) &&
        model_parameters$Volume < volume_bounds$min) {
      warning(paste(
        "Parameter Volume is below", volume_bounds$min, "m3. Value:",
        model_parameters$Volume,
        ". Please verify the building volume."
      ), call. = FALSE)
    }

    rm(list = "volume_bounds")
  }

  return(model_parameters)
}
