# -------------------------------------------------------------
# Script: Main.R
# Script to test a Model Predictive Control in buildings
# Developed by Roberto Garay Martinez
# Outline
#   - Load Model
#   - Load control and optimization parameters
#   - Perform simulation
#   - Make some plots
#      (Quite basic, see Data_exploration.R for a more advanced approach)
#   - Export results to files
# -------------------------------------------------------------

#### Initialization
# no need to look inside
{
  # Cleaning and reset of the environment
  rm(list=ls())
  # Initialisation of the file directory
  {
    WD<-getwd()
    
    data_path       <- file.path(WD, "01_Data")
    config_path     <- file.path(WD, "02_config_files")
    functions_path  <- file.path(WD, "03_Functions")
    # library_path    <- file.path(WD, "00_Libraries")
    output_path     <- file.path(WD, "04_Output")
    
    main_file       <- file.path(data_path, "Main_df.rds")
    library_file    <- file.path(config_path, "libraries.txt")
    model_file      <- file.path(config_path, "model_parameters.csv")
    control_file    <- file.path(config_path, "control_parameters.csv")
	opt_file        <- file.path(config_path, "optimization_parameters.csv")
  }
  
  # Loading of libraries and functions{
  {
    source(file.path(functions_path, "initialization.R"))
    initialization(library_file, functions_path)														  
    cat("libraries loaded\n")
    cat("functions loaded\n")
  }
}

#### Data & model parameters
# no need to look inside unless you want to modify the physical model
{
  # Load data frame
  Main_df <- readRDS(main_file)
  cat("dataframe loaded\n")
  
  # Model parameters
  model_parameters <- load_model_parameters(model_file)
  cat("model parameters loaded\n")
}

#### Control and optimization parameters
# THIS IS THE PLACE TO CHANGE PARAMETERS
# Inspect & change the parameter files OR override the parameters after they are loaded
{
  # Setpoint parameters
  {
    control <- load_control_parameters(control_file)
    
    set_point_range_heating <- control$set_point_range_heating
    set_point_range_cooling <- control$set_point_range_cooling
    Deadband                <- control$Deadband
    
    rm(control)
    cat("setpoint ranges loaded\n")
  }
  
  # Optimization_parameters
  {
    optimization_parameters <- load_optimization_parameters(opt_file)
  
    # Corrections
    if (optimization_parameters[["optimization_frequency"]]>optimization_parameters[["optimization_horizon"]]){
      optimization_parameters[["optimization_frequency"]]<-optimization_parameters[["optimization_horizon"]]
    }
    
    str(optimization_parameters)
    cat("optimization parameters loaded\n")
  }

  # subset dataframe by month
  {
    month_subset<-1
    if (month_subset!=0) {
      Main_df<-Main_df[month(Main_df$HourUTC)==month_subset,]
      cat("Month ", month_subset ," selected\n")
    } else {
      cat("Full year selected\n")
    }
  }
}

