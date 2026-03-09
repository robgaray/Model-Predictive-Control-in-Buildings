# -------------------------------------------------------------
# Script: control_optimization_parameters.R
# Defines load_control_optimization_parameters() function
# Called by Main.R
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Arguments:
#   control_file, setpoint_mode_file, optimization_file, Main_df
# Returns a list with:
#   control_type, Deadband, optimization_parameters, verbose,
#   month_subset, period_subset, Main_df (updated/subsetted)
#   and optionally: set_point_range_heating, set_point_range_cooling,
#   setpoint_modes
# -------------------------------------------------------------

load_control_optimization_parameters <- function(control_file,
                                                  setpoint_mode_file,
                                                  optimization_file,
                                                  Main_df) {
  result <- list()

  # Setpoint parameters
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
      result$set_point_range_heating <- control$set_point_range_heating
      result$set_point_range_cooling <- control$set_point_range_cooling
    }

    if (control_type == "modes") {
      result$setpoint_modes <- read.csv(setpoint_mode_file, comment.char = "#")
    }

    cat("setpoint ranges loaded\n")
  }

  # Optimization parameters
  {
    optimization_parameters <- load_optimization_parameters(optimization_file)

    # Check market resolution consistency
    if ((optimization_parameters$optimization_horizon * 60) %%
        optimization_parameters$market_resolution != 0) {
      stop("optimization_horizon must be divisible by market_resolution")
    }

    # Corrections
    if (optimization_parameters[["optimization_frequency"]] > optimization_parameters[["optimization_horizon"]]){
      optimization_parameters[["optimization_frequency"]] <- optimization_parameters[["optimization_horizon"]]
    }

    # Verbose setting
    if (optimization_parameters$verbose == 1){
      verbose <- TRUE
    } else {
      verbose <- FALSE
    }

    str(optimization_parameters)
    cat("optimization parameters loaded\n")
  }

  # Subset dataframe by month
  {
    month_subset  <- optimization_parameters$month_subset
    period_subset <- optimization_parameters$period_subset # in timesteps

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

  result$control_type            <- control_type
  result$Deadband                <- Deadband
  result$optimization_parameters <- optimization_parameters
  result$verbose                 <- verbose
  result$month_subset            <- month_subset
  result$period_subset           <- period_subset
  result$Main_df                 <- Main_df

  return(result)
}
