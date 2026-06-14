# -------------------------------------------------------------
# Script: data_outputs.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This script exports the simulation results to CSV and RDS files.
# It is sourced from Main.R.
# -------------------------------------------------------------
# Inputs
# Main_df : Data frame. Simulation results.
# parameters : List. Contains optimization sub-list.
# execution_time : List. Timing information.
# paths : List. Must include paths$output_path (path to the output directory).
# -------------------------------------------------------------
# Outputs
# (none) - writes CSV and RDS files to output_path.
# -------------------------------------------------------------
# Code outline
# 1. Create output directory if needed
# 2. Export Main_df to CSV and RDS
# 3. Build and export synthesized summary data frame
# -------------------------------------------------------------
# Usage
# source(file.path("30_Simulation", "04_Scripts", "data_outputs.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by Main.R as the final step.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

{
  if (!dir.exists(paths$output_path)) {
    dir.create(paths$output_path, recursive = TRUE)
  }
	
  # Main_df
  {
    write.csv(Main_df,
              file.path(paths$output_path, "Main_df_computed.csv"))
    write_rds(Main_df,
              file.path(paths$output_path, "Main_df_computed.rds"))
  }

  # Sinthetized
  {
    Sinthetized_df <- data.frame(as.data.frame(parameters$optimization),
                                 Elec_total   = sum(Main_df$Elec_total),
                                 Elec_Cost    = sum(Main_df$Elec_Cost),
                                 Comfort      = sum(Main_df$Comfort),
                                 reward       = sum(Main_df$Reward),
                                 process_time = execution_time$t_process)
	
    write.csv(Sinthetized_df,
              file.path(paths$output_path, "Sinthetized_df_computed.csv"))
    write_rds(Sinthetized_df,
              file.path(paths$output_path, "Sinthetized_df_computed.rds"))
    rm(Sinthetized_df)
  }
}
