# -------------------------------------------------------------
# Function: console_duration.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Formats a duration in seconds as h:mm:ss, for the elapsed and the
# remaining time written in the console.
# -------------------------------------------------------------
# Inputs
# seconds : Numeric. Duration in seconds.
# -------------------------------------------------------------
# Outputs
# Character. The duration as "h:mm:ss", rounded to the second.
# -------------------------------------------------------------
# Code outline
# 1. Split into hours, minutes and seconds
# -------------------------------------------------------------
# Usage instructions
# console_duration(3725)  # "1:02:05"
# -------------------------------------------------------------

console_duration <- function(seconds) {

  # -------------------------------------------------------------
  # 1. Split into hours, minutes and seconds
  # -------------------------------------------------------------
  {
    total   <- round(seconds)
    hours   <- total %/% 3600
    minutes <- (total %% 3600) %/% 60
    secs    <- total %% 60

    result  <- sprintf("%d:%02d:%02d", hours, minutes, secs)
  }

  rm(list = c("total", "hours", "minutes", "secs"))

  return(result)
}
