# -------------------------------------------------------------
# Function: get_val
# Retrieves a numeric value from a parameter data frame.
# Returns NA and emits a warning if the parameter is not numeric.
# -------------------------------------------------------------
get_val <- function(df, param) {
  v <- df$value[df$parameter == param]
  if (length(v) == 0) return(NA)
  num <- suppressWarnings(as.numeric(v))
  if (is.na(num)) warning(sprintf(
    "Parameter '%s' could not be converted to numeric: '%s'", param, v))
  num
}
