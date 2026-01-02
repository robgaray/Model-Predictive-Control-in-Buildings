# -------------------------------------------------------------
# Script: Main.R
# Script to test a Model Predictive Control in buildings
# Adapted version for execution in a super computer
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
  WD<-getwd()

  # Loading libraries
  {
    required_libraries <- c("readr","dplyr", "tidyr",
                            "ggplot2", "zoo", "GA", "lubridate")
    
    
    for (library in required_libraries) {
        library(library,
              character.only = TRUE)
    }
    
    rm(library, required_libraries)
  }
  cat("libraries loaded\n")

  # Load functions
  {
    files.source <- list.files(paste(WD, "/03_Functions", sep=""))
    for (i in seq_along(files.source)) {
      source(paste(getwd(), "/03_Functions/", files.source[i], sep=""))  
    }
    rm(files.source, i)    
  }
  cat("functions loaded\n")
}

#### Data & model parameters
# no need to look inside unless you want to modify the physical model
{
  # Load data frame
  Main_df <- readRDS("01_Data/Main_df.rds")
  cat("dataframe loaded\n")

  # Model parameters
  {
    model_parameters <- list(
      # Building Physics
      Ci = 1, Ce = 3.32, 
      Rie = 0.897, Rea = 4.38,
      Aw = 5.75, Ae = 3.87,
      
      # Solar control
      Shading_0 = 0.7, Shading_1 = 1,
      
      # Heat Pump
      AT_hp1 = 0.5, AT_hp2 = 1, 
      Q_hp1 = 3, Q_hp2 = 9,
      COP_hp1 = 3, COP_hp2 = 7/9,
      
      # Ventilation
      Rvent01 = 127.15, Rvent1  = 12.72, Rvent2  = 6.36,
      
      # Confort bounds
      confort_low = 21, 
      confort_high = 26,
      
      # State Initialization
      Ti_0 = 20,
      Te_0 = 20,
      Qh_0 = 0
    )
  }
  cat("model parameters loaded\n")
  
}

#### Control and optimization parameters
# THIS IS THE PLACE TO CHANGE PARAMETERS
{
  # Setpoint parameters
  {
    set_point_range_heating<-c(5,26)
    Deadband <- 1
  }
  cat("setpoint bands loaded\n")
  
  # Optimization_parameters
  {
    optimization_parameters <- list(
      population_size        = 30,
      iteration_number       = 20,
      run_number             = 3,
      optimization_horizon   = 27, #hours
      optimization_frequency = 25  #hours
    )
    
    # Corrections
    if (optimization_parameters[["optimization_frequency"]]>optimization_parameters[["optimization_horizon"]]){
      optimization_parameters[["optimization_frequency"]]<-optimization_parameters[["optimization_horizon"]]
    }
  }
  str(optimization_parameters)
  cat("optimization parameters loaded\n")
  
  # subset dataframe by month
  {
    month_subset<-1
    if (month_subset!=0) {
      Main_df<-Main_df[month(Main_df$HourUTC)==month_subset,]
      cat("Full year selected\n")
    } else {
      cat("Month ", month_subset ," selected\n")
    }
    Main_df$Ti[1]<-model_parameters$Ti_0
    Main_df$Te[1]<-model_parameters$Te_0
    Main_df$Qh[1]<-model_parameters$Qh_0
  }
}

