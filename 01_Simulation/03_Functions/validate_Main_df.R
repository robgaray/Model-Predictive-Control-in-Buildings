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
    "time",
    "external_temperature",
    "solar_radiation",
    "electricity_cost",
    "building_occupied",
    "mean_temp_24h",
    "Ti",
    "Te",
    "act_vent",
    "set_point_heating_low",
    "set_point_heating_high",
    "set_point_cooling_low",
    "set_point_cooling_high",
    "act_heat",
    "act_cool",
    "Qh",
    "Qc",
    "elec_heating",
    "elec_cooling",
    "elec_total",
    "elec_cost",
    "building_comfort",
    "reward",
    "external_temperature_forecast",
    "solar_radiation_forecast",
    "Ti_forecast",
    "Te_forecast",
    "Qh_forecast",
    "Qc_forecast",
    "elec_total_forecast"
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
  binary_cols <- c(
    "building_occupied",
    "act_vent",
    "act_heat",
    "act_cool"
  )
  
  for (col in binary_cols) {
    vals <- unique(na.omit(Main_df[[col]]))
    if (!all(vals %in% c(0, 1))) {
      stop(paste("Column", col, "contains values other than 0/1"))
    }
  }
  
  # ---------------------------------------------------------
  # Expected NA patterns (documented behavior)
  # ---------------------------------------------------------
  expected_na_cols <- c("building_occupied",
                        "mean_temp_24h",
                        "Ti",
                        "Te",
                        "act_vent",
                        "set_point_heating_low",
                        "set_point_heating_high",
                        "set_point_cooling_low",
                        "set_point_cooling_high",
                        "act_heat",
                        "act_cool",
                        "Qh",
                        "Qc",
                        "elec_heating",
                        "elec_cooling",
                        "elec_total",
                        "elec_cost",
                        "building_comfort",
                        "reward",
                        "external_temperature_forecast",
                        "solar_radiation_forecast",
                        "Ti_forecast",
                        "Te_forecast",
                        "Qh_forecast",
                        "Qc_forecast",
                        "elec_total_forecast"
                        )
  
  for (col in expected_na_cols) {
    if (!any(is.na(Main_df[[col]]))) {
      warning(paste(
        "Column", col,
        "has no NA values — expected NA before simulation initialization"
      ))
    }
  }
  
  # ---------------------------------------------------------
  # Sanity checks based on known physical ranges (soft checks)
  # ---------------------------------------------------------
  if (min(Main_df$external_temperature, na.rm = TRUE) < -50 ||
      max(Main_df$external_temperature, na.rm = TRUE) > 60) {
    warning("external_temperature outside expected physical range")
  }
  
  if (min(Main_df$electricity_cost, na.rm = TRUE) < -1) {
    warning("electricity_cost contains unusually low values")
  }
  
  if (min(Main_df$solar_radiation, na.rm = TRUE) < 0) {
    stop("solar_radiation contains negative values")
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
