# -------------------------------------------------------------
# Function: prepare_energy_prices.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Derives the twelve buy/sell price signals (four for energy, eight
# for flexibility) that prepare_market_information() and the rest of
# the market/reward pipeline consume, from the signals already
# present in Main_df at this point:
#   - Elec_unit_cost_buy: real input data (from Energy_Prices_df),
#     never overwritten by this function; the sole reference price
#     (P_ref) for the four energy signals below.
#   - The four flexibility prices, either real input data or
#     overwritten by prepare_flexibility_prices() just before this
#     function runs:
#       - Flex_unit_cost_down_com
#       - Flex_unit_cost_down_exec
#       - Flex_unit_cost_up_com
#       - Flex_unit_cost_up_exec
# The four energy signals implement this discount formula, using
# energy_price
# (Energy_Export_discount/Energy_Sell_discount/Price_variation_*):
#   import_buy  = P_ref * factor_tiempo
#   import_sell = import_buy * (1 - Sell_discount/100)
#   export_buy  = P_ref * factor_tiempo * (1 - Export_discount/100)
#   export_sell = export_buy * (1 - Sell_discount/100)
# These flat Main_df columns are the row-level ("now") prices used by
# settle_execution.R's execution-phase economic accounting, so
# factor_tiempo here always uses h = 0 (the "below_1h" tier of the
# 4-tier partition of Price_variation_in_time - see
# price_variation_at_lead()). The GA-facing prices, per market event
# and per future step (h = j * market_resolution/60, j > 0 included),
# are computed separately, cell by cell, in
# prepare_market_information() - these flat columns are NOT averaged
# into its energy matrices the way the other nine signals are (see
# its header).
# The eight flexibility columns are unconditional buy/sell duplicates
# of the four flexibility prices.
# -------------------------------------------------------------
# Inputs
#   Main_df      : data frame, carrying the input price signal
#                  Elec_unit_cost_buy and the four flexibility prices.
#   energy_price : List, parameters$energy_price. The discounts and
#                  the variation of each price with the horizon it is
#                  quoted at:
#                  - Energy_Export_discount [%]
#                  - Energy_Sell_discount [%]
#                  - Price_variation_below_1h [%]
# -------------------------------------------------------------
# Outputs
#   Main_df, as received, with the twelve derived price signals: four
#   for energy and eight for flexibility, buy and sell of each.
# -------------------------------------------------------------
# Code outline
# 1. Derive the three remaining energy prices from the input one.
# 2. Derive the eight flexibility prices from the four flexibility
#    prices, as buy and sell duplicates.
# -------------------------------------------------------------
# Usage instructions
# Main_df <- prepare_energy_prices(
#   Main_df      = Main_df,
#   energy_price = parameters$energy_price
# )
# -------------------------------------------------------------
prepare_energy_prices <- function(Main_df,
                                  energy_price
                                  ) {

  # -------------------------------------------------------------
  # 1. Energy prices
  # The three prices that derive from Elec_unit_cost_buy, with the
  # discounts and the variation of the price at the present time.
  # -------------------------------------------------------------
  {
    d_exp             <- energy_price$Energy_Export_discount / 100
    d_sell            <- energy_price$Energy_Sell_discount / 100
    factor_tiempo_now <- 1 + energy_price$Price_variation_below_1h / 100

    Main_df$Elec_unit_cost_import_buy  <- Main_df$Elec_unit_cost_buy * factor_tiempo_now
    Main_df$Elec_unit_cost_import_sell <- Main_df$Elec_unit_cost_import_buy * (1 - d_sell)
    Main_df$Elec_unit_cost_export_buy  <- Main_df$Elec_unit_cost_buy * factor_tiempo_now * (1 - d_exp)
    Main_df$Elec_unit_cost_export_sell <- Main_df$Elec_unit_cost_export_buy * (1 - d_sell)

    rm(list = c("d_exp", "d_sell", "factor_tiempo_now"))
  }

  # -------------------------------------------------------------
  # 2. Flexibility prices
  # Each of the four flexibility prices is copied as its buy and its
  # sell signal.
  # -------------------------------------------------------------
  {
    Main_df$Flex_unit_cost_down_com_buy   <- Main_df$Flex_unit_cost_down_com
    Main_df$Flex_unit_cost_down_com_sell  <- Main_df$Flex_unit_cost_down_com
    Main_df$Flex_unit_cost_down_exec_buy  <- Main_df$Flex_unit_cost_down_exec
    Main_df$Flex_unit_cost_down_exec_sell <- Main_df$Flex_unit_cost_down_exec
    Main_df$Flex_unit_cost_up_com_buy     <- Main_df$Flex_unit_cost_up_com
    Main_df$Flex_unit_cost_up_com_sell    <- Main_df$Flex_unit_cost_up_com
    Main_df$Flex_unit_cost_up_exec_buy    <- Main_df$Flex_unit_cost_up_exec
    Main_df$Flex_unit_cost_up_exec_sell   <- Main_df$Flex_unit_cost_up_exec
  }

  return(Main_df)
}
