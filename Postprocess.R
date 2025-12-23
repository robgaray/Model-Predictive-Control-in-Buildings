# Cleaning and reset of the environment
rm(list=ls())

# -------------------------------------------------------------
# Script: aggregate_simulation_results.R
# Purpose:
#   - Read all files named Sinthetized_df_NUM1_NUM2_NUM3_NUM4_NUM5_NUM6.rds
#     located in subdirectory "04_Output_SCC"
#   - Extract the numeric parameters from the filename
#   - Each RDS file contains a data frame with only one row
#   - Combine all these files into a single data frame
#   - Save the output as RDS and CSV in "06_Postprocess"
# -------------------------------------------------------------

library(dplyr)
library(stringr)

# Input and output directories
dir_input  <- "04_Output"
dir_output <- "05_Postprocess"

# Create output directory if it does not exist
if(!dir.exists(dir_output)) dir.create(dir_output, recursive = TRUE)

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

# -------------------------------------------------------------
# Function to process a single file
# -------------------------------------------------------------
process_file <- function(fpath){
  
  # File name without full path
  fname <- basename(fpath)
  
  # Extract NUM1–NUM6 using regular expressions
  # Expected format: Sinthetized_df_NUM1_NUM2_NUM3_NUM4_NUM5_NUM6.rds
  nums <- str_match(fname,
                    "^Sinthetized_df_([0-9]+)_([0-9]+)_([0-9]+)_([0-9]+)_([0-9]+)_([0-9]+)\\.rds$")
  
  # If the pattern does not match, stop with an error
  if(is.na(nums[1,1])){
    stop(paste("Filename does not follow the expected pattern:", fname))
  }
  
  # Load the RDS file (a data frame with only one row)
  df <- readRDS(fpath)
  
  return(df)
}

# -------------------------------------------------------------
# Process all files and combine them into a single data frame
# -------------------------------------------------------------
parametric_simulation_output <- 
  files_rds |> 
  lapply(process_file) |> 
  bind_rows()

# -------------------------------------------------------------
# Save the output (RDS + CSV)
# -------------------------------------------------------------
saveRDS(parametric_simulation_output,
        file = file.path(dir_output, "parametric_simulation_output.rds"))

write.csv(parametric_simulation_output,
          file = file.path(dir_output, "parametric_simulation_output.csv"),
          row.names = FALSE)

cat("✔ Combined dataframe successfully saved in 06_Postprocess\n")

names(parametric_simulation_output)


# -------------------------------------------------------------
# Function: plot_box
# Creates a boxplot of reward vs. a chosen parameter variable
# using base R graphics.
# -------------------------------------------------------------
plot_box <- function(df, xvar, xlab){
  
  # Check that xvar exists in the dataframe
  if(!(xvar %in% names(df))){
    stop(paste("Variable does not exist in dataframe:", xvar))
  }
  
  # Prepare formula for boxplot: reward ~ xvar
  formula <- as.formula(paste("reward ~", xvar))
  
  # Create the boxplot
  boxplot(formula,
          data = df,
          main = paste("Reward vs", xlab),
          xlab = xlab,
          ylab = "Reward",
          col = "lightgray",
          border = "black")
}

# -------------------------------------------------------------
# Function: plot_all_boxplots
# Generates all required boxplots automatically
# -------------------------------------------------------------
plot_all_boxplots <- function(df){
  
  # 1 - population_size  --> popsize
  plot_box(df, "population_size", "Population Size")
  
  # 2 - iteration_number --> maxiter
  plot_box(df, "iteration_number", "Iteration Number")
  
  # 3 - run_number       --> runs
  plot_box(df, "run_number", "Run Number")
  
  # 4 - optimization_horizon --> Optim_horizon
  plot_box(df, "optimization_horizon", "Optimization Horizon")
  
  # 5 - optimization_frequency --> Optim_freq
  plot_box(df, "optimization_frequency", "Optimization Frequency")
}

plot_all_boxplots(parametric_simulation_output)

