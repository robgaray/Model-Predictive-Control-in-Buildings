# -------------------------------------------------------------
# Script: load_16_market_config_scheduling.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads the scheduling market configuration table from
# 16_Market_config_scheduling.csv, validates required columns
# and non-empty content, and stores the data frame in
# parameters$market_config_scheduling.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  # load_market_config_table is called to read
  # 16_Market_config_scheduling.csv, validate its required columns,
  # its non-empty content and that no two Scheduling markets clear in
  # the same market slot, and return it as a data frame.
  parameters$market_config_scheduling <- load_market_config_table(
    paths$market_config_scheduling_file, "16_Market_config_scheduling.csv",
    parameters$market$market_resolution
  )

  cat("Market config scheduling loaded\n")
}
