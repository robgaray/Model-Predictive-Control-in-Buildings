# -------------------------------------------------------------
# Function: generate_lhs_design
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Generates a Latin Hypercube Sample (LHS) design based on the
# defined parameters and their ranges. LHS provides a more
# efficient sampling of the parameter space than full factorial
# designs, especially when dealing with a large number of
# parameters.
#
# For numeric parameters (with min/max/step), continuous LHS
# values are rounded to the nearest valid step value. For
# categorical parameters (checkbox-style, e.g. control_type),
# values are sampled uniformly from the available options.
# -------------------------------------------------------------
# Inputs
#   params_list : named list; each element is a numeric vector
#                 of valid values for that parameter.
#   n_samples   : integer; number of LHS samples to generate.
#   seed        : integer or NULL; random seed for
#                 reproducibility.
# -------------------------------------------------------------
# Outputs
#   A data.frame with one row per LHS sample and one column per
#   parameter.
# -------------------------------------------------------------
# Code outline
#   1. Validate inputs
#   2. Generate raw LHS matrix in [0,1] using a simple
#      stratified random approach (no external package needed)
#   3. Map each column to the corresponding parameter values
#   4. Return data.frame
# -------------------------------------------------------------
# Usage instructions
#   params <- list(pop = c(10,20,30), iter = c(10,20))
#   df <- generate_lhs_design(params, n_samples = 5)
# -------------------------------------------------------------
# Where this function/script is used
#   Called by GUI_parametric.R when the user clicks "Generate
#   Latin Hypercube Sample".
# -------------------------------------------------------------
# functions/scripts called
#   None (base R only).
# -------------------------------------------------------------
generate_lhs_design <- function(params_list,
                                n_samples = 100L,
                                seed      = NULL) {

  # -------------------------------------------------------------
  # 1. Validate inputs
  # -------------------------------------------------------------
  {
    param_names <- names(params_list)
    n_params    <- length(param_names)

    if (n_params == 0) {
      stop("params_list must contain at least one parameter.")
    }
    if (n_samples < 1) {
      stop("n_samples must be at least 1.")
    }
    for (CONT_001 in param_names) {
      if (length(params_list[[CONT_001]]) == 0) {
        stop(sprintf(
          "Parameter '%s' has no values. Select at least one option.",
          CONT_001
        ))
      }
    }
  }

  # -------------------------------------------------------------
  # 2. Generate raw LHS matrix in [0,1]
  # Uses stratified random sampling: for each dimension, the
  # [0,1] interval is split into n_samples equal strata. One
  # random point is drawn per stratum, then the column is
  # randomly permuted.
  # -------------------------------------------------------------
  {
    if (!is.null(seed)) set.seed(seed)

    lhs_matrix <- matrix(NA_real_, nrow = n_samples, ncol = n_params)

    for (CONT_002 in seq_len(n_params)) {
      strata_lower <- (seq_len(n_samples) - 1) / n_samples
      strata_upper <- seq_len(n_samples)       / n_samples
      raw_vals     <- runif(n_samples,
                            min = strata_lower,
                            max = strata_upper)
      lhs_matrix[, CONT_002] <- sample(raw_vals)
    }
  }

  # -------------------------------------------------------------
  # 3. Map each column to the corresponding parameter values
  # Each [0,1] value is mapped to one of the discrete valid
  # values for that parameter using quantile-based binning.
  # -------------------------------------------------------------
  {
    result <- data.frame(matrix(NA_real_,
                                nrow = n_samples,
                                ncol = n_params))
    colnames(result) <- param_names

    for (CONT_003 in seq_len(n_params)) {
      vals     <- sort(unique(params_list[[param_names[CONT_003]]]))
      n_vals   <- length(vals)
      # Map [0,1] to index 1..n_vals
      indices  <- pmin(floor(lhs_matrix[, CONT_003] * n_vals) + 1,
                       n_vals)
      result[, CONT_003] <- vals[indices]
    }
  }

  # -------------------------------------------------------------
  # 4. Remove duplicate rows and return
  # -------------------------------------------------------------
  {
    result <- unique(result)
    rownames(result) <- NULL
    result
  }
}
