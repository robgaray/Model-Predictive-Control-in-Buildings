# -------------------------------------------------------------
# Script: load_energy_prices_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads Energy_Prices_df (energy and flexibility market price input
# data) from disk and validates it before it is used by
# assemble_main_df.R. See
# 01_Agent_Comments/20260722b_Plan_Señales_por_Procedencia.md, Part E,
# for the rationale of each protection.
# -------------------------------------------------------------
# Inputs
#   paths$energy_prices_file            : Character. Path to
#                                         Energy_Prices_df.rds.
#   paths$energy_prices_validation_file : Character. Path to
#                                         Validation_Energy_Prices_df.csv.
# -------------------------------------------------------------
# Outputs
#   Energy_Prices_df       : Data frame. Columns: time (POSIXct),
#                            Elec_unit_cost_buy, Elec_unit_cost_distribution,
#                            Flex_unit_cost_down_com, Flex_unit_cost_down_exec,
#                            Flex_unit_cost_up_com, Flex_unit_cost_up_exec,
#                            Flex_Probab.
#   energy_prices_step_sec : Numeric. Detected step (seconds) of
#                            Energy_Prices_df$time.
# -------------------------------------------------------------
# Code outline
# 1. Read Energy_Prices_df.rds
# 2. Validate required columns are present and numeric
# 3. Validate the time grid (equispaced, compatible with Main_df's
#    resolution)
# 4. Validate column ranges against Validation_Energy_Prices_df.csv
# -------------------------------------------------------------
# Usage
# source(file.path("30_Simulation", "04_Scripts", "load_energy_prices_df.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by assemble_main_df.R.
# -------------------------------------------------------------
# functions/scripts called
#   validate_time_grid(), validate_dataframe_config()
#   -- from 30_Simulation/03_Functions/
# -------------------------------------------------------------

{
  Energy_Prices_df <- readRDS(paths$energy_prices_file)

  required_cols <- c("time", "Elec_unit_cost_buy", "Elec_unit_cost_distribution",
                      "Flex_unit_cost_down_com", "Flex_unit_cost_down_exec",
                      "Flex_unit_cost_up_com", "Flex_unit_cost_up_exec",
                      "Flex_Probab")
  missing_cols  <- setdiff(required_cols, names(Energy_Prices_df))
  if (length(missing_cols) > 0) {
    stop("Energy_Prices_df.rds is missing required columns: ",
         paste(missing_cols, collapse = ", "))
  }

  # validate_time_grid is called to check that Energy_Prices_df$time
  # is an equispaced grid compatible with Main_df's own resolution,
  # and to return its detected step in seconds.
  energy_prices_step_sec <- validate_time_grid(Energy_Prices_df$time, "Energy_Prices_df.rds")

  energy_prices_validation_config <- read.csv(
    paths$energy_prices_validation_file,
    comment.char     = "#",
    stringsAsFactors = FALSE
  )
  # validate_dataframe_config is called to check every column of
  # Energy_Prices_df against the ranges defined in
  # Validation_Energy_Prices_df.csv.
  validate_dataframe_config(Energy_Prices_df, "Energy_Prices_df.rds", energy_prices_validation_config)
  rm(energy_prices_validation_config, required_cols, missing_cols)

  cat("Energy_Prices_df loaded and validated:", nrow(Energy_Prices_df), "rows, step =",
      energy_prices_step_sec, "s\n")
}
