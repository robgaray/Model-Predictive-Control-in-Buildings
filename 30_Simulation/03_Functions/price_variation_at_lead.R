# -------------------------------------------------------------
# Function: price_variation_at_lead.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Returns the variation of the energy price, in per cent, that applies
# to a price quoted a given number of hours ahead.
#
# The four bands
# -------------------------------------------------------------
# The energy price moves with how far ahead it is quoted, in four
# bands, each with its own variation in 06_Energy_price_parameters.csv:
#   lead >= price_lead_day_ahead_h          Price_variation_day_ahead
#   lead >= price_lead_5h_h                 Price_variation_5h
#   lead >  price_lead_1h_h                 Price_variation_1_5h
#   otherwise                               Price_variation_below_1h
# The edges (24, 5 and 1 h in production) live in
# 01_computing_parameters.csv. They have to decrease in that order,
# or a band would be empty; the function stops when they do not.
# -------------------------------------------------------------
# Inputs
#   lead_h       : Numeric scalar. Hours between the market event and
#                  the interval the price is quoted for.
#   energy_price : Named list. parameters$energy_price, for the four
#                  Price_variation_* values [%].
#   computing    : Named list. parameters$computing, for the three
#                  price_lead_* edges [h].
# -------------------------------------------------------------
# Outputs
#   Numeric scalar. The variation of the band the lead falls in [%].
# -------------------------------------------------------------
# Code outline
# 1. Check that the edges decrease.
# 2. Return the variation of the band the lead falls in.
# -------------------------------------------------------------
# Usage instructions
# tau <- price_variation_at_lead(lead_h       = 6,
#                                energy_price = parameters$energy_price,
#                                computing    = parameters$computing)
# -------------------------------------------------------------
# Where this function/script is used
# 11_full_market_information_setup.R, once per step ahead, to discount the
# four energy price signals to the lead they are quoted at.
# -------------------------------------------------------------
# functions/scripts called
# None.
# -------------------------------------------------------------

price_variation_at_lead <- function(lead_h,
                                    energy_price,
                                    computing
                                    ) {

  # -------------------------------------------------------------
  # 1. Check that the edges decrease
  # -------------------------------------------------------------
  {
    if (!(computing$price_lead_day_ahead_h > computing$price_lead_5h_h &&
          computing$price_lead_5h_h > computing$price_lead_1h_h)) {
      stop("01_computing_parameters.csv: price_lead_day_ahead_h > ",
           "price_lead_5h_h > price_lead_1h_h is required, found ",
           computing$price_lead_day_ahead_h, ", ", computing$price_lead_5h_h,
           " and ", computing$price_lead_1h_h)
    }
  }

  # -------------------------------------------------------------
  # 2. Return the variation of the band the lead falls in
  # -------------------------------------------------------------
  {
    if (lead_h >= computing$price_lead_day_ahead_h) {
      variation <- energy_price$Price_variation_day_ahead
    } else if (lead_h >= computing$price_lead_5h_h) {
      variation <- energy_price$Price_variation_5h
    } else if (lead_h > computing$price_lead_1h_h) {
      variation <- energy_price$Price_variation_1_5h
    } else {
      variation <- energy_price$Price_variation_below_1h
    }
  }

  return(variation)
}
