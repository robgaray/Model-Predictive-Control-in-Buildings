# -------------------------------------------------------------
# Function: prepare_climate.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Generates the Overall_Climate of a building, in its table, on a
# daily basis from Main_df$Text and the operational temperature
# corrections of the building. The weather is common to every asset,
# in Main_df; the season thresholds are those of the building. It is
# the operation prepare_year of the contract of the type Building
# (see model_type_contract()).
# It is meant to run before the period is cut (see
# subset_period.R), so that the trailing periods of the first days
# of a short run have the whole year to look at.
# A day is tagged "Heating" only when every one of the preceding
# HDD_period individual 24h periods has its own mean Text below
# T_ref_Heating_Season - not when their HDD_period-day trailing
# average does. "Cooling" is the equivalent check against
# T_ref_Cooling_Season with CDD_period 24h periods and a mean
# above the threshold. Any day failing both is "Intermediate".
# A day whose preceding periods reach back before the first day of
# the series has no full history. Its verdict is taken over the
# first periods of the series instead: with HDD_period = 7, every day
# of the first week is tagged from the means of the first 7 days of
# the series. A series shorter than the periods leaves those days
# "Intermediate".
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
# Inputs
#   Main_df                             : data frame, with its time
#                                         and Text columns.
#   asset_df                            : data frame, the table of the
#                                         building, one row per row of
#                                         Main_df, with its time
#                                         column.
#   asset                               : List. The parameters of the
#     building, its entry of parameters$assets. This function reads
#     its group operational_temperature_corrections: the season
#     reference temperatures and the number of trailing periods each
#     verdict is taken over:
#     - HDD_period
#     - CDD_period
#     - T_ref_Heating_Season
#     - T_ref_Cooling_Season
# -------------------------------------------------------------
# Outputs
#   asset_df, as received, with the column Overall_Climate added: one
#   verdict per row, Heating, Cooling or Intermediate, held constant
#   over the calendar day.
# -------------------------------------------------------------
# Code outline
# 1. Resolve the daily mean of Text.
# 2. Tag a day Heating when every one of the preceding periods is
#    below the heating reference, Cooling on the mirror test. A day
#    with no full history takes the first periods of the series.
# 3. Spread the daily verdict over every row of its day.
# -------------------------------------------------------------
# Usage instructions
# asset_df <- prepare_climate(
#   Main_df                             = Main_df,
#   asset_df                            = asset_df,
#   asset                               = parameters$assets[[1]]
# )
# -------------------------------------------------------------
prepare_climate <- function(Main_df,
                            asset_df,
                            asset
                            ) {

  # -------------------------------------------------------------
  # 1. Resolve the daily mean of Text
  # The cumulative sums of Text and of its non-missing count let
  # the mean of any 24h period be read from two row positions.
  # -------------------------------------------------------------
  {
    operational_temperature_corrections <-
      asset$operational_temperature_corrections

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

    series_start <- day_starts[1]

    # Mean of Text over the single 24h period ending `offset_days`
    # days before each day's start (offset_days = 0 -> the 24h period
    # immediately before; offset_days = 1 -> the 24h period before
    # that; and so on), out of `n_periods` periods. A day whose
    # earliest period starts before the series takes, instead, the
    # period of the same position among the first `n_periods` days
    # of the series.
    daily_mean <- function(offset_days, n_periods) {
      upper      <- day_starts - offset_days * 86400
      no_history <- day_starts - n_periods * 86400 < series_start
      upper[no_history] <- series_start +
        (n_periods - offset_days) * 86400
      lower      <- upper - 86400
      idx_lower  <- findInterval(lower - eps, times)
      idx_upper  <- findInterval(upper - eps, times)
      n   <- cum_n[idx_upper + 1]    - cum_n[idx_lower + 1]
      tot <- cum_text[idx_upper + 1] - cum_text[idx_lower + 1]
      ifelse(n > 0, tot / n, NA_real_)
    }

    # TRUE for a day only when every one of the `period_days`
    # preceding 24h periods individually satisfies
    # `compare(daily_mean, base_temp)` on its own mean. A day with
    # any missing 24h period (NA mean) fails the check.
    all_periods_satisfy <- function(period_days, base_temp, compare) {
      ok        <- rep(TRUE, length(day_starts))
      offsets   <- 0:(period_days - 1)
      n_periods <- length(offsets)
      for (offset in offsets) {
        m  <- daily_mean(offset, n_periods)
        ok <- ok & !is.na(m) & compare(m, base_temp)
      }
      ok
    }
  }

  # -------------------------------------------------------------
  # 2. Tag each day
  # Heating when every one of the preceding HDD_period periods is
  # below T_ref_Heating_Season; otherwise Cooling when every one of
  # the preceding CDD_period periods is above T_ref_Cooling_Season;
  # otherwise Intermediate. A day with no full history is tested on
  # the first periods of the series (see daily_mean in block 1).
  # -------------------------------------------------------------
  {
    heating_ok <- all_periods_satisfy(
      operational_temperature_corrections$HDD_period,
      operational_temperature_corrections$T_ref_Heating_Season,
      `<`
    )
    cooling_ok <- all_periods_satisfy(
      operational_temperature_corrections$CDD_period,
      operational_temperature_corrections$T_ref_Cooling_Season,
      `>`
    )

    climate_tags <- ifelse(
      heating_ok, "Heating", ifelse(cooling_ok, "Cooling", "Intermediate")
    )

    rm(list = c("day_starts", "series_start", "times", "text_vals", "cum_text",
                "cum_n", "eps", "daily_mean", "all_periods_satisfy",
                "heating_ok", "cooling_ok",
                "operational_temperature_corrections"))
  }

  # -------------------------------------------------------------
  # 3. Spread the daily verdict over every row of its day
  # -------------------------------------------------------------
  {
    asset_df$Overall_Climate <- climate_tags[
      match(as.Date(asset_df$time, tz = "UTC"), unique_dates)
    ]

    rm(list = c("unique_dates", "climate_tags"))
  }

  return(asset_df)
}
