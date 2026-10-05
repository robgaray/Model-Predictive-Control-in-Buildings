# 10_energy_price_signals_setup.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/10_energy_price_signals_setup.R`

## Function

Derives the twelve buy/sell price signals (four for energy, eight for flexibility) that 11_full_market_information_setup.R and the rest of the market/reward pipeline consume, from the signals already present in Main_df at this point:

- Elec_unit_cost_buy: real input data (from Energy_Prices_df), never overwritten by this script; the sole reference price (P_ref) for the four energy signals below.
- The four flexibility prices, either real input data or overwritten by 09_flexibility_price_emulation.R just before this script runs (see Main.R):
    - Flex_unit_cost_down_com
    - Flex_unit_cost_down_exec
    - Flex_unit_cost_up_com
    - Flex_unit_cost_up_exec

The four energy signals implement this discount formula, using parameters$energy_price (Energy_Export_discount/Energy_Sell_discount/Price_variation_*):

- import_buy  = P_ref * factor_tiempo
- import_sell = import_buy * (1 - Sell_discount/100)
- export_buy  = P_ref * factor_tiempo * (1 - Export_discount/100)
- export_sell = export_buy * (1 - Sell_discount/100)

These flat Main_df columns are the row-level ("now") prices used by implement_control_step.R's execution-phase economic accounting, so factor_tiempo here always uses h = 0 (the "below_1h" tier of the 4-tier partition of Price_variation_in_time - see price_variation_at_lead()). The GA-facing prices, per market event and per future step (h = j * market_resolution/60, j > 0 included), are computed separately, cell by cell, in 11_full_market_information_setup.R - these flat columns are NOT averaged into that script's energy matrices the way the other nine signals are (see its header). The eight flexibility columns are unconditional buy/sell duplicates of the four flexibility prices. Sourced from Main.R, after the (conditional) 09_flexibility_price_emulation.R block and before 11_full_market_information_setup.R.

## Called by

- [Main.R](Main.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- Main_df, carrying the input price signal Elec_unit_cost_buy.
- parameters$energy_price : the discounts and the variation of each price with the horizon it is quoted at.

## Output data

- Main_df, with the twelve derived price signals: four for energy and eight for flexibility, buy and sell of each.

## Other notes from the file header

### Code outline

1. Derive the three remaining energy prices from the input one.
2. Derive the eight flexibility prices from the energy ones and the commitment and execution shares.

### Usage instructions

Not called: sourced by Main.R before 11_full_market_information_setup.R, which consumes these signals.

## Diagram

![Block diagram of 10_energy_price_signals_setup.R](10_energy_price_signals_setup.jpg)

Also available as [10_energy_price_signals_setup.svg](10_energy_price_signals_setup.svg).

---

[Back to the code structure index](../Code_Structure.md)
