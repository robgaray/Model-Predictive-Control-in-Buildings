# -------------------------------------------------------------
# Script: postprocess_XX.R
# Script to collect information from individual output files from massive calculations into a single file.
# Developed by Roberto Garay Martinez
# Outline:
#   - Read all files named Sinthetized_df_NUM1_NUM2_NUM3_NUM4_NUM5_NUM6.rds
#     located in subdirectory "04_Output_XXX"
#   - Extract the numeric parameters from the filename
#   - Each RDS file contains a data frame with only one row
#   - Combine all these files into a single data frame
#   - Save the output as RDS and CSV in "05_Postprocess_XXX"
#   - Make some frequency and boxplot analysis
#   - Identify the most performing combinations for further analysis
#     (the selection is performed by visual inspection of the plot
#     and then parametrized throughout the script)
#     (several iterations are made)
#   - Define the range of "acceptable" parameters for further analysis
# -------------------------------------------------------------

#### Initialization
{
  # Cleaning and reset of the environment
  rm(list=ls())
  
  # Loading libraries
  {
    required_libraries <- c("dplyr", "stringr")
    
    
    for (library in required_libraries) {
      library(library,
              character.only = TRUE)
    }
    
    rm(library, required_libraries)
  }
  
  # Initialisation of the file directory
  WD<-getwd()
  
  # Load functions
  {
    files.source <- list.files(paste(WD, "/03_1_Functions_Postprocess", sep=""))
    for (i in seq_along(files.source)) {
      source(paste(getwd(), "/03_1_Functions_Postprocess/", files.source[i], sep=""))  
    }
    rm(files.source, i)    
  }
}

# Input and output directories
dir_input  <- "04_Output_round_02"
dir_output <- "05_Postprocess_02"

#### Read and combine all files
{
  # List all RDS files that match the expected pattern
  files_rds <- list.files(
    path = dir_input,
    pattern = "^Sinthetized_df_.*\\.rds$",
    full.names = TRUE
  )
  
  # Stop if no matching files are found
  if(length(files_rds) == 0){
    stop("No files matching Sinthetized_df_*.rds found in directory 04_Output_SCC")
  }
  
  # Process all files and combine them into a single data frame
  parametric_simulation_output <- 
    files_rds |> 
    lapply(process_file) |> 
    bind_rows()
}

####  Save the output (RDS + CSV)
{
  # Create output directory if it does not exist
  if(!dir.exists(dir_output)) dir.create(dir_output, recursive = TRUE)
  
  saveRDS(parametric_simulation_output,
          file = file.path(dir_output, "parametric_simulation_output.rds"))
  
  write.csv(parametric_simulation_output,
            file = file.path(dir_output, "parametric_simulation_output.csv"),
            row.names = FALSE)
  
  cat("✔ Combined dataframe successfully saved in 06_Postprocess\n")
}

####  Make some figures
{
  plot_all_boxplots(parametric_simulation_output)
  
  hist(
    parametric_simulation_output$reward,
    breaks = 30,
    main = "Distribución de reward",
    xlab = "reward",
    col = "lightblue",
    border = "white"
  )
  
  lines(density(parametric_simulation_output$reward, na.rm = TRUE),
        col = "red", lwd = 2)
}

#### Get only best 25% & Make some figures
{
  parametric_simulation_output_top25 <- parametric_simulation_output %>%
    filter(reward >= quantile(reward, 0.75, na.rm = TRUE))
  
  plot_all_boxplots(parametric_simulation_output_top25)
  
  hist(
    parametric_simulation_output_top25$reward,
    breaks = 30,
    main = "Distribución de reward",
    xlab = "reward",
    col = "lightblue",
    border = "white"
  )
  
  vars <- parametric_simulation_output_top25[
    , sapply(parametric_simulation_output_top25, is.numeric)
  ]
  
  for (var in names(vars)) {
    hist(
      vars[[var]],
      main = paste("Histograma de", var),
      xlab = var,
      col = "lightblue",
      border = "white"
    )
  }
}

#### Visual optimization (iterative over the graphs)
# Remove clearly unperforming parameters,
# take again 25%,
# take run time in lower 50%,
# take population size in lower 50%,
# take iteration number in lower 50% &
# Make some figures
{
  parametric_simulation_output_selected <- parametric_simulation_output_top25 %>%
    filter(population_size >= 30)  %>%
    filter(iteration_number >= 30)  %>%
    filter(run_number >= 5) %>%
    filter(reward >= quantile(reward, 0.75, na.rm = TRUE)) %>%
    filter(process_time <= quantile(process_time, 0.5, na.rm = TRUE)) %>%
    filter(population_size <= quantile(population_size, 0.5, na.rm = TRUE)) %>%
    filter(iteration_number <= quantile(iteration_number, 0.5, na.rm = TRUE))
  
  plot_all_boxplots(parametric_simulation_output_selected)
  
  hist(
    parametric_simulation_output_selected$reward,
    breaks = 30,
    main = "Distribución de reward",
    xlab = "reward",
    col = "lightblue",
    border = "white"
  )
  
  vars <- parametric_simulation_output_selected[
    , sapply(parametric_simulation_output_selected, is.numeric)
  ]
  
  for (var in names(vars)) {
    hist(
      vars[[var]],
      main = paste("Histograma de", var),
      xlab = var,
      col = "lightblue",
      border = "white"
    )
  }
}

#### Take range for next step of parametric runs
{
  vars <- c(
    "population_size",
    "iteration_number",
    "run_number",
    "optimization_horizon",
    "optimization_frequency"
  )
  
  res <- data.frame(
    variable = vars,
    minimum = sapply(parametric_simulation_output_selected[vars], min, na.rm = TRUE),
    maximum = sapply(parametric_simulation_output_selected[vars], max, na.rm = TRUE),
    row.names = NULL
  )

  # Save the selected parameters (RDS + CSV)
  saveRDS(res,
          file = file.path(dir_output, "selected_parameter_range.rds"))
  
  write.csv(res,
            file = file.path(dir_output, "selected_parameter_range.csv"),
            row.names = FALSE)
  
  cat("✔ Combined dataframe successfully saved in 06_Postprocess\n")
}