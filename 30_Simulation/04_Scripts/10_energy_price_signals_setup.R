# -------------------------------------------------------------
# Script: 10_energy_price_signals_setup.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Derives the twelve buy/sell price signals (four for energy, eight
# for flexibility) that 11_full_market_information_setup.R and the rest
# of the market/reward pipeline consume, from the signals already
# present in Main_df at this point:
#   - Elec_unit_cost_buy: real input data (from Energy_Prices_df),
#     never overwritten by this script; the sole reference price
#     (P_ref) for the four energy signals below.
#   - The four flexibility prices, either real input data or
#     overwritten by 09_flexibility_price_emulation.R just before this
#     script runs (see Main.R):
#       - Flex_unit_cost_down_com
#       - Flex_unit_cost_down_exec
#       - Flex_unit_cost_up_com
#       - Flex_unit_cost_up_exec
# The four energy signals implement the Fase 3 discount formula of
# 01_Agent_Comments/20260720_Plan_Redefinicion_Precios_Energia.md
# (Sec. 4.3), using parameters$energy_price
# (Energy_Export_discount/Energy_Sell_discount/Price_variation_*):
#   import_buy  = P_ref * factor_tiempo
#   import_sell = import_buy * (1 - Sell_discount/100)
#   export_buy  = P_ref * factor_tiempo * (1 - Export_discount/100)
#   export_sell = export_buy * (1 - Sell_discount/100)
# These flat Main_df columns are the row-level ("now") prices used by
# implement_control_step.R's execution-phase economic accounting, so
# factor_tiempo here always uses h = 0 (the "below_1h" tier of
# Price_variation_in_time - see
# 01_Agent_Comments/20260725_Diagnostico_M7_Energy_Price.md, Sec. 4.1
# for the 4-tier partition). The GA-facing, per-market-event/per-future-step
# prices (h = j * market_resolution/60, j > 0 included) are computed
# separately, cell by cell, in 11_full_market_information_setup.R -
# these flat columns are NOT averaged into that script's energy
# matrices the way the other nine signals are (see its header).
# Differentiating the eight flexibility columns remains out of scope
# (Fase 5 of the 20260720 plan) - unconditional buy/sell duplicates.
# Sourced from Main.R, after the (conditional) 09_flexibility_price_emulation.R
# block and before 11_full_market_information_setup.R.
# -------------------------------------------------------------
# Inputs
#   Main_df, carrying the input price signal Elec_unit_cost_buy.
#   parameters$energy_price : the discounts and the variation of
#     each price with the horizon it is quoted at.
# -------------------------------------------------------------
# Outputs
#   Main_df, with the twelve derived price signals: four for energy
#     and eight for flexibility, buy and sell of each.
# -------------------------------------------------------------
# Code outline
# 1. Derive the three remaining energy prices from the input one.
# 2. Derive the eight flexibility prices from the energy ones and
#    the commitment and execution shares.
# -------------------------------------------------------------
# Usage instructions
#   Not called: sourced by Main.R before
#   11_full_market_information_setup.R, which consumes these signals.
# -------------------------------------------------------------
# Where this function/script is used
# Sourced by 30_Simulation/Main.R.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

{
  d_exp             <- parameters$energy_price$Energy_Export_discount / 100
  d_sell            <- parameters$energy_price$Energy_Sell_discount / 100
  factor_tiempo_now <- 1 + parameters$energy_price$Price_variation_below_1h / 100

  Main_df$Elec_unit_cost_import_buy  <- Main_df$Elec_unit_cost_buy * factor_tiempo_now
  Main_df$Elec_unit_cost_import_sell <- Main_df$Elec_unit_cost_import_buy * (1 - d_sell)
  Main_df$Elec_unit_cost_export_buy  <- Main_df$Elec_unit_cost_buy * factor_tiempo_now * (1 - d_exp)
  Main_df$Elec_unit_cost_export_sell <- Main_df$Elec_unit_cost_export_buy * (1 - d_sell)
  rm(d_exp, d_sell, factor_tiempo_now)

  Main_df$Flex_unit_cost_down_com_buy   <- Main_df$Flex_unit_cost_down_com
  Main_df$Flex_unit_cost_down_com_sell  <- Main_df$Flex_unit_cost_down_com
  Main_df$Flex_unit_cost_down_exec_buy  <- Main_df$Flex_unit_cost_down_exec
  Main_df$Flex_unit_cost_down_exec_sell <- Main_df$Flex_unit_cost_down_exec
  Main_df$Flex_unit_cost_up_com_buy     <- Main_df$Flex_unit_cost_up_com
  Main_df$Flex_unit_cost_up_com_sell    <- Main_df$Flex_unit_cost_up_com
  Main_df$Flex_unit_cost_up_exec_buy    <- Main_df$Flex_unit_cost_up_exec
  Main_df$Flex_unit_cost_up_exec_sell   <- Main_df$Flex_unit_cost_up_exec

  cat("Energy/flexibility price signals derived (energy: Fase 3 discount formula; flexibility: interim buy/sell duplicates)\n")
}
