# -------------------------------------------------------------
# Function: safe_ylim.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Returns a y-axis range computed from one or more numeric
# vectors that never collapses to a single value, ensuring
# that a plot axis always has a visible span.
# -------------------------------------------------------------
# INPUT:
#   ...    : One or more numeric vectors or scalar values.
#            NA and non-finite values are ignored.
#   margin : Numeric scalar. Fractional margin to add above and
#            below the range.  Default: 0.05 (5 %).
#
# OUTPUT:
#   Numeric vector of length 2: c(lower_limit, upper_limit).
#   If no finite values are found, returns c(0, 1).
#   If all finite values are equal, expands the range by ±10 %
#   of the absolute value (minimum ± 0.5).
# -------------------------------------------------------------
# FUNCTIONS USED (from this repository):
#   (none)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If all input values are NA or non-finite, the returned
#     range defaults to c(0, 1).
#   - When all values are equal (zero-span range), the range is
#     symmetrically expanded by max(|value| * 0.1, 0.5) before
#     the margin is applied.
# -------------------------------------------------------------
safe_ylim <- function(..., margin = 0.05) {
  vals <- c(...)
  rng  <- range(vals, na.rm = TRUE, finite = TRUE)
  if (!is.finite(rng[1])) rng <- c(0, 1)
  if (rng[1] == rng[2])   rng <- rng + c(-1, 1) * max(abs(rng[1]) * 0.1, 0.5)
  span <- rng[2] - rng[1]
  c(rng[1] - span * margin, rng[2] + span * margin)
}
