# Cleaning and reset of the environment
rm(list=ls())

# Get arguments from console
{
  cli_args <- commandArgs(trailingOnly = TRUE)
  str(cli_args)  
}

# Initialisation of the file directory
WD<-getwd()

# Loading libraries
{
  ruta_librerias<- paste(WD, "/00_Libraries", sep="")
  
  .libPaths(c(ruta_librerias, .libPaths()))
  
  required_libraries <- c("readr","dplyr", "tidyr",
                          "ggplot2", "zoo", "GA", "lubridate")

  
  for (library in required_libraries) {
    library(library,
            character.only = TRUE,
            lib=ruta_librerias)
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
    confort_low = 22, 
    confort_high = 26,
    
    # State Initialization
    Ti_0 = 20,
    Te_0 = 20,
    Qh_0 = 0
  )
}
cat("model parameters loaded\n")

# Setpoint parameters
{
  set_point_df <- read_rds("01_Data/set_point_df.rds")
  Deadband <- 2
  
  # The code below is optional,
  # I narrowed-down the setpoint range so that the optimization is better
  set_point_df$set_point_envelope_low[1:8]<-12
  set_point_df$set_point_envelope_low[20:24]<-12
  set_point_df$set_point_envelope_high[20:24]<-12
  set_point_df$set_point_envelope_high[1:3]<-15
  set_point_df$set_point_envelope_high[4]<-20
  set_point_df$set_point_envelope_high[5]<-26
}
cat("setpoint bands loaded\n")

# Optimization_parameters
{
  optimization_parameters <- list(
    population_size        = as.integer(cli_args[1]),
    iteration_number       = as.integer(cli_args[2]),
    run_number             = as.integer(cli_args[3]),
    optimization_horizon   = as.integer(cli_args[4]), #hours
    optimization_frequency = as.integer(cli_args[5])  #hours
  )
}
str(optimization_parameters)
cat("optimization parameters loaded\n")

# Corrections
if (optimization_parameters[["optimization_frequency"]]>optimization_parameters[["optimization_horizon"]]){
  optimization_parameters[["optimization_frequency"]]<-optimization_parameters[["optimization_horizon"]]
}

