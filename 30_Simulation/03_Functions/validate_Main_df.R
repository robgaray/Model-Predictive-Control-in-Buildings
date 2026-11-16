# -------------------------------------------------------------
# Function: validate_Main_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function performs structural and content validation of the
# main simulation data frame (Main_df) before it is used in the
# MPC simulation loop. Main_df is assembled by assemble_main_df.R
# from:
#   - 2 real input dataframes:
#       - Meteo_df
#       - Energy_Prices_df
#   - 3 synthetic dataframes:
#       - System_variables_df
#       - Flexibility_actions_df
#       - Meteo_transformations_df
# It checks the following aspects:
#   1. That Main_df is a non-empty data frame.
#   2. That all required columns are present.
#   3. That the 'time' column is POSIXct, contains no NAs, and is
#      strictly increasing.
#   4. That all non-time required columns are numeric.
#   5. Soft physical range check on Elec_unit_cost_buy (warning).
#   6. That SolarR contains no negative values (hard check).
# The table of each asset, with its own columns, is checked by
# validate_asset_df().
# -------------------------------------------------------------
# Inputs
#   Main_df : Data frame. The main simulation data frame. It must
#             contain every column of required_cols. By origin:
#               - time
#               - Meteo_df: the weather series
#               - Energy_Prices_df: the energy and flexibility prices and
#                 the flexibility probabilities
#               - System_variables_df, with the columns of:
#                   - the net electricity of the system, in four
#                     versions: _exec (what was executed), _plan (the
#                     plan), _plan_flex_down and _plan_flex_up (the
#                     downward and upward flexibility itineraries)
#                   - the flexibility committed on each leg
#                   - the cash flows of the system
#               - Flexibility_actions_df: Flex_Act
#               - Meteo_transformations_df: T_ext_24h and the forecasts
#             Output columns are present from the start, to be filled
#             during the simulation run.
#   bounding_validation_config : Data frame. The plausibility bounds of
#             the columns, from Validation_bounding_simulation.csv.
#   required_cols : Character vector. The columns the assembled Main_df
#             must hold: those of stage assembly in 02_Needed_cols.csv,
#             as load_needed_columns() returns them.
# -------------------------------------------------------------
# Outputs
#   Invisibly returns TRUE if all checks pass.
#   Nothing is written to the console when all checks pass.
# -------------------------------------------------------------
# Code outline
# 1. Check data frame structure
# 2. Check required columns
# 3. Validate time column
# 4. Validate numeric columns
# 5. Plausibility range checks
# -------------------------------------------------------------
# Usage instructions
# validate_Main_df(Main_df, bounding_validation_config,
#                  parameters$needed_cols_assembly)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If Main_df is not a data frame, an error is raised via stop().
#   - If Main_df is empty (zero rows), an error is raised via stop().
#   - If any required column is missing, an error is raised listing
#     all missing column names.
#   - If 'time' is not POSIXct, contains NAs, or is not strictly
#     increasing, an error is raised via stop().
#   - If any non-time required column is not numeric, an error is raised
#     listing the offending column names.
#   - Text is not checked here: it is the weather input itself,
#     interpolated, so the range of Validation_Meteo_df.csv, checked
#     when the weather is read, already covers it.
#   - If Elec_unit_cost_buy falls below its plausibility bound, a
#     warning() is issued (soft check, simulation continues). The bound
#     is that of Validation_bounding_simulation.csv.
#   - A magnitude whose bound is empty on one side in
#     Validation_bounding_simulation.csv is not checked on that side.
#   - If SolarR contains any negative value, an error is raised via stop().
# -------------------------------------------------------------

validate_Main_df <- function(Main_df, bounding_validation_config,
                             required_cols) {

  # ---------------------------------------------------------
  # Basic structural checks
  # ---------------------------------------------------------
  if (!is.data.frame(Main_df)) {
    stop("Main_df is not a data.frame")
  }

  if (nrow(Main_df) == 0) {
    stop("Main_df is empty")
  }

  # ---------------------------------------------------------
  # Required columns (contractual interface)
  # ---------------------------------------------------------
  missing_cols <- setdiff(required_cols, names(Main_df))

  if (length(missing_cols) > 0) {
    stop(
      "Main_df is missing required columns:\n",
      paste(missing_cols, collapse = ", ")
    )
  }

  # ---------------------------------------------------------
  # time consistency
  # ---------------------------------------------------------
  if (!inherits(Main_df$time, "POSIXct")) {
    stop("time must be POSIXct")
  }

  if (any(is.na(Main_df$time))) {
    stop("time contains NA values")
  }

  if (any(diff(as.numeric(Main_df$time)) <= 0)) {
    stop("time is not strictly increasing")
  }

  # ---------------------------------------------------------
  # Numeric columns consistency
  # ---------------------------------------------------------
  numeric_cols <- setdiff(required_cols, "time")

  non_numeric <- numeric_cols[!sapply(Main_df[numeric_cols], is.numeric)]

  if (length(non_numeric) > 0) {
    stop(
      "The following columns must be numeric:\n",
      paste(non_numeric, collapse = ", ")
    )
  }

  # ---------------------------------------------------------
  # Categorical variable checks (currently none required)
  # ---------------------------------------------------------

  # ---------------------------------------------------------
  # Expected NA patterns (documented behavior)
  # Note: NA values have been converted to 0 per requirements
  # ---------------------------------------------------------
  # This section is now simplified since NAs are converted to 0

  # ---------------------------------------------------------
  # Sanity checks against the plausibility bounds of
  # Validation_bounding_simulation.csv (soft checks)
  # These columns already went through the range validation of their
  # own input dataframe (Validation_Meteo_df.csv,
  # Validation_Energy_Prices_df.csv). What is checked here is the
  # assembled Main_df, after interpolation and step-holding, and the
  # bounds it is checked against are read from the validation file so
  # that no limit is written twice.
  # ---------------------------------------------------------
  {
    # get_validation_bounds is called for the purchase price, whose
    # validation rule only bounds it from below.
    price_bounds <- get_validation_bounds(
      bounding_validation_config, "Main_df", "Elec_unit_cost_buy"
    )

    if ((!is.na(price_bounds$min) &&
         min(Main_df$Elec_unit_cost_buy, na.rm = TRUE) < price_bounds$min) ||
        (!is.na(price_bounds$max) &&
         max(Main_df$Elec_unit_cost_buy, na.rm = TRUE) > price_bounds$max)) {
      warning("Elec_unit_cost_buy outside expected range [",
              price_bounds$min, ", ", price_bounds$max, "]",
              call. = FALSE)
    }

    rm(list = "price_bounds")
  }

  if (min(Main_df$SolarR, na.rm = TRUE) < 0) {
    stop("SolarR contains negative values")
  }

  invisible(TRUE)
}
