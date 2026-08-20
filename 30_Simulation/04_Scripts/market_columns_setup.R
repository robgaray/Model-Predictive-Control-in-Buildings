# -------------------------------------------------------------
# Script: market_columns_setup.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Initialises and populates the Sched_* and Pilot_* market
# columns in Main_df using the already-loaded parameters
# (parameters$market, parameters$market_config_scheduling,
# parameters$market_config_piloting).
# Supports two modes:
#   - Basic  (Complex_Market_Config == "no") : deterministic
#     market timeline from optimisation horizons.
#   - Complex (Complex_Market_Config == "yes") : timeline built
#     from the market-config tables. In complex mode, the
#     optimization horizon is computed from end_optimization.
# Sourced from Main.R, after the month/period subset and before
# flexibility_generation.R (price emulation).
# -------------------------------------------------------------
# functions/scripts called
# build_market_timeline()
# -------------------------------------------------------------

# -----------------------------------------------------------
# Initialise / overwrite market columns in Main_df
# -----------------------------------------------------------
{
  market_cols <- c(
    "Sched_Market_Name",
    "Sched_Market_Bid_time",
    "Sched_Market_Period_Begin",
    "Sched_Market_Period_End",
    "Sched_Optimization_Horizon",
    "Sched_Market_Aim",
    "Pilot_Market_Name",
    "Pilot_Market_Bid_time",
    "Pilot_Market_Period_Begin",
    "Pilot_Market_Period_End",
    "Pilot_Optimization_Horizon",
    "Pilot_Market_Aim"
  )

  for (CONT_001 in market_cols) {
    Main_df[[CONT_001]] <- 0
  }
  rm(market_cols, CONT_001)
}

# -----------------------------------------------------------
# Configure Scheduling market values based on Complex_Market_Config
# -----------------------------------------------------------
{
  complex_market_config <- "no"
  if (!is.null(parameters$market$Complex_Market_Config)) {
    complex_market_config <- tolower(trimws(as.character(parameters$market$Complex_Market_Config)))
  }

  if (!complex_market_config %in% c("yes", "no")) {
    stop("Complex_Market_Config must be 'yes' or 'no'")
  }

  time_min <- min(Main_df$time)
  time_max <- max(Main_df$time)

  # build_market_timeline is called to fill in the Sched_* columns of
  # Main_df (market name, bid time, period bounds, optimization
  # horizon, aim) over the full simulation range, in either basic or
  # complex mode as resolved above.
  Main_df <- build_market_timeline(
    role                   = "Sched",
    config_table           = parameters$market_config_scheduling,
    implementation_horizon = parameters$market$Implementation_horizon_scheduling,
    optimization_horizon   = parameters$market$Optimization_horizon_scheduling,
    anticipation           = parameters$market$Anticipation_scheduling,
    optimization_aim       = parameters$market$optimization_aim_scheduling,
    aim_label_energy       = "E",
    aim_label_flex         = "E+F",
    complex_market_config  = complex_market_config,
    time_min               = time_min,
    time_max               = time_max,
    Main_df                = Main_df
  )
}

# -----------------------------------------------------------
# Configure Piloting market values based on Complex_Market_Config
# -----------------------------------------------------------
{
  # build_market_timeline is called again, now to fill in the Pilot_*
  # columns of Main_df, reusing the same complex_market_config/
  # time_min/time_max resolved for the Scheduling market above.
  Main_df <- build_market_timeline(
    role                   = "Pilot",
    config_table           = parameters$market_config_piloting,
    implementation_horizon = parameters$market$Implementation_horizon_piloting,
    optimization_horizon   = parameters$market$Optimization_horizon_piloting,
    anticipation           = parameters$market$Anticipation_piloting,
    optimization_aim       = parameters$market$optimization_aim_piloting,
    aim_label_energy       = "O",
    aim_label_flex         = "O+F",
    complex_market_config  = complex_market_config,
    time_min               = time_min,
    time_max               = time_max,
    Main_df                = Main_df
  )

  rm(complex_market_config, time_min, time_max)
}
