# -------------------------------------------------------------
# Function: revenue_discount_factor.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the geometric discount factor that the reward applies to
# income that is far away in time, one factor per instant.
# -------------------------------------------------------------
# Why this factor exists
# A decision has to be prudent about what it expects to earn far into
# the future, the same way an economic appraisal discounts future
# revenue. Without it, an income of one euro ten hours ahead weighs
# exactly as much in the decision as one euro in the next slot, and the
# optimizer has no reason to prefer the operation that pays sooner.
# Revenue_discount_per_hour is the hourly rate of that prudence: with
# A = 0.25 (%), an income n hours ahead is worth (1 - 0.0025)^n of its
# face value at the decision instant.
# -------------------------------------------------------------
# Decision only, never accounting
# The factor belongs to the decision process alone. It never reaches
# the volume or the price of an energy or flexibility commitment:
# settle_market() settles what was decided at the market's
# own undiscounted prices, so the discount changes which candidate wins
# the optimization, not what the winner is then paid for.
# -------------------------------------------------------------
# Inputs
#   target_time           : POSIXct vector. Instants whose income is
#                           being discounted, normally the market
#                           intervals of the optimization horizon.
#   origin_time           : POSIXct scalar. Decision instant H, the
#                           market interval at which this optimization
#                           runs. n is counted from here.
#   discount_per_hour     : Numeric scalar (%). Revenue_discount_per_hour,
#                           between 0 and 100. 0.25 means 0.25 % per hour.
# -------------------------------------------------------------
# Outputs
#   Numeric vector, same length as target_time. The factor
#   (1 - discount_per_hour/100)^n of each instant, where n is the
#   number of hours from origin_time to that instant.
# -------------------------------------------------------------
# Code outline
# 1. Hours from the decision instant to each target instant
# 2. Geometric factor
# -------------------------------------------------------------
# Usage instructions
# f <- revenue_discount_factor(market_utc, Main_df$MarketUTC[row_index],
# parameters$reward$Revenue_discount_per_hour)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - n is measured in exact hours, so it is fractional on a market grid
#     finer than one hour: a 15-minute slot three hours and a quarter
#     ahead gets n = 3.25, not 3. The assignment's example (H+3 -> n=3)
#     is the whole-hour case of the same expression.
#   - n is bounded below at 0. An instant at or before the decision
#     instant is not discounted: a factor above 1 would amplify income
#     instead of being cautious about it, which is the opposite of what
#     the parameter is for.
#   - A discount_per_hour of 0 yields a factor of exactly 1 everywhere,
#     which is how the discount is switched off.
# -------------------------------------------------------------

revenue_discount_factor <- function(target_time, origin_time, discount_per_hour) {

  # 1. Hours from the decision instant to each target instant
  # -------------------------------------------------------------
  # as.numeric() is applied to the difference in seconds rather than
  # letting difftime() pick its own unit, the same reasoning
  # comfort_term() follows for delta_t_h: an automatically chosen
  # unit would silently change the exponent's meaning with the
  # simulation's resolution.
  # -------------------------------------------------------------
  {
    n_hours <- pmax(
      (as.numeric(target_time) - as.numeric(origin_time)) / 3600,
      0
    )
  }

  # 2. Geometric factor
  # -------------------------------------------------------------
  {
    factor <- (1 - discount_per_hour / 100)^n_hours
  }

  rm(list = "n_hours")

  return(factor)
}
