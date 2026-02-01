# -------------------------------------------------------------
# Function: run_optimization_step.R
# Part of the Model Predictive Control in buildings repository
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function runs a Model Predictive Control (MPC) over a
# building HVAC system. It optimizes the control setpoints
# over an optimization horizon and applies them over a control
# period.
# The optimization horizon shall be longer than the control
# horizon.
# When developing the optimization, it is possible to perform
# "inaccurate" weather predictions. Then the control period is
# calculated with the real weather.
# Two types of control are possible:
#   1. Setpoint control: The optimization directly provides
#      the heating and cooling setpoints for each market period.
#   2. Mode control: The optimization provides the control modes
#      for each market period. The setpoints are then derived
#      from the modes.
# 
# The function performs the following steps:
#   1. Defines the optimization and control periods based on
#      the current timestep.
#   2. Generates inaccurate forecasts for air temperature and
#      solar radiation if specified.
#   3. Optimizes the setpoints or control modes based on the
#      specified control type using genetic algorithms.
#   4. Calculates the building and energy system evolution for
#      the control period using the optimized setpoints or modes.
# -------------------------------------------------------------
# INPUT:
#   i0: Current timestep index
#   time_sec: Vector of timestamps in seconds
#   Main_df: Dataframe with the building and environment data
#   control_type: Type of control ("setpoint" or "modes")
#   set_point_range_heating: Range of heating setpoints
#   (if control_type is "setpoint")
#   set_point_range_cooling: Range of cooling setpoints
#   (if control_type is "setpoint")
#   setpoint_modes: Dataframe defining the control modes
#   (if control_type is "modes")
#   parameters: List of building and system parameters
#   Deadband: Deadband value for thermostatic control
#   optimization_parameters: List of optimization parameters
#   optimization_frequency_sec: Duration of the control period in seconds
#   optimization_horizon_sec: Duration of the optimization horizon in seconds
#   verbose: Boolean flag for verbose output
#   forecast_type: Type of forecast ("accurate" or "inaccurate")

