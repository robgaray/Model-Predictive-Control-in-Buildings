# -------------------------------------------------------------
# Script: simulation.R
# Part of the Model Predictive Control in buildings repository
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This script performs the simulation loop on the model
# predictive control (MPC). It goes through the time series, and
# executes the MPC at each optimization timestep.
# After an initial model initialization, the script foes through
# the dataframe and at each optimization timestep:
#   1. Defines the optimization and control periods
#   2. Runs the optimization step (setpoint or mode control)
#   3. Updates the main dataframe with the results from the
#      optimization step.
# -------------------------------------------------------------

# Model initialization
{
  Main_df$Ti[1] <- parameters$Ti_0
  Main_df$Te[1] <- parameters$Te_0
  Main_df$Qh[1] <- parameters$Qh_0
  Main_df$Qc[1] <- parameters$Qc_0
}

# Auxiliary variables for indexing
{
  time_sec <- as.numeric(Main_df$time)
  t0 <- time_sec[1]
  
  optimization_frequency_sec <- optimization_parameters$optimization_frequency * 3600
  optimization_horizon_sec   <- optimization_parameters$optimization_horizon   * 3600
  optimization_timesteps_idx <- which((time_sec - t0) %% optimization_frequency_sec == 0)
  n_steps <- length(optimization_timesteps_idx)
  
  market_resolution_min <- optimization_parameters$market_resolution
  Main_df$MarketUTC <- as.POSIXct(
    floor(as.numeric(Main_df$time) / (market_resolution_min * 60)) *
      (market_resolution_min * 60),
    origin = "1970-01-01",
    tz = "UTC")
}

# Simulation loop
{
  t_begin <- Sys.time()
  if (verbose) {
    cat("Simulation started at", format(t_begin), "\nTotal timesteps:", n_steps, "\n",
        "Period to be optimized:\n",
        "Begins ", format(min(Main_df$time)), "\n",
        "Ends "  , format(max(Main_df$time)), "\n",
        "Ended at time:", format(Sys.time()), "\n",
        "======================================\n")
  }
  
  for (optimization_timestep in seq_len(n_steps)) {
    i0 <- optimization_timesteps_idx[optimization_timestep]
    
    res <- run_optimization_step(i0,
                                 time_sec,
                                 Main_df,
                                 control_type,
                                 set_point_range_heating,
                                 set_point_range_cooling,
                                 setpoint_modes, parameters,
                                 Deadband,
                                 optimization_parameters,
                                 optimization_frequency_sec,
                                 optimization_horizon_sec,
                                 verbose,
                                 forecast_type
    )
    
    Main_df <- res$Main_df
  }
  
}

t_end <- Sys.time()
t_process <- as.numeric(difftime(t_end, t_begin, units = "secs"))

if (verbose) {
  cat("Simulation ended at", format(t_end), "\nTotal time:", t_process, "seconds\n")
}
