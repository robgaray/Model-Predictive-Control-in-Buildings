# -------------------------------------------------------------
# Script: load_energy_prices_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads Energy_Prices_df (energy and flexibility market price input
# data) from disk and validates it before it is used by
# assemble_main_df.R.
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
#                            Flex_Probab_down, Flex_Probab_up.
#   energy_prices_step_sec : Numeric. Detected step (seconds) of
#                            Energy_Prices_df$time.
# -------------------------------------------------------------
# Code outline
# 1. Check that Energy_Prices_df.rds exists and read it
# 2. Validate required columns are present and numeric
# 3. Validate the time grid (equispaced, compatible with Main_df's
#    resolution)
# 4. Validate column ranges against Validation_Energy_Prices_df.csv
# -------------------------------------------------------------
# Usage instructions
# source(file.path("30_Simulation", "04_Scripts", "load_energy_prices_df.R"))
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by assemble_main_df.R while it builds
#   Main_df out of the input series.
# -------------------------------------------------------------

{
  # initialize_simulator() does not require the input series, so that
  # the simulator can be loaded without them. Their existence is
  # checked here, where they are read.
  if (!file.exists(paths$energy_prices_file)) {
    stop("Missing required file:\n", paths$energy_prices_file)
  }
  Energy_Prices_df <- readRDS(paths$energy_prices_file)

  required_cols <- c("time", "Elec_unit_cost_buy", "Elec_unit_cost_distribution",
                      "Flex_unit_cost_down_com", "Flex_unit_cost_down_exec",
                      "Flex_unit_cost_up_com", "Flex_unit_cost_up_exec",
                      "Flex_Probab_down", "Flex_Probab_up")
  missing_cols  <- setdiff(required_cols, names(Energy_Prices_df))
  if (length(missing_cols) > 0) {
    stop("Energy_Prices_df.rds is missing required columns: ",
         paste(missing_cols, collapse = ", "))
  }

  # validate_time_grid is called to check that Energy_Prices_df$time
  # is an equispaced grid compatible with Main_df's own resolution,
  # and to return its detected step in seconds.
  energy_prices_step_sec <- validate_time_grid(
    time                = Energy_Prices_df$time,
    file_name           = "Energy_Prices_df.rds",
    main_resolution_sec = parameters$computing$main_resolution_sec
  )

  energy_prices_validation_config <- read.csv(
    paths$energy_prices_validation_file,
    comment.char     = "#",
    stringsAsFactors = FALSE
  )
  # validate_dataframe_config is called to check every column of
  # Energy_Prices_df against the ranges defined in
  # Validation_Energy_Prices_df.csv.
  validate_dataframe_config(Energy_Prices_df, "Energy_Prices_df.rds", energy_prices_validation_config)
  rm(list = c("energy_prices_validation_config", "required_cols",
              "missing_cols"))
}
