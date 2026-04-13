# -------------------------------------------------------------
# Script: control_optimization_parameters_SCC.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Location: 02_SCC_simulation/control_optimization_parameters_SCC.R
# -------------------------------------------------------------
# This script loads the control and optimization parameters for
# supercomputer cluster (SCC) parametric simulations. It is sourced
# from Main_SCC.R.
# Command line arguments (passed by the Slurm job array) override the
# corresponding values in the configuration file. Parameters not present
# in the command line arguments keep their values from the config file.
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
#   9.  control_type
#   10. optimization_aim
#   11. flexibility_event_length_max
#   12. flexibility_recover_timespan
#   13. thermal_stabilization_timespan
#   14. minimum_flexibility
#   15. flexibility_splits
#   16. Alpha_confort
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
      "  flexibility_splits, Alpha_confort, month_subset\n",
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
    control_type                      = as.integer(args[9]),
    optimization_aim                  = as.integer(args[10]),
    flexibility_event_length_max      = as.numeric(args[11]),
    flexibility_recover_timespan      = as.numeric(args[12]),
    thermal_stabilization_timespan    = as.numeric(args[13]),
    minimum_flexibility               = as.numeric(args[14]),
    flexibility_splits                = as.integer(args[15]),
    Alpha_confort                     = as.numeric(args[16]),
    month_subset                      = as.integer(args[17])
  )
  
  cat("SCC run parameters:\n")
  print(scc_run_params)
}

# -----------------------------------------------------------
# Setpoint parameters
# -----------------------------------------------------------
{
  parameters$control <- load_control_parameters(control_file)
  rm(control_file)
  
  # Override control_type and optimization_aim with SCC command line parameters
  parameters$control$control_type    <- scc_run_params$control_type
  parameters$control$optimization_aim <- scc_run_params$optimization_aim
  
  parameters$control$control_type <- ifelse(
    parameters$control$control_type == 1, "modes", "setpoint")
  
  if (is.null(parameters$control$Deadband)) stop("Deadband not found in control parameters")
  
  if (parameters$control$control_type == "modes") {
    parameters$setpoint_modes <- read.csv(setpoint_mode_file, comment.char = "#")
  }
  
  # Override flexibility control parameters with SCC values
  parameters$control$flexibility_event_length_max   <- scc_run_params$flexibility_event_length_max
  parameters$control$flexibility_recover_timespan    <- scc_run_params$flexibility_recover_timespan
  parameters$control$thermal_stabilization_timespan  <- scc_run_params$thermal_stabilization_timespan
  parameters$control$minimum_flexibility             <- scc_run_params$minimum_flexibility
  parameters$control$flexibility_splits              <- scc_run_params$flexibility_splits
  
  # Optimization aim (1: energy, 2: flexibility)
  if (is.null(parameters$control$optimization_aim) || 
      !parameters$control$optimization_aim %in% c(1, 2)) {
    stop("optimization_aim must be 1 (energy) or 2 (flexibility)")
  }
  
  parameters$control$optimization_aim <- ifelse(
    parameters$control$optimization_aim == 1, "energy", "flexibility")
  
  # TODO: temporary implementation - update for all conditions when flexibility
  #       mode is fully integrated with all control_type variants
  if (parameters$control$optimization_aim == "flexibility") {
    parameters$control$control_type  <- "modes"
    parameters$forecast$forecast_type <- "accurate"
    if (is.null(parameters$setpoint_modes)) {
      parameters$setpoint_modes <- read.csv(setpoint_mode_file, comment.char = "#")
    }
  }
  rm(setpoint_mode_file)
  
  cat("setpoint ranges loaded\n")
  cat("optimization aim:", parameters$control$optimization_aim, "\n")
}

# -----------------------------------------------------------
# Optimization parameters
# -----------------------------------------------------------
{
  parameters$optimization <- load_optimization_parameters(optimization_file)
  rm(optimization_file)
  
  # Override with SCC command line parameters (optimization subset)
  parameters$optimization$population_size                   <- scc_run_params$population_size
  parameters$optimization$iteration_number                  <- scc_run_params$iteration_number
  parameters$optimization$run_number                        <- scc_run_params$run_number
  parameters$optimization$pcrossover                        <- scc_run_params$pcrossover
  parameters$optimization$pmutation                         <- scc_run_params$pmutation
  parameters$optimization$control_optimization_horizon      <- scc_run_params$control_optimization_horizon
  parameters$optimization$control_implementation_horizon    <- scc_run_params$control_implementation_horizon
  parameters$optimization$control_optimization_anticipation <- scc_run_params$control_optimization_anticipation
  
  # TODO: temporary implementation - update for all conditions when flexibility
  #       mode is fully integrated with all control_type variants
  if (parameters$control$optimization_aim == "flexibility") {
    parameters$optimization$control_optimization_horizon    <- 24
    parameters$optimization$control_implementation_horizon  <- 24
    parameters$optimization$control_optimization_anticipation <- 0
  }
  
  # Check market resolution consistency
  if ((parameters$optimization$control_optimization_horizon * 60) %%
      parameters$optimization$market_resolution != 0) {
    stop("control_optimization_horizon must be divisible by market_resolution")
  }
  
  str(parameters$optimization)
  cat("optimization parameters loaded\n")
}

# -----------------------------------------------------------
# Reward parameters (Alpha_confort override)
# -----------------------------------------------------------
{
  parameters$reward$Alpha_confort <- scc_run_params$Alpha_confort
  cat("Alpha_confort:", parameters$reward$Alpha_confort, "\n")
}

# -----------------------------------------------------------
# Debug and configuration parameters
# -----------------------------------------------------------
{
  parameters$debug_and_config <- load_debug_and_config_parameters(debug_and_config_file)
  rm(debug_and_config_file)
  
  # Override month_subset with SCC command line parameter
  parameters$debug_and_config$month_subset <- scc_run_params$month_subset
  
  # SCC mandatory overrides: verbose always FALSE, parallel always 1
  parameters$debug_and_config$verbose  <- FALSE
  parameters$debug_and_config$parallel <- 1
}

# -----------------------------------------------------------
# subset dataframe by month
# -----------------------------------------------------------
{
  month_subset  <- parameters$debug_and_config$month_subset
  period_subset <- parameters$debug_and_config$period_subset # in timesteps
  
  if (!is.null(month_subset) && month_subset != 0) {
    Main_df <- Main_df[month(Main_df$time) == month_subset, ]
    cat("Month ", month_subset," selected\n")
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