# Run one optimization timestep
run_optimization_step <- function(i0,
                                  time_sec,
                                  Main_df, 
                                  control_type,
                                  set_point_range_heating = NULL,
                                  set_point_range_cooling = NULL,
                                  setpoint_modes = NULL,
                                  parameters,
                                  Deadband,
                                  optimization_parameters,
                                  optimization_frequency_sec,
                                  optimization_horizon_sec,
                                  verbose = TRUE,
                                  forecast_type = "accurate") {
  # step definition selection & subdataframes
  {
      i_end_horizon <- max(which(time_sec <= time_sec[i0] + optimization_horizon_sec))
      i_end_control <- max(which(time_sec <= time_sec[i0] + optimization_frequency_sec))
      
      period_chunk_optimize <- Main_df[i0:i_end_horizon, ]
      period_chunk_control  <- Main_df[i0:i_end_control, ]
      
      # Verify sufficiently large step
      if (nrow(period_chunk_optimize) < 2) {
        if (verbose) {
          cat("period_chunk<2 exception case triggered\n",
              "Step initiation:", format(Main_df$time[i0]), "\n",
              "Step end:"       , format(Main_df$time[i_end_horizon]), "\n")
        }
        Main_df[i0:i_end_control, ] <- period_chunk_control
        return(list(Main_df = Main_df, i_end_control = i_end_control))
      }
  }
  
  # Inaccurate predictions
  if (forecast_type == "inaccurate"){
    # Generate imperfect forecasts for external_temperature and solar_radiation and replace values
    n_days_back <- if (!is.null(parameters$forecast_n_days_back)) parameters$forecast_n_days_back else 5
    forecast_weight_history <- if (!is.null(parameters$forecast_weight_history)) parameters$forecast_weight_history else 0.2
    
    # Call imperfect_forecast (returns tibble with time and pred_<target_col>)
    pred_air_temperature <- imperfect_forecast(Main_df,
                                  target_col = "external_temperature",
                                  i0 = i0,
                                  i_end_horizon = i_end_horizon,
                                  n_days_back = n_days_back,
                                  forecast_weight_history = forecast_weight_history,
                                  time_col = "time")
    
    pred_solar_radiation <- imperfect_forecast(Main_df,
                                   target_col = "solar_radiation",
                                   i0 = i0,
                                   i_end_horizon = i_end_horizon,
                                   n_days_back = n_days_back,
                                   forecast_weight_history = forecast_weight_history,
                                   time_col = "time")
    
    # Match predictions to period_chunk_optimize rows (preserve order)
    idx_air_temperature <- match(period_chunk_optimize$time, pred_air_temperature$time)
    idx_solar_radiation <- match(period_chunk_optimize$time, pred_solar_radiation$time)
    
    pred_vals_air_temperature <- if (!all(is.na(idx_air_temperature))) pred_air_temperature$pred_external_temperature[idx_air_temperature] else rep(NA_real_, nrow(period_chunk_optimize))
    pred_vals_solar_radiation <- if (!all(is.na(idx_solar_radiation))) pred_solar_radiation$pred_solar_radiation[idx_solar_radiation] else rep(NA_real_, nrow(period_chunk_optimize))
    
    # Replace only when prediction is not NA (keep original otherwise)
    period_chunk_optimize$external_temperature <- ifelse(!is.na(pred_vals_air_temperature),
                                                         pred_vals_air_temperature,
                                                         period_chunk_optimize$external_temperature)
    
    period_chunk_optimize$solar_radiation      <- ifelse(!is.na(pred_vals_solar_radiation),
                                                         pred_vals_solar_radiation,
                                                         period_chunk_optimize$solar_radiation)
  }
    
  # optimize setpoints
  # Mode dependent
  {
    if (control_type == "setpoint") {
      set_point_optimized <- optimize_setpoints(period_chunk_optimize,
                                                set_point_range_heating,
                                                set_point_range_cooling,
                                                parameters,
                                                Deadband,
                                                optimization_parameters
                                                )
      
      set_point_actual <- convert_setpoints(setpoints_heating = set_point_optimized[[1]],
                                            setpoints_cooling = set_point_optimized[[2]],
                                            Deadband          = Deadband,
                                            periods_target    = sort(unique(Main_df$MarketUTC[i0:i_end_horizon]))
                                            )
    }
    
    if (control_type == "modes") {
      setpoint_modes_df_optimized <- optimize_modes(period_chunk_optimize,
                                                    setpoint_modes,
                                                    parameters,
                                                    Deadband,
                                                    optimization_parameters
                                                    )
      
      set_point_actual <- convert_modes_to_setpoints(setpoint_modes_df = setpoint_modes_df_optimized,
                                                     setpoint_modes    = setpoint_modes,
                                                     Deadband          = Deadband,
                                                     periods_target      = unique(Main_df$MarketUTC[i0:i_end_horizon])
                                                     )
    }
  }

  # calculate period
  # subset step + first timestamp in following day
  {
    # Actual execution
    period_chunk_control <- period_calculation(period_chunk_control,
                                               set_point_actual,
                                               parameters
                                               )
    
    # Execution with forecasted values (for logging purposes)
    {
      period_chunk_optimize<-period_chunk_optimize[period_chunk_optimize$time %in% period_chunk_control$time,]
      period_chunk_optimize <- period_calculation(period_chunk_optimize,
                                                  set_point_actual,
                                                  parameters
                                                  )
      period_chunk_control$external_temperature_forecast <- period_chunk_optimize$external_temperature
      period_chunk_control$solar_radiation_forecast      <- period_chunk_optimize$solar_radiation
      period_chunk_control$Ti_forecast                    <- period_chunk_optimize$Ti
      period_chunk_control$Te_forecast                    <- period_chunk_optimize$Te
      period_chunk_control$Qh_forecast                    <- period_chunk_optimize$Qh
      period_chunk_control$Qc_forecast                    <- period_chunk_optimize$Qc
      period_chunk_control$elec_total_forecast            <- period_chunk_optimize$elec_total
    }
    
    period_chunk_control <- period_chunk_control[, colnames(Main_df), drop = FALSE]
    Main_df[i0:i_end_control, ] <- period_chunk_control
    
    # Print verbose info
    if (verbose) {
      cat("Optimization timestep:", i0, "\n",
          "Step initiation:"      , format(Main_df$time[i0]), "\n",
          "Control step end:"     , format(Main_df$time[i_end_control]), "\n",
          "Ended at time:", format(Sys.time()), "\n",
          "======================================\n")
    }
  }

  return(list(Main_df = Main_df,
              i_end_control = i_end_control))
}
