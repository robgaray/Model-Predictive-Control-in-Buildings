# -------------------------------------------------------------
# Script: load_21_energy_price_parameters.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads energy market price discount/premium parameters from
# 21_Energy_price_parameters.csv, validates values against
# Parameter_config.csv, and stores the result in
# parameters$energy_price. These parameters apply only to the four
# energy buy/sell price signals (Elec_unit_cost_import_buy/sell,
# _export_buy/sell), not to flexibility - see
# 01_Agent_Comments/20260720_Plan_Redefinicion_Precios_Energia.md.
# Not yet consumed by any derivation script (Fase 3 of that plan);
# energy_price_signals_setup.R still derives the four energy signals
# as interim buy/sell duplicates.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  # read_and_validate_parameter_csv is called to read
  # 21_Energy_price_parameters.csv and check every value against the
  # types/ranges defined in Parameter_config.csv.
  raw_values <- read_and_validate_parameter_csv(
    paths$energy_price_file, "21_Energy_price_parameters.csv", validation_config
  )

  parameters$energy_price <- lapply(raw_values, as.numeric)
  rm(raw_values)

  cat("Energy price parameters loaded\n")
}
