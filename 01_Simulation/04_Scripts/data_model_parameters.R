# -------------------------------------------------------------
# Script: data_model_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This script loads the main data frame and all model-related
# parameters (model, reward, forecast). It is sourced from Main.R.
# No need to look inside unless you want to modify the physical model.
# -------------------------------------------------------------
# Inputs
# main_file, model_file, reward_file, forecast_file,
# needed_cols_file : Character. Paths set by initialization.R.
# -------------------------------------------------------------
# Outputs
# Main_df : Data frame. The main simulation data frame.
# parameters : List. Contains model, reward, and forecast sub-lists.
# -------------------------------------------------------------
# Code outline
# 1. Load main data frame from RDS
# 2. Parse time column
# 3. Validate Main_df structure
# 4. Load model, reward, and forecast parameters
# 5. Build parameters list
# 6. Recalculate T_ext_24h from previous day averages
# -------------------------------------------------------------
# Usage
# source(file.path("01_Simulation", "04_Scripts", "data_model_parameters.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by Main.R and Main_SCC.R after initialization.
# -------------------------------------------------------------
# functions/scripts called
# validate_Main_df(), load_parameters() from 01_Simulation/03_Functions/
# -------------------------------------------------------------

# -----------------------------------------------------------
# Load data frame
# -----------------------------------------------------------
{
  Main_df <- readRDS(main_file)
  rm(main_file)
  
  # Ensure time column is POSIXct (convert from string if needed)
  if (!inherits(Main_df$time, "POSIXct")) {
    # Try parsing with datetime format first, then date-only format
    parsed_time <- as.POSIXct(Main_df$time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
    # For any NAs (date-only values), try parsing as date
    na_times <- is.na(parsed_time)
    if (any(na_times)) {
      parsed_time[na_times] <- as.POSIXct(Main_df$time[na_times], format = "%Y-%m-%d", tz = "UTC")
    }
    Main_df$time <- parsed_time
    rm(parsed_time, na_times)
    cat("Converted time column from string to POSIXct\n")
  }
  
  validate_Main_df(Main_df)
}

# -----------------------------------------------------------
# Model, forecast & Reward parameters
# -----------------------------------------------------------
{
  model_parameters <- load_parameters(model_file)
  if (is.null(model_parameters)) stop("Model parameters could not be loaded")
  cat("model parameters loaded\n")
  
  reward_parameters <- load_parameters(reward_file)
  if (is.null(reward_parameters)) stop("Reward parameters could not be loaded")
  cat("reward parameters loaded\n")
  
  forecast_parameters <- load_parameters(forecast_file)
  if (is.null(forecast_parameters)) stop("Weather forecast parameters could not be loaded")
  cat("Weather forecast parameters loaded\n")
  rm(model_file, reward_file, forecast_file)
  
  parameters <- list(
    model    = model_parameters,
    reward   = reward_parameters,
    forecast = forecast_parameters
  )
  rm(model_parameters, reward_parameters, forecast_parameters)
  
  parameters$forecast$forecast_type <- ifelse(parameters$forecast$forecast_type == 1, "inaccurate", "accurate")
  
  # Load needed columns list
  needed_cols_lines <- readLines(needed_cols_file)
  parameters$needed_cols <- needed_cols_lines[!grepl("^\\s*#", needed_cols_lines) & nzchar(trimws(needed_cols_lines))]
  cat("needed_cols loaded:", length(parameters$needed_cols), "columns\n")
  rm(needed_cols_lines, needed_cols_file)
}

# -----------------------------------------------------------
# Recalculate T_ext_24h: average Text from previous day
# -----------------------------------------------------------
{
  # Get the default value from forecast_parameters
  t_ext_24h_default <- parameters$forecast$t_ext_24h_default
  if (is.null(t_ext_24h_default) || is.na(t_ext_24h_default)) {
    t_ext_24h_default <- 10  # fallback if parameter not found
  }
  
  # Extract the date (without time) for each row - use local variable to avoid modifying Main_df
  row_dates <- as.Date(Main_df$time)
  
  # Calculate the mean Text for each date
  daily_mean_text <- tapply(Main_df$Text, row_dates, mean, na.rm = TRUE)
  
  # Create lookup for previous day values (vectorized approach)
  # Get all unique dates and their previous dates
  unique_dates <- sort(unique(row_dates))
  previous_dates <- unique_dates - 1
  
  # Create a named vector mapping each date to its previous day's mean
  previous_day_means <- rep(t_ext_24h_default, length(unique_dates))
  names(previous_day_means) <- as.character(unique_dates)
  
  # For dates that have previous day data, use the calculated mean
  has_previous <- as.character(previous_dates) %in% names(daily_mean_text)
  previous_day_means[has_previous] <- daily_mean_text[as.character(previous_dates[has_previous])]
  
  # Assign T_ext_24h using vectorized match
  Main_df$T_ext_24h <- previous_day_means[as.character(row_dates)]
  
  cat("T_ext_24h recalculated based on previous day Text average\n")
  cat("Default value used when no previous day:", t_ext_24h_default, "\n")
  rm(t_ext_24h_default, row_dates, daily_mean_text, unique_dates, previous_dates,
     previous_day_means, has_previous)
}
