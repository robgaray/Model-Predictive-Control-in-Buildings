# -------------------------------------------------------------
# Script: load_22_flexibility_generation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads market-aware flexibility generation parameters from
# 22_Flexibility_generation_parameters.csv (Max_shift_hours, P_advance,
# P_delay, P_event_base, decay_rate), validates values against
# Parameter_config.csv, and stores the result in
# parameters$flexibility_generation. Only consumed by
# flexibility_generation.R when Complex_Market_Config == "yes".
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 22_Flexibility_generation_parameters.csv and check every value
  # against the types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$flexibility_generation_file, "22_Flexibility_generation_parameters.csv",
    validation_config
  )

  parameters$flexibility_generation <- lapply(raw_values, as.numeric)
  rm(raw_values)

  cat("Flexibility generation parameters loaded\n")
}