#### Simulation
{
  # Get time intervals
  {
    optimization_timesteps<-((Main_df$HourUTC-Main_df$HourUTC[1])/(optimization_parameters[["optimization_frequency"]]*60*60))-
      floor((Main_df$HourUTC-Main_df$HourUTC[1])/(optimization_parameters[["optimization_frequency"]]*60*60))==0
    
    optimization_timesteps<-Main_df$HourUTC[optimization_timesteps]
  }

  # go through dataframe by steps
  {
    t_begin<-Sys.time()
    n_steps <- length(optimization_timesteps)
    
    cat(
      "Optimization started at time ", format(t_begin, "%Y-%m-%d %H:%M:%S"), "\n",
      "Total timesteps: ",n_steps,"\n",
      "Period to be optimized:\n",
      "Begins ", format(min(Main_df$HourUTC), "%Y-%m-%d %H:%M:%S"), "\n",
      "Ends "  , format(max(Main_df$HourUTC), "%Y-%m-%d %H:%M:%S"), "\n")
    
    for (optimization_timestep in 1:n_steps)
    {
      # Optimization horizon
      # subset step + first timestamp in following step
      {
        step<-optimization_timesteps[optimization_timestep]
        
        step_1_horizon<-step + optimization_parameters$optimization_horizon*60*60
        step_1_horizon<-min(step_1_horizon,max(Main_df$HourUTC))
        
        TF_optimize<- Main_df$HourUTC>=step & Main_df$HourUTC<=step_1_horizon
        day_chunk_optimize<-Main_df[TF_optimize,]
        
        step_1_control<-step + optimization_parameters$optimization_frequency*60*60
        step_1_control<-min(step_1_control,max(Main_df$HourUTC))
        
        TF_control<-day_chunk_optimize$HourUTC>=step & day_chunk_optimize$HourUTC<=step_1_control
        day_chunk_control<-day_chunk_optimize[TF_control,]
      }
      
      # Verify sufficiently large step
      if (nrow(day_chunk_optimize) < 2) {
        cat("day_chunk<2 exception case triggered\n",
            "Optimization timestep:", optimization_timestep, "\n",
            "Step initiation:", format(step, "%Y-%m-%d %H:%M:%S"), "\n",
            "Step end:", format(step_1_horizon, "%Y-%m-%d %H:%M:%S"), "\n")
        TF_merge<-Main_df$HourUTC>=step & Main_df$HourUTC<=step_1_horizon
        Main_df[TF_merge,]<-day_chunk_optimize
        next
      }
      
      # optimize setpoints
      {
        set_point_heating_optimized <- f5_optimize_setpoints_24(day_chunk_optimize,
                                                                set_point_range_heating,
                                                                model_parameters,Deadband,optimization_parameters)
        
        set_point_actual<-as.data.frame(unique(floor_date(day_chunk_optimize$HourUTC, unit = "hour")))
        names(set_point_actual)<-"hour"
        set_point_actual$set_point_heating<-c(set_point_heating_optimized,0)
        set_point_actual$set_point_heating_low <-set_point_actual$set_point_heating - Deadband/2
        set_point_actual$set_point_heating_high<-set_point_actual$set_point_heating + Deadband/2
      }
      
      # calculate period
      # subset step + first timestamp in following day
      cat(
        "Optimization timestep:", optimization_timestep, "\n",
        "Step initiation:", format(step, "%Y-%m-%d %H:%M:%S"), "\n",
        "Step end:", format(step_1_control, "%Y-%m-%d %H:%M:%S"), "\n",
        "Time", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
		
      {
        day_chunk_control <- f3_period_calculation(day_chunk_control, set_point_actual, model_parameters)
        
        TF_merge<-Main_df$HourUTC>=step & Main_df$HourUTC<=step_1_control
        Main_df[TF_merge,]<-day_chunk_control
      }
    }
    t_end<-Sys.time()
    t_process <- as.numeric(difftime(t_end, t_begin, units = "secs"))
    
    cat(
      "Optimization ended at time ", format(t_end, "%Y-%m-%d %H:%M:%S"), "\n",
      "Total time span: ",t_process," seconds \n")
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
  if (!file.exists("04_Output_test")) {
    dir.create("04_Output_test")
    }
    
  # full
  write.csv(Main_df,'04_Output_test/Main_df_computed.csv')
  write_rds(Main_df,'04_Output_test/Main_df_computed.rds')
  
  #sinthetized
  Sinthetized_df<-data.frame(as.data.frame(optimization_parameters),
                             elec_heating=sum(Main_df$elec_heating),
                             cost_heating=sum(Main_df$cost_heating),
                             building_comfort=sum(Main_df$building_comfort),
                             reward=sum(Main_df$reward),
                             process_time=t_process)
  write.csv(Sinthetized_df,'04_Output_test/Sinthetized_df_computed.csv')
  write_rds(Sinthetized_df,'04_Output_test/Sinthetized_df_computed.rds')
}

