# -------------------------------------------------------------
# Script: load_15_market_config.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads market configuration from 15_Market_config.csv,
# validates raw values against Parameter_config.csv, calls
# load_market_parameters() for structured loading with internal
# clamping logic, resolves optimization aims to text labels
# ("energy"/"flexibility") via map_optimization_aim(),
# sets parameters$control$optimization_aim, and handles the
# flexibility mode override (forces "modes" control type and
# "accurate" forecast when flexibility optimization is active).
# Stores the result in parameters$market.
# Sourced from load_all_parameters.R.
# Requires parameters$control and parameters$forecast to be
# already loaded.
# -------------------------------------------------------------

{
  raw_df     <- read.csv(paths$market_file, comment.char = "#", stringsAsFactors = FALSE)
  raw_values <- as.list(raw_df$value)
  names(raw_values) <- trimws(raw_df$parameter)
  rm(raw_df)

  validate_parameter_config(raw_values, "15_Market_config.csv", validation_config)
  rm(raw_values)

  parameters$market <- load_market_parameters(paths$market_file)

  # Resolve optimization_aim_scheduling using centralized mapping
  parameters$market$optimization_aim_scheduling <- map_optimization_aim(
    aim_raw     = parameters$market$optimization_aim_scheduling,
    column_name = "optimization_aim_scheduling",
    row_index   = 0
  )

  # Resolve optimization_aim_piloting using centralized mapping
  parameters$market$optimization_aim_piloting <- map_optimization_aim(
    aim_raw     = parameters$market$optimization_aim_piloting,
    column_name = "optimization_aim_piloting",
    row_index   = 0
  )

  # Set optimization_aim in control based on scheduling aim
  parameters$control$optimization_aim <- parameters$market$optimization_aim_scheduling

  # Validate market resolution divisibility
  if ((parameters$market$Optimization_horizon_scheduling * 60) %%
      parameters$market$market_resolution != 0) {
    stop("Optimization_horizon_scheduling must be divisible by market_resolution")
  }

  # TODO: temporary implementation - update for all conditions when flexibility
  #       mode is fully integrated with all control_type variants
  if (parameters$market$optimization_aim_scheduling == "flexibility" ||
      parameters$market$optimization_aim_piloting == "flexibility") {
    parameters$control$control_type   <- "modes"
    parameters$forecast$forecast_type <- "accurate"
  }

  str(parameters$optimization)
  cat("Market configuration loaded\n")
  cat("optimization aims: scheduling=",
      parameters$market$optimization_aim_scheduling,
      ", piloting=",
      parameters$market$optimization_aim_piloting, "\n", sep = "")
}
