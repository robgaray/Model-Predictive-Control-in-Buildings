# -------------------------------------------------------------
# Function: validate_occupancy_dfs_gui.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Checks the two tables of 14_Use_Patterns.csv before saving:
# every hourly profile holds only 0 and 1, and every month maps
# each weekday to a profile that exists.
# -------------------------------------------------------------
# Inputs
#   day_types_df     : Data frame. The hourly profiles table
#                      (TYPE, H01..H24).
#   month_profiles_df: Data frame. The monthly mapping table
#                      (MONTH, D01..D07).
# -------------------------------------------------------------
# Outputs
#   Character vector: one message per invalid profile or month,
#   empty when all are valid.
# -------------------------------------------------------------
# Code outline
# 1. Check each hourly profile.
# 2. Check that each month references existing profiles only.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   validate_occupancy_dfs_gui(day_types_df, month_profiles_df)
# -------------------------------------------------------------

validate_occupancy_dfs_gui <- function(day_types_df, month_profiles_df) {
  errors        <- character(0)
  hour_cols     <- paste0("H", sprintf("%02d", 1:24))
  weekday_cols  <- paste0("D", sprintf("%02d", 1:7))

  for (CONT_104 in seq_len(nrow(day_types_df))) {
    if (!day_type_row_valid(day_types_df[CONT_104, hour_cols])) {
      errors <- c(errors, sprintf(
        "Occupancy: hourly profile '%s' contains values other than 0/1.",
        day_types_df$TYPE[CONT_104]
      ))
    }
  }

  valid_types <- trimws(as.character(day_types_df$TYPE))
  for (CONT_105 in seq_len(nrow(month_profiles_df))) {
    refs <- trimws(as.character(unlist(month_profiles_df[CONT_105, weekday_cols])))
    if (!all(refs %in% valid_types)) {
      errors <- c(errors, sprintf(
        "Occupancy: month '%s' references a nonexistent hourly profile.",
        month_profiles_df$MONTH[CONT_105]
      ))
    }
  }

  errors
}
