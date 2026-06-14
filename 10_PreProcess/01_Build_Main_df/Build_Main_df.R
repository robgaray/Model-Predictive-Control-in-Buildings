# -------------------------------------------------------------
# Script: Build_Main_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This script generates Main_df.csv and Main_df.rds from meteorological
# and energy price input files. It performs data validation, temporal
# alignment, resampling, and filling to create a consistent dataset
# with the required resolution.
#
# The script reads:
# - Meteo.csv: Meteorological data (time, Text, SolarR)
# - Energy_Prices.csv: Energy price data (time, electricity costs,
#   flexibility costs)
#
# It performs the following operations:
# - Data validation (type, range)
# - Temporal range verification
# - Interactive resampling to user-specified resolution
# - Data filling (linear interpolation for meteo, forward-fill for prices)
# - Column initialization for simulation variables
# -------------------------------------------------------------
# Inputs
# - Meteo.csv: Located in 01_Input/
#   Columns: time, Text, SolarR
# - Energy_Prices.csv: Located in 01_Input/
#   Columns: time, Elec_unit_cost_buy, Elec_unit_cost_sell,
#   Flex_unit_cost_down_com, Flex_unit_cost_down_exec,
#   Flex_unit_cost_up_com, Flex_unit_cost_up_exec
# -------------------------------------------------------------
# Outputs
# - Main_df.csv: Main dataframe in CSV format (in 90_Output/)
# - Main_df.rds: Main dataframe in RDS format (in 90_Output/)
# -------------------------------------------------------------
# Code outline
# 1. Load required libraries
# 2. Read input files
# 3. Validate input data
# 4. Verify temporal range alignment
# 5. Request resampling resolution from user
# 6. Resample data
# 7. Fill missing data
# 8. Initialize additional columns required by simulation
# 9. Validate against needed_cols.txt
# 10. Save output files
# -------------------------------------------------------------
# Usage instructions
# From repository root, run:
# Rscript 10_PreProcess/01_Build_Main_df/Build_Main_df.R
#
# The script will prompt for resampling resolution in minutes.
# -------------------------------------------------------------

# -------------------------------------------------------------
# 1. Load required libraries
# -------------------------------------------------------------

cat("Loading required libraries...\n")

# Function to check and install packages if needed
{
  if (!require("data.table", quietly = TRUE)) {
    install.packages("data.table", repos = "https://cran.r-project.org")
    library(data.table)
  }
}

cat("Libraries loaded.\n\n")

# -------------------------------------------------------------
# 2. Read input files
# -------------------------------------------------------------

cat("Reading input files...\n")

# Define file paths
{
  input_dir        <- file.path("10_PreProcess", "01_Build_Main_df", "01_Input")
  meteo_path       <- file.path(input_dir, "Meteo.csv")
  energy_path      <- file.path(input_dir, "Energy_Prices.csv")
  config_dir       <- file.path("30_Simulation", "02_Config")
  needed_cols_path <- file.path(config_dir, "02_Needed_cols.csv")
  output_dir       <- file.path("10_PreProcess", "01_Build_Main_df", "90_Output")
}

# Read files
{
  Meteo          <- read.csv(meteo_path, stringsAsFactors = FALSE)
  Energy_Prices  <- read.csv(energy_path, stringsAsFactors = FALSE)
}

cat("Meteo.csv loaded:", nrow(Meteo), "rows\n")
cat("Energy_Prices.csv loaded:", nrow(Energy_Prices), "rows\n\n")

# -------------------------------------------------------------
# 3. Validate input data
# -------------------------------------------------------------

cat("Validating input data...\n")

# -------------------------------------------------------------
# 3.1. Validate Meteo.csv
# -------------------------------------------------------------

cat("Validating Meteo.csv...\n")

# Check required columns
{
  required_meteo_cols <- c("time", "Text", "SolarR")
  missing_cols        <- setdiff(required_meteo_cols, names(Meteo))
  
  if (length(missing_cols) > 0) {
    stop("ERROR: Missing columns in Meteo.csv: ",
         paste(missing_cols, collapse = ", "))
  }
}

