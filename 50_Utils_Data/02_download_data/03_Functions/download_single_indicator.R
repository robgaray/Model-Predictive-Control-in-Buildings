# -------------------------------------------------------------
# Function: download_single_indicator.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Downloads data for one ESIOS indicator for a given date range
# and geographic area, and returns a data frame at 15-minute
# resolution.
# -------------------------------------------------------------
# INPUT:
#   api_token      : Character. Personal ESIOS API token.
#   indicator_id   : Character. ESIOS indicator numeric ID (as string).
#   indicator_name : Character. Column name to use for the downloaded
#                   values in the returned data frame.
#   start_date     : Date or character "YYYY-MM-DD". First day to
#                   download (inclusive).
#   end_date       : Date or character "YYYY-MM-DD". Last day to
#                   download (inclusive).
#   geo_id         : Integer. Geographic aggregation ID
#                   (e.g. 8741 = Peninsular Spain).
#   base_url       : Character. ESIOS API base URL
#                   (e.g. "https://api.esios.ree.es").
#                   Passed explicitly by download_esios_prices().
#
# OUTPUT:
#   Data frame with columns:
#     time           : POSIXct (UTC, 15-min resolution).
#     <indicator_name> : Numeric. Price in EUR/kWh.
#   Returns NULL on HTTP or parsing error.
# -------------------------------------------------------------
# FUNCTIONS USED (from this repository):
#   expand_to_15min() - expands hourly data to 15-min resolution.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - Prices are converted from EUR/MWh to EUR/kWh (divided by 1000).
#   - If the source data resolution is >= 50 minutes, the series is
#     expanded to 15-minute resolution by repeating each hourly value.
#   - Returns NULL if the HTTP request fails, the API returns an error,
#     or no data is found for the requested indicator.
# -------------------------------------------------------------
download_single_indicator <- function(api_token, indicator_id, indicator_name,
                                      start_date, end_date, geo_id,
                                      base_url) {

  start_str <- format(as.POSIXct(start_date, tz = "Europe/Madrid"),
                      "%Y-%m-%dT%H:%M:%S%z")
  end_str   <- format(as.POSIXct(end_date + 1, tz = "Europe/Madrid") - 1,
                      "%Y-%m-%dT%H:%M:%S%z")

  url <- paste0(base_url, "/indicators/", indicator_id)

  response <- tryCatch(
    GET(
      url,
      add_headers(
        "x-api-key"    = api_token,
        "Accept"       = "application/json; application/vnd.esios-api-v1+json",
        "Content-Type" = "application/json"
      ),
      query = list(
        start_date   = start_str,
        end_date     = end_str,
        "geo_ids[]"  = as.character(geo_id)
      )
    ),
    error = function(e) {
      message("HTTP request failed for ", indicator_name, ": ", conditionMessage(e))
      return(NULL)
    }
  )

  if (is.null(response)) return(NULL)

  if (http_error(response)) {
    message("ESIOS API error (HTTP ", status_code(response), ") for ",
            indicator_name, ": ", content(response, "text", encoding = "UTF-8"))
    return(NULL)
  }

  raw_content <- content(response, "text", encoding = "UTF-8")
  parsed      <- fromJSON(raw_content, simplifyDataFrame = TRUE)

  if (!isTRUE(nrow(parsed$indicator$values) > 0)) {
    message("No data returned for indicator: ", indicator_name)
    return(NULL)
  }

  values_df <- as.data.frame(parsed$indicator$values)

  # Filter to requested geographic area
  if ("geo_id" %in% names(values_df)) {
    values_df <- values_df[values_df$geo_id == geo_id, ]
  }

  # Parse datetime column (ESIOS returns UTC datetimes)
  time_col <- if ("datetime_utc" %in% names(values_df)) "datetime_utc" else "datetime"
  values_df$time <- as.POSIXct(values_df[[time_col]],
                                format = "%Y-%m-%dT%H:%M:%S",
                                tz = "UTC")

  # Convert price from EUR/MWh to EUR/kWh
  values_df[[indicator_name]] <- as.numeric(values_df$value) / 1000

  result <- values_df[, c("time", indicator_name)]
  result <- result[order(result$time), ]
  result <- result[!is.na(result$time), ]

  # Detect source resolution and expand to 15-min if needed
  if (nrow(result) > 1) {
    time_diffs <- as.numeric(diff(result$time), units = "mins")
    min_diff   <- min(time_diffs[time_diffs > 0], na.rm = TRUE)
  } else {
    min_diff <- 60
  }

  if (min_diff >= 50) {
    result <- expand_to_15min(result, indicator_name)
  }

  cat("  ", indicator_name, "(ID:", indicator_id, "):",
      nrow(result), "records at 15-min resolution\n")

  return(result)
}
