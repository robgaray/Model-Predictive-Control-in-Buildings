# -------------------------------------------------------------
# Script: climate_priority.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Generates Main_df$Overall_Climate on a daily basis from
# Main_df$Text and parameters$reward.
# Sourced by Main.R before simulation.
# A day is tagged "Heating" only when every one of the preceding
# HDD_period individual 24h periods has its own mean Text below
# T_ref_Heating_Season - not when their HDD_period-day trailing
# average does. "Cooling" is the equivalent check against
# T_ref_Cooling_Season with CDD_period 24h periods and a mean
# above the threshold. Any day failing both is "Intermediate".
# Each 24h period's mean is computed with cumulative sums over
# Main_df$time (sorted, strictly increasing) plus findInterval()
# to locate its row range in O(log rows) - equivalent to, but
# avoids, rescanning the full Main_df$time vector once per day
# and per 24h period (which is O(days x period x rows) and
# measurably slower over a full year at 5' resolution).
# Verified against a per-day boolean-scan implementation over
# randomized series, including fractional HDD_period/CDD_period,
# missing whole days, and series shorter than the window.
# -------------------------------------------------------------

{
  unique_dates <- sort(unique(as.Date(Main_df$time, tz = "UTC")))
  day_starts   <- as.numeric(as.POSIXct(unique_dates, tz = "UTC"))
  times        <- as.numeric(Main_df$time)
  text_vals    <- Main_df$Text

  cum_text <- c(0, cumsum(ifelse(is.na(text_vals), 0, text_vals)))
  cum_n    <- c(0, cumsum(!is.na(text_vals)))

  # eps is smaller than Main_df's time resolution, so that
  # findInterval(boundary - eps, times) counts rows strictly before
  # `boundary` without being thrown off by an exact grid match.
  eps <- 1

  # Mean of Text over the single 24h period ending `offset_days`
  # days before each day's start (offset_days = 0 -> the 24h period
  # immediately before; offset_days = 1 -> the 24h period before
  # that; and so on).
  daily_mean <- function(offset_days) {
    upper     <- day_starts - offset_days * 86400
    lower     <- upper - 86400
    idx_lower <- findInterval(lower - eps, times)
    idx_upper <- findInterval(upper - eps, times)
    n   <- cum_n[idx_upper + 1]    - cum_n[idx_lower + 1]
    tot <- cum_text[idx_upper + 1] - cum_text[idx_lower + 1]
    ifelse(n > 0, tot / n, NA_real_)
  }

  # TRUE for a day only when every one of the `period_days` preceding
  # 24h periods individually satisfies `compare(daily_mean, base_temp)`
  # on its own mean. A period with any missing 24h period (NA mean)
  # fails the check, same as before.
  all_periods_satisfy <- function(period_days, base_temp, compare) {
    ok <- rep(TRUE, length(day_starts))
    for (offset in 0:(period_days - 1)) {
      m  <- daily_mean(offset)
      ok <- ok & !is.na(m) & compare(m, base_temp)
    }
    ok
  }

  heating_ok <- all_periods_satisfy(
    parameters$reward$HDD_period, parameters$reward$T_ref_Heating_Season, `<`
  )
  cooling_ok <- all_periods_satisfy(
    parameters$reward$CDD_period, parameters$reward$T_ref_Cooling_Season, `>`
  )

  climate_tags <- ifelse(
    heating_ok, "Heating", ifelse(cooling_ok, "Cooling", "Intermediate")
  )

  Main_df$Overall_Climate <- climate_tags[
    match(as.Date(Main_df$time, tz = "UTC"), unique_dates)
  ]

  rm(unique_dates, day_starts, times, text_vals, cum_text, cum_n, eps,
     daily_mean, all_periods_satisfy, heating_ok, cooling_ok, climate_tags)

  cat("Main_df$Overall_Climate generated\n")
}
