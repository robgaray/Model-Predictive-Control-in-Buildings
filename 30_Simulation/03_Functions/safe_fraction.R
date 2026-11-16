# -------------------------------------------------------------
# Function: safe_fraction.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Divides two vectors element by element, and reports NA where the
# denominator is zero.
#
# A fraction whose denominator is zero is reported as NA rather than as
# 0: with no energy traded in a slot, the share of that energy
# committed in Scheduling (or unwound, or adjusted at Execution) is
# undefined, and reporting 0 would read as "none of it", which is a
# different statement.
# -------------------------------------------------------------
# Inputs
#   numerator   : Numeric vector.
#   denominator : Numeric vector, the same length.
# -------------------------------------------------------------
# Outputs
#   Numeric vector: numerator / denominator, NA where the denominator
#   is zero.
# -------------------------------------------------------------
# Code outline
# 1. Divide, with NA where the denominator is zero.
# -------------------------------------------------------------
# Usage instructions
# share <- safe_fraction(qty_scheduling, energy_gross)
# -------------------------------------------------------------

safe_fraction <- function(numerator,
                          denominator
                          ) {

  # -------------------------------------------------------------
  # 1. Divide, with NA where the denominator is zero
  # -------------------------------------------------------------
  {
    result <- ifelse(denominator == 0, NA_real_, numerator / denominator)
  }

  return(result)
}
