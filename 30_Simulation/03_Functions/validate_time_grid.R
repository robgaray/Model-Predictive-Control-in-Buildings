# -------------------------------------------------------------
# Function: validate_time_grid.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Validates that a 'time' vector is a well-formed, equispaced POSIXct
# series whose own step is compatible with Main_df's target resolution
# (main_resolution_sec, 300s/5' today). The step itself is NOT assumed
# to be any particular value (e.g. 1h or 15') - that is only the
# resolution of the current dataset, not a requirement; any equispaced
# step that is a multiple of main_resolution_sec is accepted (see
# 01_Agent_Comments/20260722b_Plan_Señales_por_Procedencia.md, Part E).
# -------------------------------------------------------------
# Inputs
#   time               : POSIXct vector. Timestamps to validate.
#   file_name          : Character. Name of the file this series comes
#                        from, used in error messages.
#   main_resolution_sec : Numeric. Target resolution of Main_df, in
#                        seconds (300 today).
# -------------------------------------------------------------
# Outputs
#   Numeric scalar. The detected step (seconds) of this series.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If time is not POSIXct, stop().
#   - If time has fewer than 2 rows, stop() (a step cannot be detected).
#   - If time is not strictly equispaced, stop() indicating the first
#     row where the step changes.
#   - If the detected step is not a positive multiple of
#     main_resolution_sec, stop().
#   - If the series origin (time[1]) does not fall on the
#     main_resolution_sec grid, stop().
# -------------------------------------------------------------
# Where this function/script is used
# Called by load_meteo_df.R and load_energy_prices_df.R.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

validate_time_grid <- function(time, file_name, main_resolution_sec = 300) {

  if (!inherits(time, "POSIXct")) {
    stop(file_name, ": 'time' must be POSIXct")
  }

  if (length(time) < 2) {
    stop(file_name, ": 'time' must have at least 2 rows to detect a step")
  }

  time_num <- as.numeric(time)
  diffs    <- diff(time_num)
  step     <- diffs[1]

  irregular <- which(diffs != step)
  if (length(irregular) > 0) {
    stop(file_name, ": 'time' is not equispaced. Step is ", step,
         "s up to row ", irregular[1], ", but row ", irregular[1] + 1,
         " has a step of ", diffs[irregular[1]], "s")
  }

  if (step < main_resolution_sec) {
    stop(file_name, ": 'time' step (", step, "s) is finer than Main_df's ",
         "target resolution (", main_resolution_sec, "s). No input dataframe ",
         "may have a resolution finer than Main_df's own.")
  }

  if (step %% main_resolution_sec != 0) {
    stop(file_name, ": 'time' step (", step, "s) is not a multiple of ",
         "Main_df's target resolution (", main_resolution_sec, "s)")
  }

  if (time_num[1] %% main_resolution_sec != 0) {
    stop(file_name, ": 'time' origin (", format(time[1]), ") does not fall ",
         "on Main_df's ", main_resolution_sec, "s grid")
  }

  return(step)
}
