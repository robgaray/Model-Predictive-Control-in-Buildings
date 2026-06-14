# -------------------------------------------------------------
# Script: load_12_control_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads control parameters from 12_Control_parameters.csv,
# validates raw values against Parameter_config.csv, calls
# load_control_parameters() for structured loading, and stores
# the result in parameters$control.
# control_type is read directly as text ("modes" or "setpoints")
# and validated strictly; any other value stops execution.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  raw_df     <- read.csv(paths$control_file, comment.char = "#", stringsAsFactors = FALSE)
  raw_values <- as.list(raw_df$value)
  names(raw_values) <- trimws(raw_df$parameter)
  rm(raw_df)

  validate_parameter_config(raw_values, "12_Control_parameters.csv", validation_config)
  rm(raw_values)

  parameters$control <- load_control_parameters(paths$control_file)

  if (!parameters$control$control_type %in% c("modes", "setpoints")) {
    stop(paste0(
      "Invalid control_type: '", parameters$control$control_type,
      "'. Must be 'modes' or 'setpoints'."
    ))
  }

  if (is.null(parameters$control$Deadband)) {
    stop("Deadband not found in control parameters")
  }

  cat("Control parameters loaded\n")
}
