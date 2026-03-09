# -------------------------------------------------------------
# Script: control_optimization_parameters_SCC.R
# Loads control and optimization parameters for SCC parametric runs
# Sourced by Main_SCC.R
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Expected variables in calling environment:
#   control_file, setpoint_mode_file, optimization_file,
#   Main_df, cli_args (7 positional arguments from Optim_parameters.csv)
# cli_args order:
#   [1] population_size
#   [2] iteration_number
#   [3] run_number
#   [4] control_optimization_horizon (hours)
#   [5] control_implementation_horizon (hours)
#   [6] control_optimization_anticipation (hours)
#   [7] month_subset (0 for full year)
# Variables set in calling environment:
#   control, control_type, Deadband, set_point_range_heating (optional),
#   set_point_range_cooling (optional), setpoint_modes (optional),
#   optimization_parameters, verbose, month_subset, period_subset, Main_df
# -------------------------------------------------------------

# -----------------------------------------------------------
# Setpoint parameters (from config file)
# -----------------------------------------------------------
{
  control <- load_control_parameters(control_file)
  if (control$control_type == 1){
    control_type <- "modes"
  } else {
    control_type <- "setpoint"
  }

  if (is.null(control$Deadband)) stop("Deadband not found in control parameters")

  Deadband <- control$Deadband

  if (control_type == "setpoint") {
    set_point_range_heating <- control$set_point_range_heating
    set_point_range_cooling <- control$set_point_range_cooling
  }

  if (control_type == "modes") {
    setpoint_modes <- read.csv(setpoint_mode_file, comment.char = "#")
  }

  cat("setpoint ranges loaded\n")
}

# -----------------------------------------------------------
# Optimization parameters: load from config file, then
# override with CLI args from Optim_parameters.csv
# -----------------------------------------------------------
{
  optimization_parameters <- load_optimization_parameters(optimization_file)

  # Override with CLI args
  optimization_parameters$population_size                  <- as.integer(cli_args[1])
  optimization_parameters$iteration_number                 <- as.integer(cli_args[2])
  optimization_parameters$run_number                       <- as.integer(cli_args[3])
  optimization_parameters$optimization_horizon             <- as.integer(cli_args[4])
  optimization_parameters$optimization_frequency           <- as.integer(cli_args[5])
  optimization_parameters$control_optimization_anticipation <- as.integer(cli_args[6])

  # Corrections
  if (optimization_parameters[["optimization_frequency"]] > optimization_parameters[["optimization_horizon"]]){
    optimization_parameters[["optimization_frequency"]] <- optimization_parameters[["optimization_horizon"]]
  }

  # Force verbose=0 and parallel=1
  verbose <- FALSE
  optimization_parameters$verbose   <- 0
  optimization_parameters$parallel  <- 1

  str(optimization_parameters)
  cat("optimization parameters loaded\n")
}

# -----------------------------------------------------------
# Subset dataframe by month
# -----------------------------------------------------------
{
  month_subset  <- as.integer(cli_args[7])
  period_subset <- optimization_parameters$period_subset  # from config file

  if (month_subset != 0) {
    Main_df <- Main_df[month(Main_df$time) == month_subset, ]
    cat("Month ", month_subset," selected\n")
  } else {
    cat("Full year selected\n")
  }

  if (period_subset > nrow(Main_df)){
    period_subset <- nrow(Main_df)
  }

  if (period_subset != 0) {
    Main_df <- Main_df[1:period_subset,]
  }
}
