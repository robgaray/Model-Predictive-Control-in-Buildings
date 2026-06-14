# -------------------------------------------------------------
# Script: load_all_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Master parameter-loading script. Replaces data_model_parameters.R,
# control_optimization_parameters.R, and market_config_parameters.R.
# Executes one sub-script per configuration file, each of which
# validates the loaded values against Parameter_config.csv.
# -------------------------------------------------------------
# Inputs
#   paths
#     List. Paths set by initialization.R / initialization_SCC.R.
# -------------------------------------------------------------
# Outputs
#   Main_df    : Data frame. Main simulation data frame (full year,
#                not subsetted).
#   parameters : List with sub-lists model, physical_properties,
#                use_patterns, reward, forecast, control, optimization, market,
#                market_config_scheduling, market_config_piloting,
#                debug_and_config, setpoint_modes, needed_cols.
# -------------------------------------------------------------
# Code outline
#   1.  Load validation configuration (Parameter_config.csv)
#   2.  Load Main_df from RDS, parse time, validate structure
#   3.  Initialise empty parameters list
#   4.  Source sub-scripts (one per CSV file)
#   5.  Load needed-columns list
#   6.  Recalculate T_ext_24h from previous-day averages
# -------------------------------------------------------------
# Usage
#   source(file.path("30_Simulation", "04_Scripts", "load_all_parameters.R"))
# -------------------------------------------------------------
# Where this script is used
#   Sourced by Main.R and Main_SCC.R after initialization.
# -------------------------------------------------------------
# Functions / scripts called
#   validate_parameter_config(), validate_Main_df(),
#   validate_physical_properties(), validate_model_parameters(),
#   compute_Rvent(), load_control_parameters(),
#   load_optimization_parameters(), load_market_parameters(),
#   load_debug_and_config_parameters()  -- from 30_Simulation/03_Functions/
#   load_03_physical_properties.R, load_04_use_patterns.R,
#   load_11_model_parameters.R,
#   load_12_control_parameters.R, load_13_modes_setpoints.R,
#   load_14_optimization_parameters.R, load_15_market_config.R,
#   load_16_market_config_scheduling.R,
#   load_17_market_config_piloting.R, load_18_reward_parameters.R,
#   load_19_forecast_parameters.R, load_30_debug_and_config.R
#                                    -- from 30_Simulation/04_Scripts/
# -------------------------------------------------------------

# -----------------------------------------------------------
# 1. Load validation configuration
# -----------------------------------------------------------
{
  validation_config <- read.csv(
    paths$parameter_validation_file,
    comment.char     = "#",
    stringsAsFactors = FALSE
  )
}

# -----------------------------------------------------------
# 2. Load Main_df from RDS, parse time, validate structure
# -----------------------------------------------------------
{
  Main_df <- readRDS(paths$main_file)

  if (!inherits(Main_df$time, "POSIXct")) {
    parsed_time <- as.POSIXct(Main_df$time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
    na_times    <- is.na(parsed_time)
    if (any(na_times)) {
      parsed_time[na_times] <- as.POSIXct(Main_df$time[na_times],
                                           format = "%Y-%m-%d", tz = "UTC")
    }
    Main_df$time <- parsed_time
    rm(parsed_time, na_times)
    cat("Converted time column from string to POSIXct\n")
  }

  Main_df$Occupancy  <- 0L
  Main_df$Scheduling <- 0L
  validate_Main_df(Main_df)
}

# -----------------------------------------------------------
# 3. Initialise parameters list
# -----------------------------------------------------------
{
  parameters <- list()
}

# -----------------------------------------------------------
# 4. Source one sub-script per configuration file
# -----------------------------------------------------------
{
  source(file.path("30_Simulation", "04_Scripts", "load_03_physical_properties.R"))
  source(file.path("30_Simulation", "04_Scripts", "load_11_model_parameters.R"))
  source(file.path("30_Simulation", "04_Scripts", "load_04_use_patterns.R"))
  source(file.path("30_Simulation", "04_Scripts", "load_18_reward_parameters.R"))
  source(file.path("30_Simulation", "04_Scripts", "load_19_forecast_parameters.R"))
  source(file.path("30_Simulation", "04_Scripts", "load_12_control_parameters.R"))
  source(file.path("30_Simulation", "04_Scripts", "load_13_modes_setpoints.R"))
  source(file.path("30_Simulation", "04_Scripts", "load_14_optimization_parameters.R"))
  source(file.path("30_Simulation", "04_Scripts", "load_15_market_config.R"))
  source(file.path("30_Simulation", "04_Scripts", "load_16_market_config_scheduling.R"))
  source(file.path("30_Simulation", "04_Scripts", "load_17_market_config_piloting.R"))
  source(file.path("30_Simulation", "04_Scripts", "load_30_debug_and_config.R"))
  rm(validation_config)
}

# -----------------------------------------------------------
# 5. Load needed-columns list
# -----------------------------------------------------------
{
  needed_cols_lines      <- readLines(paths$needed_cols_file)
  parameters$needed_cols <- needed_cols_lines[
    !grepl("^\\s*#", needed_cols_lines) & nzchar(trimws(needed_cols_lines))
  ]
  cat("needed_cols loaded:", length(parameters$needed_cols), "columns\n")
  rm(needed_cols_lines)
}

# -----------------------------------------------------------
# 6. Recalculate T_ext_24h from previous-day averages
# -----------------------------------------------------------
{
  t_ext_24h_default <- parameters$forecast$t_ext_24h_default
  if (is.null(t_ext_24h_default) || is.na(t_ext_24h_default)) {
    stop("t_ext_24h_default is missing\n")
  }

  row_dates       <- as.Date(Main_df$time)
  daily_mean_text <- tapply(Main_df$Text, row_dates, mean, na.rm = TRUE)
  unique_dates    <- sort(unique(row_dates))
  previous_dates  <- unique_dates - 1

  previous_day_means                    <- rep(t_ext_24h_default, length(unique_dates))
  names(previous_day_means)             <- as.character(unique_dates)
  has_previous                          <- as.character(previous_dates) %in% names(daily_mean_text)
  previous_day_means[has_previous]      <- daily_mean_text[as.character(previous_dates[has_previous])]

  Main_df$T_ext_24h <- previous_day_means[as.character(row_dates)]

  cat("T_ext_24h recalculated based on previous day Text average\n")
  cat("Default value used when no previous day:", t_ext_24h_default, "\n")
  rm(t_ext_24h_default, row_dates, daily_mean_text, unique_dates,
     previous_dates, previous_day_means, has_previous)
}