# subset dataframe by month
{
  month_subset<-as.integer(cli_args[6])
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

# Get time intervals
{
  optimization_timesteps<-((Main_df$HourUTC-Main_df$HourUTC[1])/(optimization_parameters[["optimization_frequency"]]*60*60))-
    floor((Main_df$HourUTC-Main_df$HourUTC[1])/(optimization_parameters[["optimization_frequency"]]*60*60))==0
  
  optimization_timesteps<-Main_df$HourUTC[optimization_timesteps]
}

# go through dataframe by steps
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
  # subset step + first timestamp in following day
  {
    step<-optimization_timesteps[optimization_timestep]
    if (optimization_timestep<n_steps)
    {
      step_1<-optimization_timesteps[optimization_timestep+1]
    } else{
      step_1<-max(Main_df$HourUTC)
    }
    TF_optimize<- Main_df$HourUTC>=step & Main_df$HourUTC<=step_1
    
    day_chunk_optimize<-Main_df[TF_optimize,]
  }
  
  # Verify sufficiently large step
  if (nrow(day_chunk_optimize) < 2) {
    cat("day_chunk<2 exception case triggered\n",
        "Optimization timestep:", optimization_timestep, "\n",
        "Step initiation:", format(step, "%Y-%m-%d %H:%M:%S"), "\n",
        "Step end:", format(step_1, "%Y-%m-%d %H:%M:%S"), "\n")
    TF_merge<-Main_df$HourUTC>=step & Main_df$HourUTC<=step_1
    Main_df[TF_merge,]<-day_chunk_optimize
    next
  }
  
  # optimize setpoints
  {
    set_point_df_subset<-set_point_df[set_point_df$datetime%in%unique(hour(day_chunk_optimize$HourUTC)),]
    set_point_df_other<-set_point_df[!set_point_df$datetime%in%unique(hour(day_chunk_optimize$HourUTC)),]
    
    setpoints_optimized <- f5_optimize_setpoints_24(day_chunk_optimize,
                                                    set_point_df_other,set_point_df_subset,
                                                    model_parameters,Deadband,optimization_parameters)
    
    set_point_df_actual <-set_point_df_subset
    set_point_df_actual$set_point<-setpoints_optimized
    set_point_df_actual$set_point_low <-set_point_df_actual$set_point - Deadband/2
    set_point_df_actual$set_point_high<-set_point_df_actual$set_point + Deadband/2
    
    if (nrow(set_point_df_other) > 0) {
      set_point_df_other$set_point <- NA_real_
      set_point_df_other$set_point_low <- NA_real_
      set_point_df_other$set_point_high <- NA_real_
    }
    
    set_point_df_actual<-rbind(set_point_df_other,set_point_df_actual) %>% arrange(datetime)
  }
  
  # calculate period
  # subset step + first timestamp in following day
  cat(
    "Optimization timestep:", optimization_timestep, "\n",
    "Step initiation:", format(step, "%Y-%m-%d %H:%M:%S"), "\n",
    "Step end:", format(step_1, "%Y-%m-%d %H:%M:%S"), "\n",
    "Time", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
  {
    TF_control<-day_chunk_optimize$HourUTC>=step & day_chunk_optimize$HourUTC<=step_1
    
    day_chunk<-day_chunk_optimize[TF_control,]
    day_chunk <- f3_period_calculation(day_chunk, set_point_df_actual, model_parameters)
    
    TF_merge<-Main_df$HourUTC>=step & Main_df$HourUTC<=step_1
    Main_df[TF_merge,]<-day_chunk
  }
}
t_end<-Sys.time()
t_process <- as.numeric(difftime(t_end, t_begin, units = "secs"))

cat(
  "Optimization ended at time ", format(t_end, "%Y-%m-%d %H:%M:%S"), "\n",
  "Total time span: ",t_process," seconds \n")

# data outputs
{
  if (!file.exists("04_Output")) {
    dir.create("04_Output")
    }

  # full
  write.csv(Main_df,
			paste("04_Output/Main_df_",
                  as.integer(cli_args[1]),"_",
                  as.integer(cli_args[2]),"_",
                  as.integer(cli_args[3]),"_",
                  as.integer(cli_args[4]),"_",
                  as.integer(cli_args[5]),"_",
			            as.integer(cli_args[6]),".csv", sep=""))
  write_rds(Main_df,
            paste("04_Output/Main_df_",
                  as.integer(cli_args[1]),"_",
                  as.integer(cli_args[2]),"_",
                  as.integer(cli_args[3]),"_",
                  as.integer(cli_args[4]),"_",
                  as.integer(cli_args[5]),"_",
                  as.integer(cli_args[6]),".rds", sep=""))
  #sinthetized
  Sinthetized_df<-data.frame(as.data.frame(optimization_parameters),
                             elec_heating=sum(Main_df$elec_heating),
                             cost_heating=sum(Main_df$cost_heating),
                             building_comfort=sum(Main_df$building_comfort),
                             reward=sum(Main_df$reward),
                             process_time=t_process)
  write.csv(Sinthetized_df,
            paste("04_Output/Sinthetized_df_",
                  as.integer(cli_args[1]),"_",
                  as.integer(cli_args[2]),"_",
                  as.integer(cli_args[3]),"_",
                  as.integer(cli_args[4]),"_",
                  as.integer(cli_args[5]),"_",
                  as.integer(cli_args[6]),".csv", sep=""))
  write_rds(Sinthetized_df,
            paste("04_Output/Sinthetized_df_",
                  as.integer(cli_args[1]),"_",
                  as.integer(cli_args[2]),"_",
                  as.integer(cli_args[3]),"_",
                  as.integer(cli_args[4]),"_",
                  as.integer(cli_args[5]),"_",
                  as.integer(cli_args[6]),".rds", sep=""))
}

