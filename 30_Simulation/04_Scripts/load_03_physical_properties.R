# -------------------------------------------------------------
# Script: load_03_physical_properties.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads physical properties from 03_Physical_properties.csv,
# validates the values against Parameter_config.csv, applies
# the domain-specific validate_physical_properties() check,
# and stores the result in parameters$physical_properties.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  raw_df     <- read.csv(paths$physical_properties_file, comment.char = "#", stringsAsFactors = FALSE)
  raw_values <- as.list(raw_df$value)
  names(raw_values) <- trimws(raw_df$parameter)
  rm(raw_df)

  validate_parameter_config(raw_values, "03_Physical_properties.csv", validation_config)

  parameters$physical_properties <- lapply(raw_values, as.numeric)
  rm(raw_values)

  validate_physical_properties(parameters$physical_properties)

  cat("Physical properties loaded\n")
}
