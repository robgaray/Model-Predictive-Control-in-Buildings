# -------------------------------------------------------------
# Script: download_data.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This script orchestrates the download of all external input
# data required by the MPC simulation:
#   1. Electricity market price indicators from ESIOS (EUR/kWh):
#        Precio_Pool_Spot, Precio_Banda_Secundaria,
#        Precio_Terciaria_Subir, Precio_Terciaria_Bajar,
#        Precio_Desvio_Subir, Precio_Desvio_Bajar
#   2. Hourly weather data from Open-Meteo (temperature in °C,
#      solar irradiance in W/m²)
# All datasets are converted to 15-minute resolution (no
# interpolation: hourly values are repeated for each 15-min
# slot within the hour) and saved as CSV and RDS files in
# the 90_Output/ subdirectory.
# -------------------------------------------------------------
# Usage
# 1. Set the configuration parameters in the "Configuration"
#    section below.
# 2. Place your ESIOS API token in 02_Config/esios_api_token.txt
#    (request a token at esios.ree.es).
# 3. Run from the repository root:
#      Rscript 10_Utils_data/02_download_data/download_data.R
#    Or source from an interactive R session with the repo root
#    as the working directory.
# -------------------------------------------------------------
# Output files (in 10_Utils_data/02_download_data/90_Output/)
#   data_df.csv : merged data frame (CSV)
#   data_df.rds : merged data frame (RDS)
# -------------------------------------------------------------

# ---- Initialization ----
{
  rm(list = ls())
  gc()
  options(stringsAsFactors = FALSE)
}

# ---- Required libraries ----
library(httr)
library(jsonlite)
library(lubridate)
library(dplyr)

# ----------------------------------------------------------------
# 0. Paths
# ----------------------------------------------------------------
if (dir.exists("10_Utils_data/02_download_data")) {
  base_dir <- "10_Utils_data/02_download_data"
} else if (dir.exists("01_Input")) {
  base_dir <- "."
} else {
  stop("Cannot locate 10_Utils_data/02_download_data directory. ",
       "Run this script from the repository root or from ",
       "10_Utils_data/02_download_data/.")
}

config_dir <- file.path(base_dir, "02_Config")
func_dir   <- file.path(base_dir, "03_Functions")
output_dir <- file.path(base_dir, "90_Output")

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

cat("Config directory: ", config_dir,  "\n")
cat("Output directory:", output_dir, "\n")

# ---- Source functions ----
source(file.path(func_dir, "expand_to_15min.R"))
source(file.path(func_dir, "download_single_indicator.R"))
source(file.path(func_dir, "download_esios_prices.R"))
source(file.path(func_dir, "download_open_meteo.R"))

# ----------------------------------------------------------------
# 1. Configuration
# ----------------------------------------------------------------
# Modify these parameters to match your use case.
{
  # Date range to download (inclusive)
  start_date <- "2019-01-01"
  end_date   <- "2019-12-31"

  # ESIOS API token: read from 02_Config/esios_api_token.txt
  # Lines starting with '#' and blank lines are ignored.
  token_file <- file.path(config_dir, "esios_api_token.txt")
  if (file.exists(token_file)) {
    token_lines <- readLines(token_file, warn = FALSE)
    token_lines <- token_lines[!grepl("^\\s*#", token_lines)]
    token_lines <- trimws(token_lines)
    token_lines <- token_lines[nchar(token_lines) > 0]
    esios_api_token <- if (length(token_lines) > 0) token_lines[1] else ""
  } else {
    esios_api_token <- Sys.getenv("ESIOS_API_TOKEN", unset = "")
    if (nchar(esios_api_token) == 0) {
      warning(paste(
        "Config file not found:", token_file,
        "\nFalling back to ESIOS_API_TOKEN environment variable (also not set)."
      ))
    }
  }

  # ESIOS indicators: read from 02_Config/esios_indicators.txt
  # Format: variable_name = indicator_id  (one per line, '#' lines ignored)
  # Note: inline comments (trailing '#') are not supported.
  indicators_file <- file.path(config_dir, "esios_indicators.txt")
  if (!file.exists(indicators_file)) {
    stop("ESIOS indicators file not found: ", indicators_file)
  }
  ind_lines <- readLines(indicators_file, warn = FALSE)
  ind_lines <- ind_lines[!grepl("^\\s*#", ind_lines)]
  ind_lines <- trimws(ind_lines)
  ind_lines <- ind_lines[nchar(ind_lines) > 0]
  ind_parts <- strsplit(ind_lines, "\\s*=\\s*")
  malformed <- which(sapply(ind_parts, length) != 2)
  if (length(malformed) > 0) {
    stop("Malformed line(s) in ", indicators_file,
         " (expected 'variable_name = indicator_id'): ",
         paste(ind_lines[malformed], collapse = "; "))
  }
  esios_indicators <- setNames(
    trimws(sapply(ind_parts, `[`, 2)),
    trimws(sapply(ind_parts, `[`, 1))
  )
  cat("Loaded", length(esios_indicators), "ESIOS indicators from", indicators_file, "\n")

  # ESIOS API base URL
  esios_base_url <- "https://api.esios.ree.es"

  # Building / site location (decimal degrees, WGS84)
  # Default: Bilbao, Spain
  site_latitude  <- 43.263
  site_longitude <- -2.935

  # Timezone for the site (used when interpreting Open-Meteo timestamps)
  site_timezone <- "Europe/Madrid"

  # ESIOS geographic area ID for price aggregation
  # 8741 = Peninsular Spain (default)
  esios_geo_id <- 8741
}

