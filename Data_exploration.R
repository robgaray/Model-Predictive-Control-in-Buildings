# Cleaning and reset of the environment
rm(list=ls())

# -------------------------------------------------------------
# Script: Data_Exploration.R
# Purpose:
#   - Get a well performing configuration
#   - Read the corresponding file with name Main_df_NUM1_NUM2_NUM3_NUM4_NUM5_NUM6.rds located in subdirectory "04_Output_XXX"
#   - Explore a few random weeks in the year
#   - Sinthetize performance metrics per relevant time frames
#      Metrics: Confort, Cost of energy, Ti, air temperature
#      Aggregation periods: Hour of the day, Day of the week, Week of the year
# -------------------------------------------------------------

library(dplyr)
library(stringr)
library(lubridate)

# Initialisation of the file directory
WD<-getwd()

# Load functions
{
  files.source <- list.files(paste(WD, "/03_1_Functions_Postprocess", sep=""))
  for (i in seq_along(files.source)) {
    source(paste(WD, "/03_1_Functions_Postprocess/", files.source[i], sep=""))  
  }
  rm(files.source, i)    
}

# Input and output directories
dir_input  <- "04_Output_round_02"
file_parameters <- "05_Postprocess_02/selected_parameter_range.rds"
dir_output <- "06_Data_Exploration"

# Get a well performing configuration
{
  configurations <- readRDS(paste(WD,"/",file_parameters,sep=""))
  
  for (i in seq_len(nrow(configurations))) {
    assign(
      x = configurations$variable[i],
      value = configurations$minimum[i],
      envir = .GlobalEnv
    )
  }
  
  selected_configuration<-paste("Main_df_",
                                population_size,"_",
                                iteration_number,"_",
                                run_number,"_",
                                optimization_horizon,"_",
                                optimization_frequency,"_",
                                "0",".rds",sep="")  
}

# Read file
Main_df <- readRDS(paste(WD,"/",dir_input,"/",selected_configuration,sep=""))


# Take 3 random weeks to plot
{
  weeks <- sample(unique(as.integer(strftime(Main_df$HourUTC, "%V"))), 3)
  
  for (w in weeks) {
    plot_one_iso_week(Main_df, iso_week = w, year = 2019)
    plot_one_iso_week(Main_df, iso_week = w, year = 2019,
                      file = paste(WD,"/",dir_output,"/week_",w,".jpg",sep="")
    )
  }  
}


# Sinthetize performance metrics per relevant time frames
#      Metrics: Confort, Cost of energy, Ti, air temperature
#      Aggregation periods: Hour of the day, Day of the week, Week of the year

generate_all_calendar_plots(
  Main_df,
  save_plots = TRUE,
  output_dir = paste(WD,"/",dir_output,sep="")
)