#### Simulation
{
  # Model initialization
  {
    Main_df$Ti[1]<-model_parameters$Ti_0
    Main_df$Te[1]<-model_parameters$Te_0
    Main_df$Qh[1]<-model_parameters$Qh_0  
  }
  
  # Auxiliary variables for indexing, removed at the end
  {
    time_sec <- as.numeric(Main_df$HourUTC)
    t0 <- time_sec[1]
    
    optimization_frequency_sec <- optimization_parameters[["optimization_frequency"]] * 3600
    optimization_horizon_sec   <- optimization_parameters[["optimization_horizon"]]   * 3600
    
    optimization_timesteps_idx <- which((time_sec - t0) %% optimization_frequency_sec == 0)
    n_steps <- length(optimization_timesteps_idx)
    
    # Used instead of floor_date inside the loop
    Main_df$HourUTC_hour <- as.POSIXct(format(Main_df$HourUTC, "%Y-%m-%d %H:00:00"),
                                       tz = "UTC")
  }
  
  # simulation loop
  {
    t_begin<-Sys.time()
    
    cat(
      "Optimization started at time ", format(t_begin, "%Y-%m-%d %H:%M:%S"), "\n",
      "Total timesteps: ",n_steps,"\n",
      "Period to be optimized:\n",
      "Begins ", format(min(Main_df$HourUTC), "%Y-%m-%d %H:%M:%S"), "\n",
      "Ends "  , format(max(Main_df$HourUTC), "%Y-%m-%d %H:%M:%S"), "\n")
	  
    for (optimization_timestep in 1:n_steps)
    {
      # step definition selection
      {
        # step initiation (same for optimization and control horizons)
        i0 <- optimization_timesteps_idx[optimization_timestep]
        
        # optimization horizon ends
        i_end_horizon <- max(which(time_sec <= time_sec[i0] + optimization_horizon_sec))
        
        # control horizon ends
        i_end_control <- max(which(time_sec <= time_sec[i0] + optimization_frequency_sec))
        
        day_chunk_optimize <- Main_df[i0:i_end_horizon, ]
        day_chunk_control  <- Main_df[i0:i_end_control, ]
      }
      
      # Verify sufficiently large step
      if (nrow(day_chunk_optimize) < 2) {
        cat("day_chunk<2 exception case triggered\n",
            "Optimization timestep:", optimization_timestep, "\n",
            "Step initiation:"      , format(Main_df$HourUTC[i0], "%Y-%m-%d %H:%M:%S"), "\n",
            "Step end:"             , format(Main_df$HourUTC[i_end_horizon], "%Y-%m-%d %H:%M:%S"), "\n")
        Main_df[i0:i_end_control, ] <- day_chunk_control
        next
      }

      # optimize setpoints
      {
        # optimization
        set_point_optimized <- f5_optimize_setpoints_24(day_chunk_optimize,
                                                        set_point_range_heating,set_point_range_cooling,
                                                        model_parameters,Deadband,optimization_parameters)
        
        # output conversion
        set_point_actual <- data.frame(
          hour = unique(Main_df$HourUTC_hour[i0:i_end_horizon])
          )
        n_hours <- nrow(set_point_actual)
        
        set_point_actual$set_point_heating <- numeric(n_hours)
        set_point_actual$set_point_cooling <- numeric(n_hours)
        
        n_setpoints <- length(set_point_optimized[[1]])
        
        if (n_setpoints > n_hours) {
          set_point_actual$set_point_heating <- set_point_optimized[[1]][1:n_hours]
          set_point_actual$set_point_cooling <- set_point_optimized[[2]][1:n_hours]
        } else if (n_setpoints < n_hours) {
          set_point_actual$set_point_heating <- c(set_point_optimized[[1]], rep(0, n_hours - n_setpoints))
          set_point_actual$set_point_cooling <- c(set_point_optimized[[2]], rep(50, n_hours - n_setpoints))
        } else {
          set_point_actual$set_point_heating <- set_point_optimized[[1]]
          set_point_actual$set_point_cooling <- set_point_optimized[[2]]
        }
		
        set_point_actual$set_point_heating_low  <- set_point_actual$set_point_heating - Deadband/2
        set_point_actual$set_point_heating_high <- set_point_actual$set_point_heating + Deadband/2
		
        set_point_actual$set_point_cooling_low  <- set_point_actual$set_point_cooling - Deadband/2
        set_point_actual$set_point_cooling_high <- set_point_actual$set_point_cooling + Deadband/2
        
        cat(
          "Optimization timestep:", optimization_timestep, "\n",
          "Step initiation:"      , format(Main_df$HourUTC[i0], "%Y-%m-%d %H:%M:%S"), "\n",
          "Control step end:"     , format(Main_df$HourUTC[i_end_control], "%Y-%m-%d %H:%M:%S"), "\n",
          "Time", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
      }
      
      # calculate period
      # subset step + first timestamp in following day
      {
        day_chunk_control <- f3_period_calculation(day_chunk_control, set_point_actual, model_parameters)
		
        Main_df[i0:i_end_control, ] <- day_chunk_control
      }
    }

    t_end<-Sys.time()
    t_process <- as.numeric(difftime(t_end, t_begin, units = "secs"))
    
    cat(
      "Optimization ended at time ", format(t_end, "%Y-%m-%d %H:%M:%S"), "\n",
      "Total time span: ",t_process," seconds \n")
    
    Main_df$HourUTC_hour <- NULL
    rm(time_sec, t0, optimization_frequency_sec, optimization_horizon_sec,
       optimization_timesteps_idx, n_steps,
       i0, i_end_horizon, i_end_control, n_hours)
    gc()
  }
}

#### Visual exploration
# very basic
{
  plot(Main_df$HourUTC[1:(7*24*6)], xlab="time",
       Main_df$Ti[1:(7*24*6)], ylim=c(10,30), ylab="Indoor Temperature [ºC]")
  lines(Main_df$HourUTC[1:(7*24*6)],Main_df$set_point_low[1:(7*24*6)])
  lines(Main_df$HourUTC[1:(7*24*6)],Main_df$set_point_high[1:(7*24*6)])
  
  plot(Main_df$HourUTC[1:(7*24*6)], xlab="time",
       Main_df$building_occupied[1:(7*24*6)])
  
  plot(Main_df$HourUTC[1:(7*24*6)], xlab="time",
       Main_df$reward[1:(7*24*6)], ylab="reward")
  
  plot(Main_df$HourUTC[1:(7*24*6)], xlab="time",
       Main_df$Qh[1:(7*24*6)], ylab="Heat Input [W]")
}

#### Data outputs
{
  if (!dir.exists(output_path)) {
    dir.create(output_path, recursive = TRUE)
  }
	
  # Main_df
  {
    write.csv(Main_df,
              file.path(output_path,
                        "Main_df_computed.csv"))
    write_rds(Main_df,
              file.path(output_path,
                        "Main_df_computed.rds"))
  }

  #sinthetized
  {
    Sinthetized_df<-data.frame(as.data.frame(optimization_parameters),
                               elec_total=sum(Main_df$elec_total),
                               elec_cost=sum(Main_df$elec_cost),
                               building_comfort=sum(Main_df$building_comfort),
                               reward=sum(Main_df$reward),
                               process_time=t_process)
    write.csv(Sinthetized_df,
              file.path(output_path,
                        "Sinthetized_df_computed.csv"))
    write_rds(Sinthetized_df,
              file.path(output_path,
                        "Sinthetized_df_computed.rds"))
  }
}