# -------------------------------------------------------------
# Function: load_market_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function structures the already-parsed market-related
# parameters (as read and validated by
# read_and_validate_parameter_csv() from 03_Market_config.csv) into a
# validated named list, clamping the six horizons to the bounds
# declared in Validation_Market_Config.csv.
# -------------------------------------------------------------
# Why the horizons are clamped and not rejected
# A horizon longer than the market process can resolve, or shorter
# than one hour, would leave the optimization without a well-formed
# window rather than with a wrong number. The bounds are therefore
# applied, not merely reported, and the console states every value
# that was moved. The bounds themselves live in
# Validation_Market_Config.csv: this function holds none of them.
# -------------------------------------------------------------
# Inputs
# values : Named list. Raw parameter/value pairs for market
#          parameters, as returned by read_and_validate_parameter_csv().
# market_validation_config : Data frame. Content of
#          Validation_Market_Config.csv, holding the admissible bounds
#          of the six optimization/implementation/anticipation
#          horizons.
# -------------------------------------------------------------
# Outputs
# Named list with the elements:
#   - market_resolution
#   - Complex_Market_Config
#   - Optimization_horizon_scheduling
#   - Implementation_horizon_scheduling
#   - Anticipation_scheduling
#   - optimization_aim_scheduling
#   - Optimization_horizon_piloting
#   - Implementation_horizon_piloting
#   - Anticipation_piloting
#   - optimization_aim_piloting
#   - Max_flex_periods_day
#   - Max_flex_com_price
#   - Max_flex_exec_price
#   - Max_flex_period_duration
#   - Max_flex_probability_down
#   - Max_flex_probability_up
# -------------------------------------------------------------
# Usage instructions
# params <- load_market_parameters(raw_values, market_validation_config)
# -------------------------------------------------------------
# Code outline
# 1. Separate the text parameters from the numeric ones.
# 2. Coerce the numeric ones and name each of them.
# 3. Return them as the market sub-list.
# -------------------------------------------------------------
# Where this function/script is used
# Called by load_03_market_config.R.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - The relations between horizons (implementation not longer than
#     optimization, anticipation shorter than implementation) are
#     structural, not numeric limits, and are applied here rather than
#     read from the validation file.
# -------------------------------------------------------------
# functions/scripts called
# get_validation_bounds()
# -------------------------------------------------------------

load_market_parameters <- function(values, market_validation_config) {

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
    Max_flex_probability_down         = value_num("Max_flex_probability_down"),
    Max_flex_probability_up           = value_num("Max_flex_probability_up")
  )

  if (is.na(market_parameters$market_resolution) ||
      market_parameters$market_resolution <= 0) {
    stop("market_resolution must be a numeric value > 0")
  }

  # clamp_horizon() is defined here, next to the parameters it acts on,
  # as the single place where a horizon is brought inside the bounds of
  # Validation_Market_Config.csv. It is applied to the six horizons in
  # the two blocks below, each interleaved with the structural relations
  # between them.
  clamp_horizon <- function(parameter_name, value) {

    # get_validation_bounds is called to read this horizon's admissible
    # bounds out of the validation table, so that no limit is written
    # in this function.
    bounds <- get_validation_bounds(
      market_validation_config, "03_Market_config.csv", parameter_name
    )

    if (!is.na(bounds$min) && value < bounds$min) {
      cat("WARNING:", parameter_name, "has been set to", bounds$min,
          "h (minimum allowed value)\n")
      return(bounds$min)
    }

    if (!is.na(bounds$max) && value > bounds$max) {
      cat("WARNING:", parameter_name, "has been set to", bounds$max,
          "h (maximum allowed value)\n")
      return(bounds$max)
    }

    return(value)
  }

  market_parameters$Optimization_horizon_scheduling <- clamp_horizon(
    "Optimization_horizon_scheduling",
    market_parameters$Optimization_horizon_scheduling
  )
  market_parameters$Implementation_horizon_scheduling <- clamp_horizon(
    "Implementation_horizon_scheduling",
    market_parameters$Implementation_horizon_scheduling
  )

  if (market_parameters$Implementation_horizon_scheduling >
      market_parameters$Optimization_horizon_scheduling) {
    market_parameters$Implementation_horizon_scheduling <-
      market_parameters$Optimization_horizon_scheduling
    cat("WARNING: Implementation_horizon_scheduling has been set equal to Optimization_horizon_scheduling\n")
  }

  market_parameters$Anticipation_scheduling <- clamp_horizon(
    "Anticipation_scheduling",
    market_parameters$Anticipation_scheduling
  )
  if (market_parameters$Anticipation_scheduling >=
      market_parameters$Implementation_horizon_scheduling) {
    market_parameters$Anticipation_scheduling <- max(
      0,
      market_parameters$Implementation_horizon_scheduling - 1
    )
    cat("WARNING: Anticipation_scheduling adjusted to be lower than Implementation_horizon_scheduling\n")
  }

  market_parameters$Optimization_horizon_piloting <- clamp_horizon(
    "Optimization_horizon_piloting",
    market_parameters$Optimization_horizon_piloting
  )
  market_parameters$Implementation_horizon_piloting <- clamp_horizon(
    "Implementation_horizon_piloting",
    market_parameters$Implementation_horizon_piloting
  )

  if (market_parameters$Implementation_horizon_piloting >
      market_parameters$Optimization_horizon_piloting) {
    market_parameters$Implementation_horizon_piloting <-
      market_parameters$Optimization_horizon_piloting
    cat("WARNING: Implementation_horizon_piloting has been set equal to Optimization_horizon_piloting\n")
  }

  market_parameters$Anticipation_piloting <- clamp_horizon(
    "Anticipation_piloting",
    market_parameters$Anticipation_piloting
  )
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
