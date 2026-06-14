# -------------------------------------------------------------
# Function: build_param_range
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Builds a numeric sequence from min, max, step inputs.
# Returns a numeric vector, or the single 'fixed' value if
# min == max.
#
# When step == 0, only the minimum value is returned (i.e.
# c(min)). This is useful when the user wants to fix the
# parameter at its minimum value for the SCC configuration
# file.
# -------------------------------------------------------------
# Inputs
#   val_min : numeric minimum value
#   val_max : numeric maximum value
#   val_step: numeric step size (must be >= 0)
# -------------------------------------------------------------
# Outputs
#   A numeric vector of parameter values.
# -------------------------------------------------------------
# Code outline
#   1. Validate inputs (NA check, step >= 0, min <= max)
#   2. If step == 0, return only min value
#   3. Otherwise, return seq(min, max, by = step)
# -------------------------------------------------------------
# Usage instructions
#   vals <- build_param_range(10, 50, 10)
#   vals <- build_param_range(0, 1, 0)  # returns c(0)
# -------------------------------------------------------------
# Where this function/script is used
#   Called by GUI_parametric.R when building parameter ranges
#   for factorial or LHS designs.
# -------------------------------------------------------------
# functions/scripts called
#   None (base R only).
# -------------------------------------------------------------
build_param_range <- function(val_min, val_max, val_step) {

  # -------------------------------------------------------------
  # 1. Validate inputs
  # -------------------------------------------------------------
  {
    if (is.na(val_min) || is.na(val_max) || is.na(val_step)) {
      stop("min, max and step must all be numeric values.")
    }
    if (val_step < 0) {
      stop("step must be greater than or equal to 0.")
    }
    if (val_min > val_max) {
      stop("min must be less than or equal to max.")
    }
  }

  # -------------------------------------------------------------
  # 2. Handle step == 0: return only the minimum value
  # When step == 0 the user intends to fix the parameter at its
  # minimum value for the SCC configuration file.
  # -------------------------------------------------------------
  {
    if (val_step == 0) {
      return(val_min)
    }
  }

  # -------------------------------------------------------------
  # 3. Generate sequence with step
  # -------------------------------------------------------------
  {
    seq(from = val_min, to = val_max, by = val_step)
  }
}
