# -------------------------------------------------------------
# Script: control_optimization_parameters_SCC.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Location: 31_SCC_Simulation/control_optimization_parameters_SCC.R
# -------------------------------------------------------------
# This script applies SCC command-line argument overrides to the
# parameters already loaded by load_all_parameters.R, then subsets
# Main_df by month/period. Market column initialisation is performed
# in Main_SCC.R after price emulation.
# It is sourced from Main_SCC.R.
# All CSV file loading is handled by load_all_parameters.R;
# this script only overrides specific parameter values.
# verbose is always set to FALSE and parallel always to 1 for SCC runs.
# -------------------------------------------------------------
# Command line arguments (positional):
#   1.  population_size
#   2.  iteration_number
#   3.  run_number
#   4.  pcrossover
#   5.  pmutation
#   6.  control_optimization_horizon
#   7.  control_implementation_horizon
#   8.  control_optimization_anticipation
#   9.  control_type  ("modes" or "setpoints")
#   10. optimization_aim
#   11. flexibility_event_length_max
#   12. flexibility_recover_timespan
#   13. thermal_stabilization_timespan
#   14. minimum_flexibility
#   15. flexibility_splits
#   16. Alpha_Service_Min
#   17. month_subset
# -------------------------------------------------------------

# -----------------------------------------------------------
# Read SCC command line parameters
# -----------------------------------------------------------
{
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) < 17) {
    stop(paste0(
      "Expected 17 command line arguments:\n",
      "  population_size, iteration_number, run_number,\n",
      "  pcrossover, pmutation,\n",
      "  control_optimization_horizon, control_implementation_horizon,\n",
      "  control_optimization_anticipation, control_type, optimization_aim,\n",
      "  flexibility_event_length_max, flexibility_recover_timespan,\n",
      "  thermal_stabilization_timespan, minimum_flexibility,\n",
      "  flexibility_splits, Alpha_Service_Min, month_subset\n",
      "Got: ", length(args)
    ))
  }

  scc_run_params <- list(
    population_size                   = as.integer(args[1]),
    iteration_number                  = as.integer(args[2]),
    run_number                        = as.integer(args[3]),
    pcrossover                        = as.numeric(args[4]),
    pmutation                         = as.numeric(args[5]),
    control_optimization_horizon      = as.integer(args[6]),
    control_implementation_horizon    = as.integer(args[7]),
    control_optimization_anticipation = as.integer(args[8]),
    control_type                      = trimws(as.character(args[9])),
    optimization_aim                  = as.integer(args[10]),
    flexibility_event_length_max      = as.numeric(args[11]),
    flexibility_recover_timespan      = as.numeric(args[12]),
    thermal_stabilization_timespan    = as.numeric(args[13]),
    minimum_flexibility               = as.numeric(args[14]),
    flexibility_splits                = as.integer(args[15]),
    Alpha_Service_Min                     = as.numeric(args[16]),
    month_subset                      = as.integer(args[17])
  )

  cat("SCC run parameters:\n")
  print(scc_run_params)
}

# -----------------------------------------------------------
# Override control parameters with SCC command line values
# -----------------------------------------------------------
{
  parameters$control$control_type <- scc_run_params$control_type

  if (!parameters$control$control_type %in% c("modes", "setpoints")) {
    stop(paste0(
      "Invalid control_type: '", parameters$control$control_type,
      "'. Must be 'modes' or 'setpoints'."
    ))
  }

  if (is.null(parameters$control$Deadband)) stop("Deadband not found in control parameters")

  parameters$control$flexibility_event_length_max   <- scc_run_params$flexibility_event_length_max
  parameters$control$flexibility_recover_timespan    <- scc_run_params$flexibility_recover_timespan
  parameters$control$thermal_stabilization_timespan  <- scc_run_params$thermal_stabilization_timespan
  parameters$control$minimum_flexibility             <- scc_run_params$minimum_flexibility
  parameters$control$flexibility_splits              <- scc_run_params$flexibility_splits

  cat("setpoint ranges loaded\n")
}

# -----------------------------------------------------------
# Override optimization and market parameters with SCC values
# -----------------------------------------------------------
{
  parameters$optimization$population_size  <- scc_run_params$population_size
  parameters$optimization$iteration_number <- scc_run_params$iteration_number
  parameters$optimization$run_number       <- scc_run_params$run_number
  parameters$optimization$pcrossover       <- scc_run_params$pcrossover
  parameters$optimization$pmutation        <- scc_run_params$pmutation

  parameters$market$Optimization_horizon_scheduling   <- scc_run_params$control_optimization_horizon
  parameters$market$Implementation_horizon_scheduling <- scc_run_params$control_implementation_horizon
  parameters$market$Anticipation_scheduling           <- scc_run_params$control_optimization_anticipation

  # Resolve optimization_aim using centralized mapping
  parameters$market$optimization_aim_scheduling <- map_optimization_aim(
    aim_raw     = scc_run_params$optimization_aim,
    column_name = "optimization_aim (SCC)",
    row_index   = 0
  )
  parameters$market$optimization_aim_piloting <- parameters$market$optimization_aim_scheduling

  # Set optimization_aim in control based on scheduling aim
  parameters$control$optimization_aim <- parameters$market$optimization_aim_scheduling

  # TODO: temporary implementation - update for all conditions when flexibility
  #       mode is fully integrated with all control_type variants
  if (parameters$control$optimization_aim == "flexibility") {
    parameters$market$Optimization_horizon_scheduling   <- 24
    parameters$market$Implementation_horizon_scheduling <- 24
    parameters$market$Anticipation_scheduling           <- 0
  }

  if (parameters$market$optimization_aim_scheduling == "flexibility" ||
      parameters$market$optimization_aim_piloting == "flexibility") {
    parameters$control$control_type   <- "modes"
    parameters$forecast$forecast_type <- "accurate"
  }

  # Check market resolution consistency
  if ((parameters$market$Optimization_horizon_scheduling * 60) %%
      parameters$market$market_resolution != 0) {
    stop("control_optimization_horizon must be divisible by market_resolution")
  }

  str(parameters$optimization)
  cat("optimization parameters loaded\n")
  cat("optimization aim:", parameters$control$optimization_aim, "\n")
}

# -----------------------------------------------------------
# Override reward parameters
# -----------------------------------------------------------
{
  parameters$reward$Alpha_Service_Min <- scc_run_params$Alpha_Service_Min
  cat("Alpha_Service_Min:", parameters$reward$Alpha_Service_Min, "\n")
}

# -----------------------------------------------------------
# Override debug and configuration parameters
# -----------------------------------------------------------
{
  # Override month_subset with SCC command line parameter
  parameters$debug_and_config$month_subset <- scc_run_params$month_subset

  # SCC mandatory overrides: verbose always FALSE, parallel always 1
  parameters$debug_and_config$verbose  <- FALSE
  parameters$debug_and_config$parallel <- 1
}

# -----------------------------------------------------------
# Subset Main_df by month / period
# -----------------------------------------------------------
{
  month_subset  <- parameters$debug_and_config$month_subset
  period_subset <- parameters$debug_and_config$period_subset

  if (!is.null(month_subset) && month_subset != 0) {
    Main_df <- Main_df[month(Main_df$time) == month_subset, ]
    cat("Month ", month_subset, " selected\n")
  } else {
    cat("Full year selected\n")
  }

  if (!is.null(period_subset) && period_subset > nrow(Main_df)) {
    period_subset <- nrow(Main_df)
  }

  if (!is.null(period_subset) && period_subset != 0) {
    Main_df <- Main_df[1:period_subset, ]
  }
  rm(month_subset, period_subset)
}
