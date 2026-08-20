# -------------------------------------------------------------
# Function: load_market_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function structures the already-parsed market-related
# parameters (as read and validated by
# read_and_validate_parameter_csv() from 15_Market_config.csv) into a
# validated named list, clamping out-of-range values.
# -------------------------------------------------------------
# Inputs
# values : Named list. Raw parameter/value pairs for market
#          parameters, as returned by read_and_validate_parameter_csv().
# -------------------------------------------------------------
# Outputs
# Named list with market_resolution, Complex_Market_Config,
# Optimization_horizon_scheduling, Implementation_horizon_scheduling,
# Anticipation_scheduling, optimization_aim_scheduling,
# Optimization_horizon_piloting, Implementation_horizon_piloting,
# Anticipation_piloting, optimization_aim_piloting,
# Max_flex_periods_day, Max_flex_com_price, Max_flex_exec_price,
# Max_flex_period_duration, Max_flex_probability.
# -------------------------------------------------------------
# Usage instructions
# params <- load_market_parameters(raw_values)
# -------------------------------------------------------------
# Where this function/script is used
# Called by load_15_market_config.R.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

load_market_parameters <- function(values) {

  value_num <- function(name) {
    if (is.null(values[[name]])) {
      return(NA_real_)
    }
    as.numeric(trimws(as.character(values[[name]])))
  }

  value_chr <- function(name) {
    if (is.null(values[[name]])) {
      return(NA_character_)
    }
    trimws(as.character(values[[name]]))
  }

  market_parameters <- list(
    market_resolution                 = value_num("market_resolution"),
    Complex_Market_Config             = value_chr("Complex_Market_Config"),
    Optimization_horizon_scheduling   = value_num("Optimization_horizon_scheduling"),
    Implementation_horizon_scheduling = value_num("Implementation_horizon_scheduling"),
    Anticipation_scheduling           = value_num("Anticipation_scheduling"),
    optimization_aim_scheduling       = value_chr("optimization_aim_scheduling"),
    Optimization_horizon_piloting     = value_num("Optimization_horizon_piloting"),
    Implementation_horizon_piloting   = value_num("Implementation_horizon_piloting"),
    Anticipation_piloting             = value_num("Anticipation_piloting"),
    optimization_aim_piloting         = value_chr("optimization_aim_piloting"),
    Max_flex_periods_day              = value_num("Max_flex_periods_day"),
    Max_flex_com_price                = value_num("Max_flex_com_price"),
    Max_flex_exec_price               = value_num("Max_flex_exec_price"),
    Max_flex_period_duration          = value_num("Max_flex_period_duration"),
    Max_flex_probability              = value_num("Max_flex_probability")
  )

  if (is.na(market_parameters$market_resolution) ||
      market_parameters$market_resolution <= 0) {
    stop("market_resolution must be a numeric value > 0")
  }

  if (market_parameters$Optimization_horizon_scheduling < 1) {
    market_parameters$Optimization_horizon_scheduling <- 1
    cat("WARNING: Optimization_horizon_scheduling has been set to 1 hour (minimum allowed value)\n")
  }
  if (market_parameters$Optimization_horizon_scheduling > 72) {
    market_parameters$Optimization_horizon_scheduling <- 72
    cat("WARNING: Optimization_horizon_scheduling has been set to 72 hours (maximum allowed value)\n")
  }

  if (market_parameters$Implementation_horizon_scheduling < 1) {
    market_parameters$Implementation_horizon_scheduling <- 1
    cat("WARNING: Implementation_horizon_scheduling has been set to 1 hour (minimum allowed value)\n")
  }
  if (market_parameters$Implementation_horizon_scheduling > 48) {
    market_parameters$Implementation_horizon_scheduling <- 48
    cat("WARNING: Implementation_horizon_scheduling has been set to 48 hours (maximum allowed value)\n")
  }

  if (market_parameters$Implementation_horizon_scheduling >
      market_parameters$Optimization_horizon_scheduling) {
    market_parameters$Implementation_horizon_scheduling <-
      market_parameters$Optimization_horizon_scheduling
    cat("WARNING: Implementation_horizon_scheduling has been set equal to Optimization_horizon_scheduling\n")
  }

  if (market_parameters$Anticipation_scheduling < 0) {
    market_parameters$Anticipation_scheduling <- 0
    cat("WARNING: Anticipation_scheduling has been set to 0 hours (minimum allowed value)\n")
  }
  if (market_parameters$Anticipation_scheduling > 24) {
    market_parameters$Anticipation_scheduling <- 24
    cat("WARNING: Anticipation_scheduling has been set to 24 hours (maximum allowed value)\n")
  }
  if (market_parameters$Anticipation_scheduling >=
      market_parameters$Implementation_horizon_scheduling) {
    market_parameters$Anticipation_scheduling <- max(
      0,
      market_parameters$Implementation_horizon_scheduling - 1
    )
    cat("WARNING: Anticipation_scheduling adjusted to be lower than Implementation_horizon_scheduling\n")
  }

  if (market_parameters$Optimization_horizon_piloting < 1) {
    market_parameters$Optimization_horizon_piloting <- 1
    cat("WARNING: Optimization_horizon_piloting has been set to 1 hour (minimum allowed value)\n")
  }
  if (market_parameters$Optimization_horizon_piloting > 48) {
    market_parameters$Optimization_horizon_piloting <- 48
    cat("WARNING: Optimization_horizon_piloting has been set to 48 hours (maximum allowed value)\n")
  }

  if (market_parameters$Implementation_horizon_piloting < 1) {
    market_parameters$Implementation_horizon_piloting <- 1
    cat("WARNING: Implementation_horizon_piloting has been set to 1 hour (minimum allowed value)\n")
  }
  if (market_parameters$Implementation_horizon_piloting > 24) {
    market_parameters$Implementation_horizon_piloting <- 24
    cat("WARNING: Implementation_horizon_piloting has been set to 24 hours (maximum allowed value)\n")
  }

  if (market_parameters$Implementation_horizon_piloting >
      market_parameters$Optimization_horizon_piloting) {
    market_parameters$Implementation_horizon_piloting <-
      market_parameters$Optimization_horizon_piloting
    cat("WARNING: Implementation_horizon_piloting has been set equal to Optimization_horizon_piloting\n")
  }

  if (market_parameters$Anticipation_piloting < 0) {
    market_parameters$Anticipation_piloting <- 0
    cat("WARNING: Anticipation_piloting has been set to 0 hours (minimum allowed value)\n")
  }
  if (market_parameters$Anticipation_piloting > 24) {
    market_parameters$Anticipation_piloting <- 24
    cat("WARNING: Anticipation_piloting has been set to 24 hours (maximum allowed value)\n")
  }
  if (market_parameters$Anticipation_piloting >=
      market_parameters$Implementation_horizon_piloting) {
    market_parameters$Anticipation_piloting <- max(
      0,
      market_parameters$Implementation_horizon_piloting - 1
    )
    cat("WARNING: Anticipation_piloting adjusted to be lower than Implementation_horizon_piloting\n")
  }

  if (is.na(market_parameters$optimization_aim_scheduling) ||
      market_parameters$optimization_aim_scheduling == "") {
    stop("optimization_aim_scheduling must not be empty")
  }
  if (is.na(market_parameters$optimization_aim_piloting) ||
      market_parameters$optimization_aim_piloting == "") {
    stop("optimization_aim_piloting must not be empty")
  }

  complex_market_config <- tolower(trimws(as.character(
    market_parameters$Complex_Market_Config
  )))
  if (is.na(complex_market_config) || complex_market_config == "") {
    complex_market_config <- "no"
  }
  if (!complex_market_config %in% c("yes", "no")) {
    stop("Complex_Market_Config must be 'yes' or 'no'")
  }
  market_parameters$Complex_Market_Config <- complex_market_config

  str(market_parameters)
  cat("market parameters loaded\n")

  return(market_parameters)
}
