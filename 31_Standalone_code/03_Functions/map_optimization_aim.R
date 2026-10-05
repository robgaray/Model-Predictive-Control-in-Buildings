# -------------------------------------------------------------
# Function: map_optimization_aim.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Maps raw market aim values to internal optimization aim labels.
# Accepted input values (case-insensitive):
#   - O
#   - E
#   - O+F
#   - E+F
# Any other value produces an error.
# -------------------------------------------------------------
# Inputs
# aim_raw      : Scalar value with market aim code.
# -------------------------------------------------------------
# Outputs
# Character. "energy", "flexibility", "operation" or
#            "operationflex".
# -------------------------------------------------------------
# Usage instructions
# map_optimization_aim(aim_raw)
# -------------------------------------------------------------
# Code outline
# 1. Match the code against the four aims the model accepts.
# 2. Stop on anything else, because an unknown aim cannot be
#    defaulted. validate_inputs() already refuses such a code, so
#    this only guards a direct call.
# -------------------------------------------------------------
# Where this function/script is used
#   - run_market_process()
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

map_optimization_aim <- function(aim_raw) {

  aim_chr <- toupper(trimws(as.character(aim_raw)[1]))

  if (aim_chr == "E") {
    return("energy")
  }

  if (aim_chr == "E+F") {
    return("flexibility")
  }

  if (aim_chr == "O") {
    return("operation")
  }

  if (aim_chr == "O+F") {
    return("operationflex")
  }

  stop("Invalid market aim '", aim_chr,
       "'. Accepted values: O, E, O+F, E+F.")
}
