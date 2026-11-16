# -------------------------------------------------------------
# Script: load_meteo_df.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Loads Meteo_df (weather input data: Text, SolarR) from disk and
# validates it before it is used by assemble_main_df.R.
# -------------------------------------------------------------
# Inputs
#   paths$meteo_file            : Character. Path to Meteo_df.rds.
#   paths$meteo_validation_file : Character. Path to
#                                 Validation_Meteo_df.csv.
# -------------------------------------------------------------
# Outputs
#   Meteo_df       : Data frame, with the columns:
#                      - time (POSIXct)
#                      - Text
#                      - SolarR
#   meteo_step_sec : Numeric. Detected step (seconds) of Meteo_df$time.
# -------------------------------------------------------------
# Code outline
# 1. Check that Meteo_df.rds exists and read it
# 2. Validate required columns are present and numeric
# 3. Validate the time grid (equispaced, compatible with Main_df's
#    resolution)
# 4. Validate column ranges against Validation_Meteo_df.csv
# -------------------------------------------------------------
# Usage instructions
# source(file.path("30_Simulation", "04_Scripts", "load_meteo_df.R"))
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by assemble_main_df.R while it builds
#   Main_df out of the input series.
# -------------------------------------------------------------

{
  # initialize_simulator() does not require the input series, so that
  # the simulator can be loaded without them. Their existence is
  # checked here, where they are read.
  if (!file.exists(paths$meteo_file)) {
    stop("Missing required file:\n", paths$meteo_file)
  }
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
  meteo_step_sec <- validate_time_grid(
    time                = Meteo_df$time,
    file_name           = "Meteo_df.rds",
    main_resolution_sec = parameters$computing$main_resolution_sec
  )

  meteo_validation_config <- read.csv(
    paths$meteo_validation_file,
    comment.char     = "#",
    stringsAsFactors = FALSE
  )
  # validate_dataframe_config is called to check every column of
  # Meteo_df against the ranges defined in Validation_Meteo_df.csv.
  validate_dataframe_config(Meteo_df, "Meteo_df.rds", meteo_validation_config)
  rm(list = c("meteo_validation_config", "required_cols", "missing_cols"))
}
