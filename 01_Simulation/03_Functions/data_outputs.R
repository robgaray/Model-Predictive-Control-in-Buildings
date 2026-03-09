# -------------------------------------------------------------
# Script: data_outputs.R
# Defines write_data_outputs() function
# Called by Main.R and Main_SCC.R
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Arguments:
#   output_path, Main_df, optimization_parameters, t_process
# Optional arguments for SCC parametric runs:
#   param_suffix - string appended to output file names
#                  (e.g. "10_10_3_24_12_0"); when NULL the
#                  default names "Main_df_computed" are used
# -------------------------------------------------------------

write_data_outputs <- function(output_path,
                               Main_df,
                               optimization_parameters,
                               t_process,
                               param_suffix = NULL) {
  if (!dir.exists(output_path)) {
    dir.create(output_path, recursive = TRUE)
  }

  # Build base file names
  if (is.null(param_suffix)) {
    main_name       <- "Main_df_computed"
    sinthetized_name <- "Sinthetized_df_computed"
  } else {
    main_name       <- paste0("Main_df_computed_",       param_suffix)
    sinthetized_name <- paste0("Sinthetized_df_computed_", param_suffix)
  }

  # Main_df
  {
    write.csv(Main_df,
              file.path(output_path, paste0(main_name, ".csv")))
    write_rds(Main_df,
              file.path(output_path, paste0(main_name, ".rds")))
  }

  # Sinthetized
  {
    Sinthetized_df <- data.frame(as.data.frame(optimization_parameters),
                                 elec_total=sum(Main_df$elec_total),
                                 elec_cost=sum(Main_df$elec_cost),
                                 building_comfort=sum(Main_df$building_comfort),
                                 reward=sum(Main_df$reward),
                                 process_time=t_process)

    write.csv(Sinthetized_df,
              file.path(output_path, paste0(sinthetized_name, ".csv")))
    write_rds(Sinthetized_df,
              file.path(output_path, paste0(sinthetized_name, ".rds")))
  }
}
