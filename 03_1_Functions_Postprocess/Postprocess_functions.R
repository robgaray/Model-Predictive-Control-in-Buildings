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
# Function: plot_box
# Creates a boxplot of reward/process time vs. a chosen parameter variable
# using base R graphics.
# -------------------------------------------------------------
plot_box <- function(df, xvar, xlab){
  
  # Check that xvar exists in the dataframe
  if(!(xvar %in% names(df))){
    stop(paste("Variable does not exist in dataframe:", xvar))
  }
  
  # Prepare formula for boxplot: reward ~ xvar
  formula <- as.formula(paste("reward ~", xvar))
  
  # Create the boxplot for reward
  boxplot(formula,
          data = df,
          main = paste("Reward vs", xlab),
          xlab = xlab,
          ylab = "Reward",
          col = "lightgray",
          border = "black")
  
  # Prepare formula for boxplot: process time ~ xvar
  formula <- as.formula(paste("process_time ~", xvar))
  
  # Create the boxplot for process time
  boxplot(formula,
          data = df,
          main = paste("Process Time vs", xlab),
          xlab = xlab,
          ylab = "Process time [s]",
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