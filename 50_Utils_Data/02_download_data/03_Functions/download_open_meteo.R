# -------------------------------------------------------------
# Function: download_open_meteo.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Downloads historical hourly weather data (external temperature
# and solar radiation) for a given location and date range from
# the Open-Meteo Historical Weather API.
# No API key is required for the open-access tier.
# -------------------------------------------------------------
# INPUT:
#   latitude   : Numeric. Latitude of the site in decimal degrees
#                (WGS84), range [-90, 90].
#   longitude  : Numeric. Longitude of the site in decimal degrees
#                (WGS84), range [-180, 180].
#   start_date : Date or character "YYYY-MM-DD". First day to
#                download (inclusive).
#   end_date   : Date or character "YYYY-MM-DD". Last day to
#                download (inclusive).
#   timezone   : Character. IANA timezone name used when
#                interpreting Open-Meteo timestamps.
#                Default: "UTC".  Use "Europe/Madrid" for
#                mainland Spain.
#
# OUTPUT:
#   Data frame with columns:
#     time   : POSIXct (UTC).
#     Text   : External dry-bulb temperature (°C).
#              Column name matches project convention in Main_df.
#     SolarR : Global horizontal solar irradiance (W/m²).
#              Negative values are replaced with 0.
#   Returns NULL on HTTP or parsing error.
# -------------------------------------------------------------
# FUNCTIONS USED (from this repository):
#   (none)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - stop() is called if start_date or end_date is NA or if
#     end_date < start_date.
#   - stop() is called if latitude or longitude are out of range
#     or non-numeric.
#   - Timestamps from Open-Meteo are in local time (ISO 8601);
#     they are converted to UTC for consistency with the rest of
#     the project.
#   - Negative solar radiation values are clamped to 0.
#   - Returns NULL if the HTTP request fails, the API returns an
#     error, or no hourly data is present in the response.
# -------------------------------------------------------------

# ---- Constant ----
# Open-Meteo historical archive base URL
OPEN_METEO_ARCHIVE_URL <- "https://archive-api.open-meteo.com/v1/archive"

# ---- Function definition ----
download_open_meteo <- function(latitude,
                                longitude,
                                start_date,
                                end_date,
                                timezone = "UTC") {

  # Validate inputs
  start_date <- as.Date(start_date)
  end_date   <- as.Date(end_date)

  if (is.na(start_date) || is.na(end_date)) {
    stop("start_date and end_date must be valid dates (YYYY-MM-DD).")
  }
  if (end_date < start_date) {
    stop("end_date must be on or after start_date.")
  }
  if (!is.numeric(latitude) || latitude < -90 || latitude > 90) {
    stop("latitude must be a numeric value between -90 and 90.")
  }
  if (!is.numeric(longitude) || longitude < -180 || longitude > 180) {
    stop("longitude must be a numeric value between -180 and 180.")
  }

  cat("Downloading Open-Meteo weather data:\n")
  cat("  Location :", latitude, "/", longitude, "\n")
  cat("  Period   :", format(start_date), "to", format(end_date), "\n")

  # Build query parameters
  query_params <- list(
    latitude   = latitude,
    longitude  = longitude,
    start_date = format(start_date, "%Y-%m-%d"),
    end_date   = format(end_date,   "%Y-%m-%d"),
    hourly     = paste(c("temperature_2m", "shortwave_radiation"), collapse = ","),
    timezone   = timezone
  )

  # Perform API request
  response <- tryCatch(
    GET(OPEN_METEO_ARCHIVE_URL, query = query_params),
    error = function(e) {
      message("HTTP request failed: ", conditionMessage(e))
      return(NULL)
    }
  )

  if (is.null(response)) return(NULL)

  # Check HTTP status
  if (http_error(response)) {
    message("Open-Meteo API error (HTTP ", status_code(response), "): ",
            content(response, "text", encoding = "UTF-8"))
    return(NULL)
  }

  # Parse JSON response
  raw_content <- content(response, "text", encoding = "UTF-8")
  parsed      <- fromJSON(raw_content, simplifyDataFrame = TRUE)

  if (is.null(parsed$hourly)) {
    message("No hourly data returned for the requested period.")
    return(NULL)
  }

  hourly <- as.data.frame(parsed$hourly)

  # Parse timestamp (Open-Meteo returns ISO 8601 local time strings)
  hourly$time <- as.POSIXct(hourly$time,
                             format = "%Y-%m-%dT%H:%M",
                             tz = timezone)

  # Convert to UTC for consistency with the rest of the project
  hourly$time <- with_tz(hourly$time, "UTC")

  # Rename weather variables to project column names
  names(hourly)[names(hourly) == "temperature_2m"]      <- "Text"
  names(hourly)[names(hourly) == "shortwave_radiation"] <- "SolarR"

  # Replace any negative radiation values with 0 (physically impossible)
  hourly$SolarR[!is.na(hourly$SolarR) & hourly$SolarR < 0] <- 0

  # Select and sort output columns
  result_df <- hourly[, c("time", "Text", "SolarR")]
  result_df <- result_df[order(result_df$time), ]
  result_df <- result_df[!is.na(result_df$time), ]

  cat("Downloaded", nrow(result_df), "hourly weather records\n")

  return(result_df)
}
