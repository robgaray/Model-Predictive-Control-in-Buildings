# -------------------------------------------------------------
# Script: csv_to_rds.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This script converts all CSV data files found in the 01_Input/
# subdirectory into RDS format and saves the results to 90_Output/.
# Each CSV file is expected to contain a 'time' column (accepted
# formats: "YYYY-MM-DD HH:MM:SS" or "YYYY-MM-DD") plus numeric
# data columns.  The 'time' column is parsed to POSIXct (UTC) and
# all other columns are coerced to numeric.
# -------------------------------------------------------------
# Usage
#   Run from the repository root:
#     Rscript 10_Utils_data/01_csv_to_rds/csv_to_rds.R
#   Or source from an interactive R session with the repo root as
#   the working directory.
# -------------------------------------------------------------
# Output files (in 10_Utils_data/01_csv_to_rds/90_Output/)
#   <filename>.rds : one RDS file per CSV found in 01_Input/
# -------------------------------------------------------------

# ---- Initialization ----
{
  rm(list = ls())
  gc()
  options(stringsAsFactors = FALSE)
}

# ---- Required libraries ----
library(dplyr)
library(readr)
library(lubridate)
library(tools)

# ----------------------------------------------------------------
# 0. Paths
# ----------------------------------------------------------------
if (dir.exists("10_Utils_data/01_csv_to_rds")) {
  base_dir <- "10_Utils_data/01_csv_to_rds"
} else if (dir.exists("01_Input")) {
  base_dir <- "."
} else {
  stop("Cannot locate 10_Utils_data/01_csv_to_rds directory. ",
       "Run this script from the repository root or from ",
       "10_Utils_data/01_csv_to_rds/.")
}

input_dir  <- file.path(base_dir, "01_Input")
output_dir <- file.path(base_dir, "90_Output")

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

cat("Input directory: ", input_dir,  "\n")
cat("Output directory:", output_dir, "\n")

# ----------------------------------------------------------------
# 1. Find input CSV files
# ----------------------------------------------------------------
csv_files <- list.files(path = input_dir, pattern = "\\.csv$",
                        full.names = TRUE, ignore.case = TRUE)

if (length(csv_files) == 0) {
  stop("No CSV files were found in: ", input_dir)
}

cat("Found", length(csv_files), "CSV file(s) to process.\n\n")

# ----------------------------------------------------------------
# 2. Convert each CSV to RDS
# ----------------------------------------------------------------
for (CONT_001 in csv_files) {

  base_name <- file_path_sans_ext(basename(CONT_001))
  cat("Processing:", base_name, "\n")

  # Read CSV; read_csv is faster than read.csv and does not
  # convert strings to factors by default.
  df <- read_csv(CONT_001, show_col_types = FALSE)

  # Parse time column and coerce all other columns to numeric
  clean_df <- df %>%
    mutate(
      time = parse_date_time(time, orders = c("ymd HMS", "ymd"), tz = "UTC"),
      across(-time, as.numeric)
    )

  output_path <- file.path(output_dir, paste0(base_name, ".rds"))
  saveRDS(clean_df, file = output_path)

  cat("  Saved:", output_path, "\n")
}

cat("\nAll files converted successfully.\n")
cat("Outputs saved to:", output_dir, "\n")
