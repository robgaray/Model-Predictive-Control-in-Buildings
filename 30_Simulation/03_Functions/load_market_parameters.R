# -------------------------------------------------------------
# Function: load_market_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function reads market-related parameters from
# 15_Market_config.csv and returns them as a validated named list.
# -------------------------------------------------------------

load_market_parameters <- function(market_file) {

  df <- read.csv(
    market_file,
    comment.char      = "#",
    stringsAsFactors  = FALSE
  )

  values <- as.list(df$value)
  names(values) <- trimws(df$parameter)
  rm(df)

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
    optimization_aim_piloting         = value_chr("optimization_aim_piloting")
  )

  if (is.na(market_parameters$market_resolution) ||
      market_parameters$market_resolution <= 0) {
    stop("market_resolution must be a numeric value > 0")
  }

  if (market_parameters$Optimization_horizon_scheduling < 2) {
    market_parameters$Optimization_horizon_scheduling <- 2
    cat("WARNING: Optimization_horizon_scheduling has been set to 2 hours (minimum allowed value)\n")
  }
  if (market_parameters$Optimization_horizon_scheduling > 72) {
    market_parameters$Optimization_horizon_scheduling <- 72
    cat("WARNING: Optimization_horizon_scheduling has been set to 72 hours (maximum allowed value)\n")
  }

  if (market_parameters$Implementation_horizon_scheduling < 2) {
    market_parameters$Implementation_horizon_scheduling <- 2
    cat("WARNING: Implementation_horizon_scheduling has been set to 2 hours (minimum allowed value)\n")
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
  if (market_parameters$Optimization_horizon_piloting > 24) {
    market_parameters$Optimization_horizon_piloting <- 24
    cat("WARNING: Optimization_horizon_piloting has been set to 24 hours (maximum allowed value)\n")
  }

  if (market_parameters$Implementation_horizon_piloting < 1) {
    market_parameters$Implementation_horizon_piloting <- 1
    cat("WARNING: Implementation_horizon_piloting has been set to 1 hour (minimum allowed value)\n")
  }
  if (market_parameters$Implementation_horizon_piloting > 12) {
    market_parameters$Implementation_horizon_piloting <- 12
    cat("WARNING: Implementation_horizon_piloting has been set to 12 hours (maximum allowed value)\n")
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
  if (market_parameters$Anticipation_piloting > 6) {
    market_parameters$Anticipation_piloting <- 6
    cat("WARNING: Anticipation_piloting has been set to 6 hours (maximum allowed value)\n")
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
    market_parameters$optimization_aim_scheduling <- "1"
  }
  if (is.na(market_parameters$optimization_aim_piloting) ||
      market_parameters$optimization_aim_piloting == "") {
    market_parameters$optimization_aim_piloting <- "1"
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
