# -------------------------------------------------------------
# Script: data_outputs_SCC.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This script exports the simulation results to CSV and RDS
# files for supercomputer cluster (SCC) parametric simulations.
# Output filenames include all run parameters as a suffix so
# that results from different configurations do not overwrite
# each other.
# Example suffix:
#   10_10_3_0_0.1_24_12_12_1_1_2_2_2_1_4_10_0
# It is sourced from Main_SCC.R.
# -------------------------------------------------------------
# Inputs
#   Main_df          : Data frame. Simulation results.
#   parameters       : List. Contains optimization sub-list.
#   execution_time   : List. Timing information.
#   paths            : List. Must include paths$output_path (path to output directory).
#   scc_run_params   : List. 17 SCC command-line parameters.
#   SCC_OUTPUT_FORMATS : Environment variable. Comma-separated
#     list of output flags: main_csv, main_rds, synth_csv,
#     synth_rds.
# -------------------------------------------------------------
# Outputs
#   Main_df_computed_<suffix>.csv / .rds
#   Sinthetized_df_computed_<suffix>.csv / .rds
# -------------------------------------------------------------
# Code outline
#   1. Build filename suffix from SCC run parameters
#   2. Determine output format flags
#   3. Write Main_df to CSV and/or RDS
#   4. Build and write Sinthetized_df to CSV and/or RDS
# -------------------------------------------------------------
# Usage instructions
#   source(file.path("31_SCC_Simulation",
#                    "data_outputs_SCC.R"))
# -------------------------------------------------------------
# Where this script is used
#   Sourced by Main_SCC.R as the final step.
# -------------------------------------------------------------
# functions/scripts called
#   (none - base R only)
# -------------------------------------------------------------

{
  # -------------------------------------------------------------
  # 1. Build filename suffix from SCC run parameters
  # -------------------------------------------------------------
  suffix <- paste(
    scc_run_params$population_size,
    scc_run_params$iteration_number,
    scc_run_params$run_number,
    scc_run_params$pcrossover,
    scc_run_params$pmutation,
    scc_run_params$control_optimization_horizon,
    scc_run_params$control_implementation_horizon,
    scc_run_params$control_optimization_anticipation,
    scc_run_params$control_type,
    scc_run_params$optimization_aim,
    scc_run_params$flexibility_event_length_max,
    scc_run_params$flexibility_recover_timespan,
    scc_run_params$thermal_stabilization_timespan,
    scc_run_params$minimum_flexibility,
    scc_run_params$flexibility_splits,
    scc_run_params$Alpha_Service_Min,
    scc_run_params$month_subset,
    sep = "_"
  )
  
  if (!dir.exists(paths$output_path)) {
    dir.create(paths$output_path, recursive = TRUE)
  }
  
  # -------------------------------------------------------------
  # 2. Determine which output formats to write
  # Format flags: main_csv, main_rds, synth_csv, synth_rds
  # -------------------------------------------------------------
  scc_output_formats_raw <- Sys.getenv("SCC_OUTPUT_FORMATS",
                                       unset = "main_csv,main_rds,synth_csv,synth_rds")
  scc_output_formats     <- trimws(unlist(strsplit(scc_output_formats_raw, ",")))
  write_main_csv_flag    <- "main_csv"  %in% scc_output_formats
  write_main_rds_flag    <- "main_rds"  %in% scc_output_formats
  write_synth_csv_flag   <- "synth_csv" %in% scc_output_formats
  write_synth_rds_flag   <- "synth_rds" %in% scc_output_formats
  
  # -------------------------------------------------------------
  # 3. Main_df output
  # -------------------------------------------------------------
  {
    if (write_main_csv_flag) {
      write.csv(Main_df,
                file.path(paths$output_path, paste0("Main_df_computed_", suffix, ".csv")))
    }
    if (write_main_rds_flag) {
      write_rds(Main_df,
                file.path(paths$output_path, paste0("Main_df_computed_", suffix, ".rds")))
    }
  }
  
  # -------------------------------------------------------------
  # 4. Sinthetized_df output
  # -------------------------------------------------------------
  {
    Sinthetized_df <- data.frame(as.data.frame(parameters$optimization),
                                 control_type                   = scc_run_params$control_type,
                                 optimization_aim               = scc_run_params$optimization_aim,
                                 flexibility_event_length_max   = scc_run_params$flexibility_event_length_max,
                                 flexibility_recover_timespan   = scc_run_params$flexibility_recover_timespan,
                                 thermal_stabilization_timespan = scc_run_params$thermal_stabilization_timespan,
                                 minimum_flexibility            = scc_run_params$minimum_flexibility,
                                 flexibility_splits             = scc_run_params$flexibility_splits,
                                 Alpha_Service_Min                  = scc_run_params$Alpha_Service_Min,
                                 month_subset                   = scc_run_params$month_subset,
                                 Elec_total   = sum(Main_df$Elec_total),
                                 Elec_Cost    = sum(Main_df$Elec_Cost),
                                 Comfort      = sum(Main_df$Comfort),
                                 reward       = sum(Main_df$Reward),
                                 process_time = execution_time$t_process)
    
    if (write_synth_csv_flag) {
      write.csv(Sinthetized_df,
                file.path(paths$output_path, paste0("Sinthetized_df_computed_", suffix, ".csv")))
    }
    if (write_synth_rds_flag) {
      write_rds(Sinthetized_df,
                file.path(paths$output_path, paste0("Sinthetized_df_computed_", suffix, ".rds")))
    }
    rm(Sinthetized_df, suffix)
    rm(scc_output_formats_raw, scc_output_formats)
    rm(write_main_csv_flag, write_main_rds_flag)
    rm(write_synth_csv_flag, write_synth_rds_flag)
  }
}
