# -------------------------------------------------------------
# Script: load_meteo_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Loads Meteo_df (weather input data: Text, SolarR) from disk and
# validates it before it is used by assemble_main_df.R. See
# 01_Agent_Comments/20260722b_Plan_Señales_por_Procedencia.md, Part E,
# for the rationale of each protection.
# -------------------------------------------------------------
# Inputs
#   paths$meteo_file            : Character. Path to Meteo_df.rds.
#   paths$meteo_validation_file : Character. Path to
#                                 Validation_Meteo_df.csv.
# -------------------------------------------------------------
# Outputs
#   Meteo_df       : Data frame. Columns: time (POSIXct), Text, SolarR.
#   meteo_step_sec : Numeric. Detected step (seconds) of Meteo_df$time.
# -------------------------------------------------------------
# Code outline
# 1. Read Meteo_df.rds
# 2. Validate required columns are present and numeric
# 3. Validate the time grid (equispaced, compatible with Main_df's
#    resolution)
# 4. Validate column ranges against Validation_Meteo_df.csv
# -------------------------------------------------------------
# Usage
# source(file.path("30_Simulation", "04_Scripts", "load_meteo_df.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by assemble_main_df.R.
# -------------------------------------------------------------
# functions/scripts called
#   validate_time_grid(), validate_dataframe_config()
#   -- from 30_Simulation/03_Functions/
# -------------------------------------------------------------

{
  Meteo_df <- readRDS(paths$meteo_file)

  required_cols <- c("time", "Text", "SolarR")
  missing_cols  <- setdiff(required_cols, names(Meteo_df))
  if (length(missing_cols) > 0) {
    stop("Meteo_df.rds is missing required columns: ",
         paste(missing_cols, collapse = ", "))
  }

  # validate_time_grid is called to check that Meteo_df$time is an
  # equispaced grid compatible with Main_df's own resolution, and to
  # return its detected step in seconds.
  meteo_step_sec <- validate_time_grid(Meteo_df$time, "Meteo_df.rds")

  meteo_validation_config <- read.csv(
    paths$meteo_validation_file,
    comment.char     = "#",
    stringsAsFactors = FALSE
  )
  # validate_dataframe_config is called to check every column of
  # Meteo_df against the ranges defined in Validation_Meteo_df.csv.
  validate_dataframe_config(Meteo_df, "Meteo_df.rds", meteo_validation_config)
  rm(meteo_validation_config, required_cols, missing_cols)

  cat("Meteo_df loaded and validated:", nrow(Meteo_df), "rows, step =",
      meteo_step_sec, "s\n")
}
