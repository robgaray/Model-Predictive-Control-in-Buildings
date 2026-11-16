# -------------------------------------------------------------
# Function: write_use_patterns_file.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Writes 14_Use_Patterns.csv from the two tables the user edited:
# a comment header, the hourly profiles with their units row, and
# the monthly mapping with its units row. It writes the
# already-validated state of the app.
# It writes into config_path, the configuration folder
# GUI_config.R resolves at start.
# -------------------------------------------------------------
# Inputs
#   filename         : Character. Path of the configuration file,
#                      relative to config_path.
#   day_types_df     : Data frame. The hourly profiles table
#                      (TYPE, H01..H24).
#   month_profiles_df: Data frame. The monthly mapping table
#                      (MONTH, D01..D07).
# -------------------------------------------------------------
# Outputs
#   None; the file is written.
# -------------------------------------------------------------
# Code outline
# 1. Write the header and the hourly profiles.
# 2. Write the monthly mapping.
# -------------------------------------------------------------
# Usage instructions
# Sourced by GUI_config.R into the app's own environment, with
# every file of 20_GUI/01_Configure_Simulation/03_Functions.
#   write_use_patterns_file(
#     filename,
#     day_types_df,
#     month_profiles_df)
# -------------------------------------------------------------

write_use_patterns_file <- function(
    filename,
    day_types_df,
    month_profiles_df
) {
  con <- file(file.path(config_path, filename), open = "wt")
  on.exit(close(con), add = TRUE)

  writeLines(
    c(
      "# Occupancy use patterns configuration file",
      "# -------------------------------------------------------------",
      "# Day type profiles by hour"
    ),
    con
  )

  write.csv(
    rbind(
      setNames(
        as.data.frame(
          as.list(c("text", rep("-(boolean 0/1)",
                                 max(0, ncol(day_types_df) - 1)))),
          stringsAsFactors = FALSE
        ),
        names(day_types_df)
      ),
      day_types_df
    ),
    con,
    row.names = FALSE,
    quote = FALSE
  )

  writeLines(
    c(
      "",
      "# -------------------------------------------------------------",
      "# Monthly mapping by weekday (D01 = Monday, D07 = Sunday)"
    ),
    con
  )

  write.csv(
    rbind(
      setNames(
        as.data.frame(
          as.list(c("text", rep("text",
                                 max(0, ncol(month_profiles_df) - 1)))),
          stringsAsFactors = FALSE
        ),
        names(month_profiles_df)
      ),
      month_profiles_df
    ),
    con,
    row.names = FALSE,
    quote = FALSE
  )
}