# Parse time
{
  # Try parsing with datetime format first, then date-only format
  parsed_time <- as.POSIXct(Meteo$time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
  # For any NAs (date-only values), try parsing as date (assumes 00:00:00)
  na_times <- is.na(parsed_time)
  if (any(na_times)) {
    parsed_time[na_times] <- as.POSIXct(Meteo$time[na_times], format = "%Y-%m-%d", tz = "UTC")
  }
  Meteo$time <- parsed_time
  rm(parsed_time, na_times)
  
  if (any(is.na(Meteo$time))) {
    stop("ERROR: Invalid time format in Meteo.csv. ",
         "Expected format: YYYY-MM-DD HH:MM:SS or YYYY-MM-DD")
  }
}

# Validate Text (temperature in °C, range: -50 to 100)
{
  if (!is.numeric(Meteo$Text)) {
    stop("ERROR: Text in Meteo.csv is not numeric")
  }
  
  if (any(Meteo$Text < -50 | Meteo$Text > 100, na.rm = TRUE)) {
    stop("ERROR: Text in Meteo.csv out of range (-50 to 100 °C)")
  }
}

# Validate SolarR (solar radiation in W/m2, range: 0 to 1500)
{
  if (!is.numeric(Meteo$SolarR)) {
    stop("ERROR: SolarR in Meteo.csv is not numeric")
  }
  
  if (any(Meteo$SolarR < 0, na.rm = TRUE)) {
    cat("WARNING: Negative SolarR values found. Setting to 0.\n")
    Meteo$SolarR[Meteo$SolarR < 0] <- 0
  }
  
  if (any(Meteo$SolarR > 1500, na.rm = TRUE)) {
    cat("WARNING: SolarR values > 1500 W/m2 found.\n")
  }
}

cat("Meteo.csv validated successfully.\n\n")

# -------------------------------------------------------------
# 3.2. Validate Energy_Prices.csv
# -------------------------------------------------------------

cat("Validating Energy_Prices.csv...\n")

# Parse time
{
  # Try parsing with datetime format first, then date-only format
  parsed_time <- as.POSIXct(
    Energy_Prices$time,
    format = "%Y-%m-%d %H:%M:%S",
    tz     = "UTC"
  )
  # For any NAs (date-only values), try parsing as date (assumes 00:00:00)
  na_times <- is.na(parsed_time)
  if (any(na_times)) {
    parsed_time[na_times] <- as.POSIXct(
      Energy_Prices$time[na_times],
      format = "%Y-%m-%d",
      tz     = "UTC"
    )
  }
  Energy_Prices$time <- parsed_time
  rm(parsed_time, na_times)
  
  if (any(is.na(Energy_Prices$time))) {
    stop("ERROR: Invalid time format in Energy_Prices.csv. ",
         "Expected format: YYYY-MM-DD HH:MM:SS or YYYY-MM-DD")
  }
}

# Check for Elec_unit_cost_buy and Elec_unit_cost_sell
{
  has_buy  <- "Elec_unit_cost_buy" %in% names(Energy_Prices)
  has_sell <- "Elec_unit_cost_sell" %in% names(Energy_Prices)
  has_elec <- "Elec_unit_cost" %in% names(Energy_Prices)
  
  if (!has_buy && !has_sell && !has_elec) {
    stop("ERROR: Energy_Prices.csv must contain at least one of: ",
         "Elec_unit_cost_buy, Elec_unit_cost_sell, or Elec_unit_cost")
  }
  
  if (!has_buy && !has_sell && has_elec) {
    cat("WARNING: Using Elec_unit_cost for both buy and sell prices.\n")
    Energy_Prices$Elec_unit_cost_buy  <- Energy_Prices$Elec_unit_cost
    Energy_Prices$Elec_unit_cost_sell <- Energy_Prices$Elec_unit_cost
  }
  
  if (has_buy && !has_sell) {
    cat("WARNING: Elec_unit_cost_sell not found. ",
        "Using Elec_unit_cost_buy values.\n")
    Energy_Prices$Elec_unit_cost_sell <- Energy_Prices$Elec_unit_cost_buy
  }
  
  if (!has_buy && has_sell) {
    cat("WARNING: Elec_unit_cost_buy not found. ",
        "Using Elec_unit_cost_sell values.\n")
    Energy_Prices$Elec_unit_cost_buy <- Energy_Prices$Elec_unit_cost_sell
  }
}

# Validate electricity cost ranges
{
  if (!is.numeric(Energy_Prices$Elec_unit_cost_buy)) {
    stop("ERROR: Elec_unit_cost_buy is not numeric")
  }
  
  if (!is.numeric(Energy_Prices$Elec_unit_cost_sell)) {
    stop("ERROR: Elec_unit_cost_sell is not numeric")
  }
  
  if (any(Energy_Prices$Elec_unit_cost_buy < -1 |
          Energy_Prices$Elec_unit_cost_buy > 1, na.rm = TRUE)) {
    cat("WARNING: Elec_unit_cost_buy out of expected range (-1 to 1 €/kWh)\n")
  }
  
  if (any(Energy_Prices$Elec_unit_cost_sell < -1 |
          Energy_Prices$Elec_unit_cost_sell > 1, na.rm = TRUE)) {
    cat("WARNING: Elec_unit_cost_sell out of expected range (-1 to 1 €/kWh)\n")
  }
}

# Check and validate flexibility cost columns
{
  flex_cols <- c(
    "Flex_unit_cost_down_com",
    "Flex_unit_cost_down_exec",
    "Flex_unit_cost_up_com",
    "Flex_unit_cost_up_exec"
  )
  
  for (col in flex_cols) {
    if (!(col %in% names(Energy_Prices))) {
      cat("WARNING: ", col, " not found. Setting to 0.\n", sep = "")
      Energy_Prices[[col]] <- 0
    } else {
      if (!is.numeric(Energy_Prices[[col]])) {
        stop("ERROR: ", col, " is not numeric")
      }
      
      if (any(Energy_Prices[[col]] < 0 | Energy_Prices[[col]] > 10,
              na.rm = TRUE)) {
        cat("WARNING: ", col, " out of expected range (0 to 10 €/kWh)\n",
            sep = "")
      }
    }
  }
}

cat("Energy_Prices.csv validated successfully.\n\n")

# -------------------------------------------------------------
# 4. Verify temporal range alignment
# -------------------------------------------------------------

cat("Verifying temporal range alignment...\n")

# Get start and end times
{
  meteo_start  <- min(Meteo$time)
  meteo_end    <- max(Meteo$time)
  energy_start <- min(Energy_Prices$time)
  energy_end   <- max(Energy_Prices$time)
}

cat("Meteo range: ", format(meteo_start), " to ", format(meteo_end), "\n",
    sep = "")
cat("Energy range: ", format(energy_start), " to ", format(energy_end), "\n",
    sep = "")

# Check start time alignment (must match to the minute)
{
  common_start <- max(meteo_start, energy_start)
  common_end   <- min(meteo_end, energy_end)
  
  if (format(meteo_start, "%Y-%m-%d %H:%M") !=
      format(energy_start, "%Y-%m-%d %H:%M")) {
    stop("ERROR: Start times do not match between Meteo and Energy_Prices. ",
         "Both must start at the same date-hour-minute.")
  }
  
  if (format(meteo_end, "%Y-%m-%d %H") !=
      format(energy_end, "%Y-%m-%d %H")) {
    stop("ERROR: End times do not match to the hour between Meteo and ",
         "Energy_Prices. Both must end at the same date-hour.")
  }
}

cat("Temporal ranges verified successfully.\n\n")

# -------------------------------------------------------------
# 5. Request resampling resolution from user
# -------------------------------------------------------------

cat("Requesting resampling resolution...\n")

# Determine resolution of input files
{
  meteo_intervals  <- diff(as.numeric(Meteo$time))
  energy_intervals <- diff(as.numeric(Energy_Prices$time))
  
  meteo_res_sec  <- as.numeric(median(meteo_intervals))
  energy_res_sec <- as.numeric(median(energy_intervals))
  
  meteo_res_min  <- meteo_res_sec / 60
  energy_res_min <- energy_res_sec / 60
}

cat("Detected resolutions:\n")
cat("  Meteo: ", meteo_res_min, " minutes\n", sep = "")
cat("  Energy: ", energy_res_min, " minutes\n\n", sep = "")

# Request resolution from user
{
  user_res_min <- as.numeric(readline("Enter desired resampling resolution in minutes: "))
  
  if (is.na(user_res_min) || user_res_min <= 0) {
    stop("ERROR: Invalid resolution entered")
  }
  
  # Check if resolution is a valid divisor
  if (meteo_res_min %% user_res_min != 0) {
    stop("ERROR: Resolution ", user_res_min, " minutes is not a valid divisor ",
         "of Meteo resolution (", meteo_res_min, " minutes)")
  }
  
  if (energy_res_min %% user_res_min != 0) {
    stop("ERROR: Resolution ", user_res_min, " minutes is not a valid divisor ",
         "of Energy resolution (", energy_res_min, " minutes)")
  }
}

cat("Resampling to ", user_res_min, " minutes resolution.\n\n", sep = "")

# -------------------------------------------------------------
# 6. Resample data
# -------------------------------------------------------------

cat("Resampling data...\n")

# Create target time sequence
{
  # Find the end time: last complete period of shortest file
  end_time <- min(meteo_end, energy_end)
  
  # Adjust end_time to include last complete period
  # Calculate how many periods fit into the time range
  time_range_min <- as.numeric(
    difftime(end_time, common_start, units = "mins")
  )
  n_periods      <- floor(time_range_min / user_res_min)
  adjusted_end   <- common_start + (n_periods * user_res_min * 60)
  
  target_times <- seq(
    from = common_start,
    to   = adjusted_end,
    by   = paste(user_res_min, "min")
  )
}

cat("Target time range: ", format(target_times[1]), " to ",
    format(tail(target_times, 1)), "\n", sep = "")
cat("Number of time steps: ", length(target_times), "\n\n", sep = "")

# -------------------------------------------------------------
# 6.1. Resample Meteo (linear interpolation)
# -------------------------------------------------------------

cat("Resampling Meteo with linear interpolation...\n")

{
  Meteo_resampled <- data.frame(time = target_times)
  
  # Interpolate Text
  Meteo_resampled$Text <- approx(
    x      = as.numeric(Meteo$time),
    y      = Meteo$Text,
    xout   = as.numeric(target_times),
    method = "linear",
    rule   = 2
  )$y
  
  # Interpolate SolarR
  Meteo_resampled$SolarR <- approx(
    x      = as.numeric(Meteo$time),
    y      = Meteo$SolarR,
    xout   = as.numeric(target_times),
    method = "linear",
    rule   = 2
  )$y
}

cat("Meteo resampled successfully.\n\n")

# -------------------------------------------------------------
# 6.2. Resample Energy_Prices (forward fill)
# -------------------------------------------------------------

cat("Resampling Energy_Prices with forward fill...\n")

{
  # Convert to data.table for efficient rolling join
  Energy_dt <- data.table(Energy_Prices)
  setkey(Energy_dt, time)
  
  Target_dt <- data.table(time = target_times)
  setkey(Target_dt, time)
  
  # Perform rolling join (forward fill / LOCF - Last Observation Carried Forward)
  # roll=Inf: Forward-fill with no distance limit (LOCF behavior)
  # rollends=c(TRUE, TRUE): Handle edge cases properly:
  #   - rollends[1]=TRUE: If target time precedes all data, use first row
  #     (matches original: Energy_Prices[[col]][1])
  #   - rollends[2]=TRUE: If target time follows all data, use last row
  # Note: The temporal alignment validation (section 4 above) ensures that
  # target_times always start at or after Energy_Prices start time, making
  # rollends[1] a safety measure rather than an expected case.
  Energy_resampled <- Energy_dt[Target_dt, roll = Inf, rollends = c(TRUE, TRUE)]
  
  # Convert back to data.frame
  Energy_resampled <- as.data.frame(Energy_resampled)
}

cat("Energy_Prices resampled successfully.\n\n")

# -------------------------------------------------------------
# 7. Merge resampled data
# -------------------------------------------------------------

cat("Merging resampled data...\n")

{
  Main_df <- merge(Meteo_resampled, Energy_resampled, by = "time")
}

cat("Data merged. Rows: ", nrow(Main_df), "\n\n", sep = "")

# -------------------------------------------------------------
# 8. Initialize additional columns required by simulation
# -------------------------------------------------------------

cat("Initializing additional columns...\n")

# These columns will be populated during simulation
{
  init_cols <- c(
    "Flex_Probab", "Flex_Act", "Flex_Length", "Flex_Intensity",
    "Occupancy", "Scheduling", "Act_vent", "T_ext_24h",
    "Text_forec", "Text_forec_ant", "SolarR_forec", "SolarR_forec_ant",
    "Ti", "Te",
    "STP_heat", "STP_heat_high", "STP_heat_low",
    "STP_cool", "STP_cool_high", "STP_cool_low",
    "Act_heat", "Act_cool",
    "Q_heat", "Q_cool",
    "Elec_heat", "Elec_cool", "Elec_total", "Elec_total_no_flex",
    "Elec_Cost", "Elec_flex_revenue", "Comfort",
    "Ti_plan", "Te_plan",
    "STP_heat_plan", "STP_heat_high_plan", "STP_heat_low_plan",
    "STP_cool_plan", "STP_cool_high_plan", "STP_cool_low_plan",
    "Act_heat_plan", "Act_cool_plan",
    "Q_heat_plan", "Q_cool_plan",
    "Elec_heat_plan", "Elec_cool_plan", "Elec_total_plan",
    "Elec_Cost_Plan", "Comfort_plan",
    "Ti_plan_flex", "Te_plan_flex",
    "STP_heat_plan_flex", "STP_heat_high_plan_flex",
    "STP_heat_low_plan_flex",
    "STP_cool_plan_flex", "STP_cool_high_plan_flex",
    "STP_cool_low_plan_flex",
    "Act_heat_plan_flex", "Act_cool_plan_flex",
    "Q_heat_plan_flex", "Q_cool_plan_flex",
    "Elec_heat_plan_flex", "Elec_cool_plan_flex",
    "Elec_total_plan_flex",
    "Comfort_plan_flex",
    "Elec_flex_plan",
    "Elec_flex_com_revenue_plan",
    "Elec_flex_exec_revenue_plan",
    "Elec_flex_revenue_plan",
    "Reward"
  )
  
  for (col in init_cols) {
    Main_df[[col]] <- 0
  }
  Main_df$Occupancy  <- as.integer(Main_df$Occupancy)
  Main_df$Scheduling <- as.integer(Main_df$Scheduling)
}

cat("Additional columns initialized.\n\n")

# -------------------------------------------------------------
# 9. Validate against needed_cols.txt
# -------------------------------------------------------------

cat("Validating against needed_cols.txt...\n")

{
  # Read needed columns
  needed_lines <- readLines(needed_cols_path)
  needed_cols  <- needed_lines[!grepl("^#", needed_lines) &
                               nchar(trimws(needed_lines)) > 0]
  needed_cols  <- trimws(needed_cols)
  
  # Check for missing columns
  missing_cols <- setdiff(needed_cols, names(Main_df))
  extra_cols   <- setdiff(names(Main_df), needed_cols)
  
  if (length(missing_cols) > 0) {
    cat("WARNING: Missing columns in Main_df:\n")
    cat("  ", paste(missing_cols, collapse = ", "), "\n\n", sep = "")
  }
  
  if (length(extra_cols) > 0) {
    cat("INFO: Extra columns in Main_df (will be kept):\n")
    cat("  ", paste(extra_cols, collapse = ", "), "\n\n", sep = "")
  }
  
  if (length(missing_cols) == 0) {
    cat("All required columns present in Main_df.\n\n")
  }
}

# -------------------------------------------------------------
# 10. Save output files
# -------------------------------------------------------------

cat("Saving output files...\n")

# Create output directory if it doesn't exist
{
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
}

# Save CSV
{
  csv_path <- file.path(output_dir, "Main_df.csv")
  write.csv(Main_df, file = csv_path, row.names = FALSE, quote = FALSE)
  cat("Main_df.csv saved to: ", csv_path, "\n", sep = "")
}

# Save RDS
{
  rds_path <- file.path(output_dir, "Main_df.rds")
  saveRDS(Main_df, file = rds_path)
  cat("Main_df.rds saved to: ", rds_path, "\n", sep = "")
}

# -------------------------------------------------------------
# End of script
# -------------------------------------------------------------

cat("\nBuild_Main_df completed successfully!\n")
cat("Generated Main_df with ", nrow(Main_df), " rows and ",
    ncol(Main_df), " columns.\n", sep = "")
