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
#       - System_df
#       - Flexibility_actions_df
#       - Meteo_transformations_df
# It checks the following aspects:
#   1. That Main_df is a non-empty data frame.
#   2. That all required columns are present.
#   3. That the 'time' column is POSIXct, contains no NAs, and is
#      strictly increasing.
#   4. That all non-time required columns are numeric.
#   5. That Occupancy and Scheduling are integer 0/1 flags and
#      that the remaining binary flag columns contain only 0/1 values.
#   6. Soft physical range checks on Text and Elec_unit_cost_buy (warnings).
#   7. That SolarR contains no negative values (hard check).
# -------------------------------------------------------------
# Inputs
#   Main_df : Data frame. The main simulation data frame. It must
#             contain every column of required_cols, the vector declared
#             in block "Required columns (contractual interface)" of the
#             body, which is the only list of them. By origin:
#               - time
#               - Meteo_df: the weather series
#               - Energy_Prices_df: the energy and flexibility prices and
#                 the flexibility probabilities
#               - System_df, with the columns of:
#                   - the thermal state (Ti, Te)
#                   - the context (Occupancy and Scheduling)
#                   - the setpoints and comfort
#                   - the heating and cooling actions
#                   - the thermal energy and the electricity
#                   - the flexibility commitment and phases
#                   - the economic results and the Reward
#                 Most of them come in four versions:
#                   - _exec: what was executed
#                   - _plan: the plan
#                   - _plan_flex_down: the downward flexibility itinerary
#                   - _plan_flex_up: the upward flexibility itinerary
#               - Flexibility_actions_df: Flex_Act
#               - Meteo_transformations_df: T_ext_24h and the forecasts
#             Output columns are present from the start, to be filled
#             during the simulation run.
#   bounding_validation_config : Data frame. The plausibility bounds of
#             the columns, from Validation_bounding_simulation.csv.
# -------------------------------------------------------------
# Outputs
#   Invisibly returns TRUE if all checks pass.
#   Prints a summary message with the number of rows and time span.
# -------------------------------------------------------------
# Code outline
# 1. Check data frame structure
# 2. Check required columns
# 3. Validate time column
# 4. Validate numeric columns
# 5. Validate binary flag columns
# 6. Plausibility range checks
# -------------------------------------------------------------
# Usage instructions
# validate_Main_df(Main_df, bounding_validation_config)
# -------------------------------------------------------------
# Where this function/script is used
# Called by 02_load_all_parameters.R after assembling Main_df.
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
#   - If Occupancy or Scheduling are not integer 0/1 columns, an error is
#     raised via stop().
#   - If a binary column contains values other than 0 or 1, an error
#     is raised via stop(). The binary columns are:
#       - Act_heat_exec
#       - Act_cool_exec
#   - If Text is outside its plausibility bounds, a warning() is issued
#     (soft check, simulation continues). The bounds are those of
#     Validation_bounding_simulation.csv, not of this function.
#   - If Elec_unit_cost_buy falls below its plausibility bound, a
#     warning() is issued (soft check, simulation continues). The bound
#     is that of Validation_bounding_simulation.csv.
#   - A magnitude whose bound is empty on one side in
#     Validation_bounding_simulation.csv is not checked on that side.
#   - If SolarR contains any negative value, an error is raised via stop().
# -------------------------------------------------------------
# functions/scripts called
#   get_validation_bounds()
# -------------------------------------------------------------