# ----------------------------------------------------------------
# 2. Validate configuration
# ----------------------------------------------------------------
{
  if (nchar(trimws(esios_api_token)) == 0 ||
      grepl("YOUR_ESIOS_API_TOKEN_HERE", esios_api_token)) {
    warning(paste(
      "ESIOS API token is not set.",
      "Edit 02_Config/esios_api_token.txt and replace the placeholder with",
      "your actual token (request at https://www.esios.ree.es/en/access-my-esios).",
      "Electricity price download will be skipped."
    ))
    skip_esios <- TRUE
  } else {
    skip_esios <- FALSE
  }
}

# ----------------------------------------------------------------
# 3. Download electricity prices (ESIOS)
# ----------------------------------------------------------------
{
  if (!skip_esios) {
    cat("--- Downloading electricity prices from ESIOS ---\n")
    prices_df <- download_esios_prices(
      api_token        = esios_api_token,
      start_date       = start_date,
      end_date         = end_date,
      geo_id           = esios_geo_id,
      esios_indicators = esios_indicators,
      base_url         = esios_base_url
    )
    if (is.null(prices_df)) {
      warning("ESIOS download failed. Electricity prices will be set to NA.")
      prices_df <- NULL
    }
  } else {
    cat("Skipping ESIOS download (no API token).\n")
    prices_df <- NULL
  }
}

# ----------------------------------------------------------------
# 4. Download weather data (Open-Meteo)
# ----------------------------------------------------------------
{
  cat("--- Downloading weather data from Open-Meteo ---\n")
  weather_df <- download_open_meteo(
    latitude   = site_latitude,
    longitude  = site_longitude,
    start_date = start_date,
    end_date   = end_date,
    timezone   = site_timezone
  )
  if (is.null(weather_df)) {
    stop("Open-Meteo download failed. Cannot continue without weather data.")
  }

  # Expand hourly weather data to 15-minute resolution
  # (repeat same value for all four slots within each hour)
  t_start <- floor_date(min(weather_df$time), unit = "hour")
  t_end   <- floor_date(max(weather_df$time), unit = "hour") + 45 * 60
  grid_15 <- data.frame(time = seq(t_start, t_end, by = "15 min"))
  grid_15$time_hour  <- floor_date(grid_15$time,     unit = "hour")
  weather_df$time_hour <- floor_date(weather_df$time, unit = "hour")
  weather_df <- merge(grid_15,
                      weather_df[, c("time_hour", "Text", "SolarR")],
                      by = "time_hour", all.x = TRUE)
  weather_df$time_hour <- NULL
  weather_df <- weather_df[order(weather_df$time), ]
  cat("Weather data expanded to", nrow(weather_df), "15-min records\n")
}

# ----------------------------------------------------------------
# 5. Merge into a single data frame
# ----------------------------------------------------------------
{
  cat("--- Merging datasets ---\n")

  # Start from 15-min weather data
  data_df <- weather_df

  # Join electricity prices if available
  if (!is.null(prices_df) && nrow(prices_df) > 0) {
    data_df <- merge(data_df, prices_df, by = "time", all.x = TRUE)
  } else {
    for (CONT_001 in names(esios_indicators)) {
      data_df[[CONT_001]] <- NA_real_
    }
  }

  # Ensure consistent column order
  price_cols <- names(esios_indicators)
  data_df <- data_df[, c("time", "Text", "SolarR", price_cols)]

  # Sort by time
  data_df <- data_df[order(data_df$time), ]

  cat("Merged data frame: ", nrow(data_df), "rows x", ncol(data_df), "columns\n")
  cat("Time range:", format(min(data_df$time)), "to", format(max(data_df$time)), "\n")
  cat("Columns:", paste(names(data_df), collapse = ", "), "\n")
}

# ----------------------------------------------------------------
# 6. Save output
# ----------------------------------------------------------------
{
  cat("--- Saving output ---\n")

  output_csv <- file.path(output_dir, "data_df.csv")
  output_rds <- file.path(output_dir, "data_df.rds")

  write.csv(data_df, output_csv, row.names = FALSE)
  saveRDS(data_df,   output_rds)

  cat("Saved CSV :", output_csv, "\n")
  cat("Saved RDS :", output_rds, "\n")
  cat("Done.\n")
}
