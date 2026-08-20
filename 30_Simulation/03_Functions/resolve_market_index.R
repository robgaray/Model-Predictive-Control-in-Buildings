# -------------------------------------------------------------
# Function: resolve_market_index.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Converts a market timestamp to its index position in a
# reference time vector.
# -------------------------------------------------------------
# Inputs
# time_raw    : Scalar value with the timestamp to locate.
# column_name : Character. Source column name for error messages.
# row_index   : Integer. Current simulation row for error messages.
# time_vector : POSIXct vector where the timestamp must exist.
# -------------------------------------------------------------
# Outputs
# Integer index position in time_vector.
# -------------------------------------------------------------
# Usage instructions
# resolve_market_index(time_raw, column_name, row_index, time_vector)
# -------------------------------------------------------------
# Where this function/script is used
# Called by simulation.R only (no longer called from
# run_market_process()).
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

resolve_market_index <- function(time_raw,
                                 column_name,
                                 row_index,
                                 time_vector) {
  time_chr <- trimws(as.character(time_raw)[1])
  time_posix <- suppressWarnings(as.POSIXct(time_chr, tz = "UTC"))

  if (is.na(time_posix)) {
    stop("Invalid market timestamp at row ", row_index,
         " in column ", column_name, ": ", time_chr)
  }

  idx <- match(time_posix, time_vector)
  if (is.na(idx)) {
    stop("Market timestamp not found at row ", row_index,
         " in column ", column_name, ": ",
         format(time_posix, "%Y-%m-%d %H:%M:%S"))
  }

  return(as.integer(idx))
}
