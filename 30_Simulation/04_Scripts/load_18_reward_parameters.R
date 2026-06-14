# -------------------------------------------------------------
# Script: load_18_reward_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads reward parameters from 18_Reward_parameters.csv,
# validates values against Parameter_config.csv, and stores
# the result in parameters$reward.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  raw_df     <- read.csv(paths$reward_file, comment.char = "#", stringsAsFactors = FALSE)
  raw_values <- as.list(raw_df$value)
  names(raw_values) <- trimws(raw_df$parameter)
  rm(raw_df)

  validate_parameter_config(raw_values, "18_Reward_parameters.csv", validation_config)

  parameters$reward <- lapply(raw_values, as.numeric)
  rm(raw_values)

  cat("Reward parameters loaded\n")
}