validate_Main_df <- function(Main_df, bounding_validation_config) {

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
  required_cols <- c(
    # Timestamp
    "time",
    # Meteo_df
    "Text",
    "SolarR",
    # Energy_Prices_df
    "Elec_unit_cost_buy",
    "Elec_unit_cost_distribution",
    "Flex_unit_cost_down_com",
    "Flex_unit_cost_down_exec",
    "Flex_unit_cost_up_com",
    "Flex_unit_cost_up_exec",
    "Flex_Probab_down", "Flex_Probab_up",
    # System_df - state
    "Ti_exec", "Ti_plan", "Ti_plan_flex_down", "Ti_plan_flex_up",
    "Te_exec", "Te_plan", "Te_plan_flex_down", "Te_plan_flex_up",
    # System_df - context
    "Scheduling",
    "Occupancy",
    "STP_heat_exec", "STP_heat_plan", "STP_heat_plan_flex_down", "STP_heat_plan_flex_up",
    "STP_heat_high_exec", "STP_heat_high_plan", "STP_heat_high_plan_flex_down", "STP_heat_high_plan_flex_up",
    "STP_heat_low_exec", "STP_heat_low_plan", "STP_heat_low_plan_flex_down", "STP_heat_low_plan_flex_up",
    "STP_cool_exec", "STP_cool_plan", "STP_cool_plan_flex_down", "STP_cool_plan_flex_up",
    "STP_cool_high_exec", "STP_cool_high_plan", "STP_cool_high_plan_flex_down", "STP_cool_high_plan_flex_up",
    "STP_cool_low_exec", "STP_cool_low_plan", "STP_cool_low_plan_flex_down", "STP_cool_low_plan_flex_up",
    # System_df - evaluation
    "Comfort_exec", "Comfort_plan", "Comfort_plan_flex_down", "Comfort_plan_flex_up",
    # System_df - action
    "Act_heat_exec", "Act_heat_plan", "Act_heat_plan_flex_down", "Act_heat_plan_flex_up",
    "Act_cool_exec", "Act_cool_plan", "Act_cool_plan_flex_down", "Act_cool_plan_flex_up",
    "Q_heat_exec", "Q_heat_plan", "Q_heat_plan_flex_down", "Q_heat_plan_flex_up",
    "Q_cool_exec", "Q_cool_plan", "Q_cool_plan_flex_down", "Q_cool_plan_flex_up",
    # System_df - energy
    "Elec_heat_exec", "Elec_heat_plan", "Elec_heat_plan_flex_down", "Elec_heat_plan_flex_up",
    "Elec_cool_exec", "Elec_cool_plan", "Elec_cool_plan_flex_down", "Elec_cool_plan_flex_up",
    "Elec_total_exec", "Elec_total_plan", "Elec_total_plan_flex_down", "Elec_total_plan_flex_up",
    "Elec_total_no_flex",
    "Elec_flex_down_plan", "Elec_flex_up_plan",
    "Flex_phase_down_plan", "Flex_phase_up_plan",
    # System_df - economic
    "Elec_purchase_cost_market", "Elec_sell_revenue_market",
    "Elec_flex_sell_revenue_market", "Elec_flex_purchase_cost_market",
    "Elec_market_net_cost_h", "Elec_deviations_net_cost_h", "Elec_net_cost_h",
    "Elec_flex_commitment_revenue_h", "Elec_flex_execution_revenue_h",
    "Elec_flex_deviations_net_cost_h", "Elec_cost_distr_h",
    # System_df - optimization
    "Reward",
    # Flexibility_actions_df
    "Flex_Act",
    # Meteo_transformations_df
    "T_ext_24h",
    "Text_forec",
    "SolarR_forec"
    )

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
  # Binary flag checks (0/1 expected)
  # ---------------------------------------------------------
  integer_binary_cols <- c("Occupancy", "Scheduling")
  for (CONT_001 in integer_binary_cols) {
    if (!is.integer(Main_df[[CONT_001]])) {
      stop("Column ", CONT_001, " must be of type integer")
    }
    vals <- unique(na.omit(Main_df[[CONT_001]]))
    if (!all(vals %in% c(0, 1))) {
      stop(paste("Column", CONT_001, "contains values other than 0/1"))
    }
  }

  binary_cols <- c("Act_heat_exec", "Act_cool_exec")
  for (CONT_001 in binary_cols) {
    vals <- unique(na.omit(Main_df[[CONT_001]]))
    if (!all(vals %in% c(0, 1))) {
      stop(paste("Column", CONT_001, "contains values other than 0/1"))
    }
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
    # get_validation_bounds is called to read the bounds of the outdoor
    # temperature out of the validation table, so this function holds
    # no temperature limit of its own.
    text_bounds <- get_validation_bounds(
      bounding_validation_config, "Main_df", "Text"
    )

    if ((!is.na(text_bounds$min) &&
         min(Main_df$Text, na.rm = TRUE) < text_bounds$min) ||
        (!is.na(text_bounds$max) &&
         max(Main_df$Text, na.rm = TRUE) > text_bounds$max)) {
      warning("Text outside expected physical range [",
              text_bounds$min, ", ", text_bounds$max, "]")
    }

    # get_validation_bounds is called again for the purchase price,
    # whose validation rule only bounds it from below.
    price_bounds <- get_validation_bounds(
      bounding_validation_config, "Main_df", "Elec_unit_cost_buy"
    )

    if ((!is.na(price_bounds$min) &&
         min(Main_df$Elec_unit_cost_buy, na.rm = TRUE) < price_bounds$min) ||
        (!is.na(price_bounds$max) &&
         max(Main_df$Elec_unit_cost_buy, na.rm = TRUE) > price_bounds$max)) {
      warning("Elec_unit_cost_buy outside expected range [",
              price_bounds$min, ", ", price_bounds$max, "]")
    }

    rm(text_bounds, price_bounds)
  }

  if (min(Main_df$SolarR, na.rm = TRUE) < 0) {
    stop("SolarR contains negative values")
  }

  # ---------------------------------------------------------
  # Successful validation
  # ---------------------------------------------------------
  cat(
    "Main_df validated successfully\n",
    "Rows:", nrow(Main_df), "\n",
    "Time span:",
    format(min(Main_df$time)), "→",
    format(max(Main_df$time)), "\n"
  )

  invisible(TRUE)
}
