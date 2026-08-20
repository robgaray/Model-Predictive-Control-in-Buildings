# -------------------------------------------------------------
# Script: load_17_market_config_piloting.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads the piloting market configuration table from
# 17_Market_config_piloting.csv, validates required columns
# and non-empty content, and stores the data frame in
# parameters$market_config_piloting.
# Sourced from load_all_parameters.R.
# -------------------------------------------------------------

{
  # load_market_config_table is called to read
  # 17_Market_config_piloting.csv, validate its required columns,
  # its non-empty content and that no two Piloting markets clear in
  # the same market slot, and return it as a data frame.
  parameters$market_config_piloting <- load_market_config_table(
    paths$market_config_piloting_file, "17_Market_config_piloting.csv",
    parameters$market$market_resolution
  )

  cat("Market config piloting loaded\n")
}
