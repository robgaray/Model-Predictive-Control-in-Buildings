# -------------------------------------------------------------
# Script: load_18_reward_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads reward parameters from 18_Reward_parameters.csv,
# validates values against Parameter_config.csv, and stores
# the result in parameters$reward.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 18_Reward_parameters.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$reward_file, "18_Reward_parameters.csv", validation_config
  )

  parameters$reward <- lapply(raw_values, as.numeric)
  rm(raw_values)

  cat("Reward parameters loaded\n")
}
