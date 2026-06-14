# -------------------------------------------------------------
# Function: validate_Main_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function performs structural and content validation of the
# main simulation data frame (Main_df) before it is used in the
# MPC simulation loop.
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
#   Main_df : Data frame. The main simulation data frame. Must contain
#             all required columns listed below (both measured/input
#             columns and output/plan columns that will be populated
#             during the simulation run):
#               time, Text, SolarR,
#               Elec_unit_cost_buy, Elec_unit_cost_sell,
#               Flex_unit_cost_down_com, Flex_unit_cost_down_exec,
#               Flex_unit_cost_up_com, Flex_unit_cost_up_exec,
#               Flex_Probab, Flex_Act,
#               Occupancy, Scheduling, Act_vent, T_ext_24h,
#               Text_forec, Text_forec_ant, SolarR_forec, SolarR_forec_ant,
#               Ti, Te, STP_heat, STP_heat_high, STP_heat_low,
#               STP_cool, STP_cool_high, STP_cool_low,
#               Act_heat, Act_cool, Q_heat, Q_cool,
#               Elec_heat, Elec_cool, Elec_total, Comfort,
#               Ti_plan, Te_plan, STP_heat_plan, STP_heat_high_plan,
#               STP_heat_low_plan, STP_cool_plan, STP_cool_high_plan,
#               STP_cool_low_plan, Act_heat_plan, Act_cool_plan,
#               Q_heat_plan, Q_cool_plan,
#               Elec_heat_plan, Elec_cool_plan, Elec_total_plan, Comfort_plan,
#               Ti_plan_flex, Te_plan_flex,
#               STP_heat_low_plan_flex, STP_heat_high_plan_flex,
#               STP_cool_low_plan_flex, STP_cool_high_plan_flex,
#               Act_heat_plan_flex, Act_cool_plan_flex,
#               Q_heat_plan_flex, Q_cool_plan_flex,
#               Elec_heat_plan_flex, Elec_cool_plan_flex,
#               Elec_total_plan_flex, Comfort_plan_flex,
#               Elec_Cost, Elec_flex_plan, Reward
#
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
# 6. Physical range checks
# -------------------------------------------------------------
# Usage instructions
# validate_Main_df(Main_df)
# -------------------------------------------------------------
# Where this function/script is used
# Called by data_model_parameters.R after loading the main data frame.
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
#   - If binary columns (Act_vent, Act_heat, Act_cool) contain values
#     other than 0 or 1, an error is raised via stop().
#   - If Text is outside the range [-50, 60] °C, a warning() is issued
#     (soft check, simulation continues).
#   - If Elec_unit_cost_buy contains values below -1, a warning() is issued
#     (soft check, simulation continues).
#   - If SolarR contains any negative value, an error is raised via stop().
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

validate_Main_df <- function(Main_df) {
  
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
    # External environmental conditions
    "Text",
    "SolarR",
    # Energy and flexibility prices
    "Elec_unit_cost_buy",
    "Elec_unit_cost_sell",
    "Flex_unit_cost_down_com",
    "Flex_unit_cost_down_exec",
    "Flex_unit_cost_up_com",
    "Flex_unit_cost_up_exec",
    # Flexibility probability and execution
    "Flex_Probab",
    "Flex_Act",
    # Occupancy
    "Occupancy",
    "Scheduling",
    "Act_vent",
    # Derived variables from external conditions
    "T_ext_24h",
    # Weather forecast
    "Text_forec",
    "Text_forec_ant",
    "SolarR_forec",
    "SolarR_forec_ant",
    # Execution variables
    "Ti",
    "Te",
    "STP_heat",
    "STP_heat_high",
    "STP_heat_low",
    "STP_cool",
    "STP_cool_high",
    "STP_cool_low",
    "Act_heat",
    "Act_cool",
    "Q_heat",
    "Q_cool",
    "Elec_heat",
    "Elec_cool",
    "Elec_total",
    "Comfort",
    # Plan variables
    "Ti_plan",
    "Te_plan",
    "STP_heat_plan",
    "STP_heat_high_plan",
    "STP_heat_low_plan",
    "STP_cool_plan",
    "STP_cool_high_plan",
    "STP_cool_low_plan",
    "Act_heat_plan",
    "Act_cool_plan",
    "Q_heat_plan",
    "Q_cool_plan",
    "Elec_heat_plan",
    "Elec_cool_plan",
    "Elec_total_plan",
    "Comfort_plan",
    # Plan_flex variables
    "Ti_plan_flex",
    "Te_plan_flex",
    "STP_heat_low_plan_flex",
    "STP_heat_high_plan_flex",
    "STP_cool_low_plan_flex",
    "STP_cool_high_plan_flex",
    "Act_heat_plan_flex",
    "Act_cool_plan_flex",
    "Q_heat_plan_flex",
    "Q_cool_plan_flex",
    "Elec_heat_plan_flex",
    "Elec_cool_plan_flex",
    "Elec_total_plan_flex",
    "Comfort_plan_flex",
    # Reward calculation variables
    "Elec_Cost",
    "Elec_flex_plan",
    "Reward"
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

  binary_cols <- c("Act_vent", "Act_heat", "Act_cool")
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
  # Sanity checks based on known physical ranges (soft checks)
  # ---------------------------------------------------------
  if (min(Main_df$Text, na.rm = TRUE) < -50 ||
      max(Main_df$Text, na.rm = TRUE) > 60) {
    warning("Text outside expected physical range")
  }
  
  if (min(Main_df$Elec_unit_cost_buy, na.rm = TRUE) < -1) {
    warning("Elec_unit_cost_buy contains unusually low values")
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
