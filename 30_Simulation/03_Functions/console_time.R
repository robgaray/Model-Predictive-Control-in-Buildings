# -------------------------------------------------------------
# Function: console_time.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Formats an instant of the simulation for the console. Every
# instant is written with the same format, the hour included also
# at midnight, so that the columns of the console keep their width.
# console_message() writes its instant column with it, and the
# messages that quote an instant in their text use it too.
# -------------------------------------------------------------
# Inputs
# x : POSIXct vector, or NULL. A character vector that writes
#     instants is accepted too, and read as written.
# -------------------------------------------------------------
# Outputs
# Character vector, one element per instant, as
# "YYYY-MM-DD hh:mm:ss". NULL for NULL.
# -------------------------------------------------------------
# Code outline
# 1. Format
# -------------------------------------------------------------
# Usage instructions
# console_time(Main_df$time[1])
# -------------------------------------------------------------

console_time <- function(x) {

  # -------------------------------------------------------------
  # 1. Format
  # NULL stays NULL, so that a line with no instant is possible. An
  # instant written as text is read back with its own time zone.
  # -------------------------------------------------------------
  {
    if (is.null(x)) {
      return(NULL)
    }

    if (is.character(x)) {
      x <- as.POSIXct(x, tz = "UTC")
    }

    result <- format(x, format = "%Y-%m-%d %H:%M:%S")
  }

  return(result)
}
