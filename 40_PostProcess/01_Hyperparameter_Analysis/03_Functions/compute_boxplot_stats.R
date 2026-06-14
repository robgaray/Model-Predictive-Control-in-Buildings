# -------------------------------------------------------------
# Function: compute_boxplot_stats
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Computes boxplot statistics for a numeric vector using user-defined
# percentile thresholds. Returns a list compatible with the bxp()
# function for drawing custom boxplots.
# The five elements of the box are:
#   1. Lower whisker  - defined by lower_pct
#   2. Lower box edge - defined by lower_box_pct
#   3. Central mark   - mean or median (center_type)
#   4. Upper box edge - defined by upper_box_pct
#   5. Upper whisker  - defined by upper_pct
# Outlier values (outside the whisker range) are also returned.
# -------------------------------------------------------------
# Inputs
#   y_vals        : numeric vector of values for one group
#   lower_pct     : numeric 0-100. Percentile for lower whisker.
#   lower_box_pct : numeric 0-100. Percentile for lower box edge.
#   center_type   : character. "mean" or "median".
#   upper_box_pct : numeric 0-100. Percentile for upper box edge.
#   upper_pct     : numeric 0-100. Percentile for upper whisker.
# -------------------------------------------------------------
# Outputs
#   A list with:
#     stats : numeric vector of length 5 (lower_whisker, lower_box,
#             center, upper_box, upper_whisker). NA if no valid data.
#     out   : numeric vector of outlier values (outside whisker range).
#     n     : integer. Number of valid (non-NA) observations.
# -------------------------------------------------------------
# Code outline
#   1. Remove NA values and handle empty input
#   2. Compute percentile-based whisker and box bounds
#   3. Compute central statistic (mean or median)
#   4. Identify outlier values
# -------------------------------------------------------------
# Usage instructions
#   stats_one_group <- compute_boxplot_stats(
#     y_vals        = my_values,
#     lower_pct     = 5,
#     lower_box_pct = 25,
#     center_type   = "median",
#     upper_box_pct = 75,
#     upper_pct     = 95
#   )
# -------------------------------------------------------------
# Where this function/script is used
#   PostProcess_hyperparameter_analysis.R
#   GUI_hyperparameter.R
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

compute_boxplot_stats <- function(y_vals,
                                   lower_pct,
                                   lower_box_pct,
                                   center_type,
                                   upper_box_pct,
                                   upper_pct) {

  # -------------------------------------------------------------
  # 1. Remove NA values and handle empty input
  # -------------------------------------------------------------
  {
    y_clean <- y_vals[!is.na(y_vals)]

    if (length(y_clean) == 0) {
      return(list(
        stats = rep(NA_real_, 5),
        out   = numeric(0),
        n     = 0L
      ))
    }
  }

  # -------------------------------------------------------------
  # 2. Compute percentile-based whisker and box bounds
  # -------------------------------------------------------------
  {
    lo_wh  <- quantile(y_clean, lower_pct     / 100, names = FALSE)
    lo_box <- quantile(y_clean, lower_box_pct / 100, names = FALSE)
    hi_box <- quantile(y_clean, upper_box_pct / 100, names = FALSE)
    hi_wh  <- quantile(y_clean, upper_pct     / 100, names = FALSE)
  }

  # -------------------------------------------------------------
  # 3. Compute central statistic (mean or median)
  # -------------------------------------------------------------
  {
    if (center_type == "mean") {
      ctr <- mean(y_clean)
    } else {
      ctr <- median(y_clean)
    }
  }

  # -------------------------------------------------------------
  # 4. Identify outlier values (outside whisker range)
  # -------------------------------------------------------------
  {
    out_vals <- y_clean[y_clean < lo_wh | y_clean > hi_wh]
  }

  list(
    stats = c(lo_wh, lo_box, ctr, hi_box, hi_wh),
    out   = out_vals,
    n     = length(y_clean)
  )
}
