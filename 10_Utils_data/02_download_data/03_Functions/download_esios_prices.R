# -------------------------------------------------------------
# Function: download_esios_prices.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Downloads all configured electricity market price indicators
# from the ESIOS API (Red Eléctrica de España Information System)
# for a given date range, and returns a single data frame at
# 15-minute resolution.
# -------------------------------------------------------------
# INPUT:
#   api_token        : Character. Personal ESIOS API token
#                      (request at esios.ree.es).
#   start_date       : Date or character "YYYY-MM-DD". First day to
#                      download (inclusive).
#   end_date         : Date or character "YYYY-MM-DD". Last day to
#                      download (inclusive).
#   geo_id           : Integer. Geographic aggregation ID.
#                      Default: 8741 (Peninsular Spain).
#   esios_indicators : Named character vector mapping variable names
#                      to ESIOS indicator IDs, e.g.
#                      c("Precio_Pool_Spot" = "600", ...).
#                      Read from 02_Config/esios_indicators.txt by
#                      download_data.R and passed here explicitly.
#   base_url         : Character. ESIOS API base URL,
#                      e.g. "https://api.esios.ree.es".
#                      Defined in download_data.R and passed here.
#
# OUTPUT:
#   Data frame with columns (all prices in EUR/kWh):
#     time                    : POSIXct (UTC, 15-min resolution).
#     <one column per entry in esios_indicators>
#   Every indicator listed in esios_indicators is guaranteed to
#   appear as a column; indicators unavailable from the API have
#   NA values.
#   Returns NULL if no data could be downloaded for any indicator.
# -------------------------------------------------------------
# FUNCTIONS USED (from this repository):
#   download_single_indicator() - downloads one ESIOS indicator.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - start_date and end_date are coerced to Date; stop() is
#     called if either is NA or if end_date < start_date.
#   - stop() is called if api_token is missing or blank.
#   - Indicators that fail individually produce NA-filled columns;
#     NULL is returned only if ALL indicators fail.
# -------------------------------------------------------------

# ---- Function definition ----
download_esios_prices <- function(api_token,
                                  start_date,
                                  end_date,
                                  geo_id           = 8741,
                                  esios_indicators,
                                  base_url) {

  # Validate inputs
  start_date <- as.Date(start_date)
  end_date   <- as.Date(end_date)

  if (is.na(start_date) || is.na(end_date)) {
    stop("start_date and end_date must be valid dates (YYYY-MM-DD).")
  }
  if (end_date < start_date) {
    stop("end_date must be on or after start_date.")
  }
  if (missing(api_token) || nchar(trimws(api_token)) == 0) {
    stop("A valid ESIOS API token must be provided.")
  }
  if (missing(esios_indicators) || length(esios_indicators) == 0) {
    stop("esios_indicators must be a non-empty named character vector.")
  }
  if (missing(base_url) || nchar(trimws(base_url)) == 0) {
    stop("A valid ESIOS base URL must be provided.")
  }

  cat("Downloading ESIOS prices from", format(start_date), "to", format(end_date), "\n")

  result_df <- NULL

  for (CONT_001 in names(esios_indicators)) {
    ind_id <- esios_indicators[[CONT_001]]
    cat("Downloading indicator:", CONT_001, "(ID:", ind_id, ")\n")

    ind_df <- download_single_indicator(api_token, ind_id, CONT_001,
                                        start_date, end_date, geo_id,
                                        base_url)

    if (is.null(result_df)) {
      if (!is.null(ind_df)) {
        result_df <- ind_df
      }
      # ind_df is NULL and result_df is not yet initialized: skip this
      # indicator now; a NA column will be added after the loop.
    } else {
      if (!is.null(ind_df)) {
        result_df <- merge(result_df, ind_df, by = "time", all = TRUE)
      } else {
        # Indicator unavailable: add column with NA values
        result_df[[CONT_001]] <- NA_real_
      }
    }
  }

  if (is.null(result_df)) {
    message("No price data downloaded.")
    return(NULL)
  }

  # Ensure every expected indicator column is present (NA if missing).
  # This covers indicators that failed before result_df was initialized
  # (i.e. the first N indicators all failed); those were not caught by
  # the NA assignment inside the loop above.
  for (CONT_002 in names(esios_indicators)) {
    if (!CONT_002 %in% names(result_df)) {
      result_df[[CONT_002]] <- NA_real_
    }
  }

  result_df <- result_df[order(result_df$time), ]

  cat("Downloaded", nrow(result_df), "15-min price records with",
      ncol(result_df) - 1, "indicators\n")

  return(result_df)
}
