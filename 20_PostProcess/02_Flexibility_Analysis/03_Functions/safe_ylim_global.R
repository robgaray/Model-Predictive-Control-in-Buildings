# -------------------------------------------------------------
# Function: safe_ylim_global.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Returns a y-axis range computed over the full data series
# (not just the current day's subset) that always includes 0,
# never collapses to a single value, and adds a small margin.
# Used for axes where visual consistency across multiple plots
# is required (e.g. the Graph 2 price axis in flexibility
# analysis), so that the scale is the same in every plot.
# -------------------------------------------------------------
# INPUT:
#   ...    : One or more numeric vectors or scalar values
#            covering the entire time series.
#            NA and non-finite values are ignored.
#   margin : Numeric scalar. Fractional margin to add above and
#            below the range.  Default: 0.05 (5 %).
#
# OUTPUT:
#   Numeric vector of length 2: c(lower_limit, upper_limit).
#   The range always contains 0.
#   If no finite values are found, returns c(0, 1).
#   If all finite values are equal, expands the range by ±10 %
#   of the absolute value (minimum ± 0.5).
# -------------------------------------------------------------
# FUNCTIONS USED (from this repository):
#   (none)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - 0 is always included in the range before the margin is
#     applied (via c(0, vals) in the range() call).
#   - If all input values are NA or non-finite, the returned
#     range defaults to c(0, 1).
#   - When all finite values (including 0) are equal, the range
#     is symmetrically expanded by max(|value| * 0.1, 0.5)
#     before the margin is applied.
# -------------------------------------------------------------
safe_ylim_global <- function(..., margin = 0.05) {
  vals <- c(...)
  rng  <- range(c(0, vals), na.rm = TRUE, finite = TRUE)
  if (!is.finite(rng[1])) rng <- c(0, 1)
  if (rng[1] == rng[2])   rng <- rng + c(-1, 1) * max(abs(rng[1]) * 0.1, 0.5)
  span <- rng[2] - rng[1]
  c(rng[1] - span * margin, rng[2] + span * margin)
}
