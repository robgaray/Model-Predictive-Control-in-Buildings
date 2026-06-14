# -------------------------------------------------------------
# Function: read_param_csv
# Reads a parameter CSV (parameter,value) ignoring comment lines.
# config_path must be defined in the calling environment.
# -------------------------------------------------------------
read_param_csv <- function(filename) {
  path <- file.path(config_path, filename)
  df <- read.csv(path, comment.char = "#", strip.white = TRUE,
                 stringsAsFactors = FALSE)
  df
}
