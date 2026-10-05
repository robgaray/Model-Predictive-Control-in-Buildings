# Economic Data Structures

This page documents the three objects that hold prices, commitments and results for the energy and flexibility markets:

- `full_market_information`

- `market_commitments` 

- `economic_analysis`.

All three are built while `Main.R` is setting up the simulation (before the main loop runs), filled in or read from during the loop, and (for `economic_analysis`) completed and exported once the loop is over.

For where the CSV/RDS files these produce are written, see [Input and output files](Input_Output_Files.md).

## General content and purpose

Each of the three items above is not itself a data frame - it is a named list that groups a handful of data frames together, for convenience, "the market prices" or "the market commitments" are easily identified and passed-around as a single item. This page documents every data frame inside each list on its own: its own shape, its own columns, its own meaning. The list itself is only a folder.

- **`full_market_information`** - the prices every market decision is made against. Read-only: built once, before the simulation loop starts, and never changed afterwards. 13 data frames, one per price signal.
- **`market_commitments`** - what each market actually committed to, in energy and money. Written to throughout the simulation loop, once per Scheduling or Piloting market that clears. 12 data frames.
- **`economic_analysis`** - the final economic picture: what each market did, and what happened in each delivery slot. Built up throughout the loop and completed at the end. 2 data frames are exported (`market`, `slot`); a third, `index`, is internal bookkeeping dropped before export.

## Shared shape of `full_market_information` and `market_commitments`

All 13 + 12 = 25 data frames in these two lists share the same shape, because they are all indexed the same way:

- One row per **market event** (a `MarketUTC` interval where a Scheduling or Piloting market actually clears)

- One column per **future step ahead** of that event.

The actual configuration:

- Column `time` (POSIXct): the market event's own `MarketUTC`.

- Columns `"0"`, `"1"`, ..., up to `as.character(max_steps_ahead - 1):
  
  - Numeric
  
  - One column per future market-resolution step: column `"0"` is the event's own delivery interval, column `"1"` the next one, and so on.
  
  - `max_steps_ahead` is the longest distance from a market's bid time to the end of its optimization horizon, converted from hours to `parameters$market$market_resolution`-sized steps and rounded up (`compute_max_steps_ahead()`). It is read from the market configuration in use: in basic mode, `Anticipation + Optimization_horizon` of the Scheduling and Piloting markets of `03_Market_config.csv`; in complex mode, `closure + end + end_optimization` of every market of `04_Market_config_scheduling.csv` and `05_Market_config_piloting.csv`. With the repository's default configuration (complex mode) this is 169 columns (`time` + 168 future steps); a shorter or longer configured horizon changes this count directly.

- Row count: one row per distinct clearing timestamp, across **both** Scheduling and Piloting
  
  - If a Scheduling and a Piloting market ever clear at the exact same instant, they share one row, indexed by that shared `MarketUTC` 
  
  - How often Scheduling and Piloting clear, and therefore how many rows these tables have, is entirely a property of the market configuration files, unrelated to `Main_df`'s own row count.

Neither list carries an `NA` by design: every cell that is not yet meaningful (a future step nobody has committed to yet) is a real `0`, not a missing value - documented per data frame below.

## `full_market_information`

Read-only price lookup with prices to be applied to all future slots in each market.

| Data frame                         | Unit  | Meaning                                                                              |
| ---------------------------------- | ----- | ------------------------------------------------------------------------------------ |
| `Elec_unit_cost_import_buy_df`     | €/kWh | Price to buy energy                                                                  |
| `Elec_unit_cost_import_sell_df`    | €/kWh | Price received when reselling a previously bought commitment                         |
| `Elec_unit_cost_export_buy_df`     | €/kWh | Price to buy back a previously sold commitment                                       |
| `Elec_unit_cost_export_sell_df`    | €/kWh | Price received to sell energy                                                        |
| `Elec_unit_cost_distribution_df`   | €/kWh | Grid distribution cost, applied to the absolute energy moved regardless of direction |
| `Flex_unit_cost_down_com_buy_df`   | €/kWh | Price to buy back a previously sold down-flexibility commitment                      |
| `Flex_unit_cost_down_com_sell_df`  | €/kWh | Price received for newly selling a down-flexibility commitment                       |
| `Flex_unit_cost_down_exec_buy_df`  | €/kWh | Execution-side price component of buying back down-flexibility                       |
| `Flex_unit_cost_down_exec_sell_df` | €/kWh | Execution-side price component of selling down-flexibility                           |
| `Flex_unit_cost_up_com_buy_df`     | €/kWh | Price to buy back a previously sold up-flexibility commitment                        |
| `Flex_unit_cost_up_com_sell_df`    | €/kWh | Price received for newly selling up-flexibility                                      |
| `Flex_unit_cost_up_exec_buy_df`    | €/kWh | Execution-side price component of buying back up-flexibility                         |
| `Flex_unit_cost_up_exec_sell_df`   | €/kWh | Execution-side price component of selling up-flexibility                             |

Currently, the code develops a dummy market price signal dataset based on simplified data. But the user can bypass it by adapting the behavior of the following blocks of code in `30_Simulation/Main.R`:

9. Initialise market columns in Main_df

10. Flexibility generation (conditional)

11. Energy/flexibility price signals (buy/sell derivation)



## `market_commitments`

Output matrices: start at 0 and accumulate the *differential* (change) each market decision makes every time a Scheduling or Piloting market clears. 

A cell that no market has touched yet is genuinely 0, not an unknown value.

| Data frame                    | Unit | Meaning                                                                                |
| ----------------------------- | ---- | -------------------------------------------------------------------------------------- |
| `Elec_buy_plan_df`            | kWh  | Base-energy import commitment added                                                    |
| `Elec_sell_plan_df`           | kWh  | Base-energy export commitment added                                                    |
| `Elec_net_plan_df`            | kWh  | Net base-energy position added (`buy - sell`, signed)                                  |
| `Elec_buy_plan_flex_down_df`  | kWh  | Same as `Elec_buy_plan_df`, for the flex-adjusted energy track                         |
| `Elec_sell_plan_flex_down_df` | kWh  | Same as `Elec_sell_plan_df`, flex-adjusted track                                       |
| `Elec_net_plan_flex_down_df`  | kWh  | Same as `Elec_net_plan_df`, flex-adjusted track                                        |
| `Elec_flex_down_sell_plan_df` | kWh  | Down-flexibility newly sold                                                            |
| `Elec_flex_down_buy_plan_df`  | kWh  | Down-flexibility bought back                                                           |
| `Elec_flex_up_sell_plan_df`   | kWh  | Up-flexibility newly sold                                                              |
| `Elec_flex_up_buy_plan_df`    | kWh  | Up-flexibility bought back                                                             |
| `Elec_Cost_plan_df`           | €    | Net cash flow of the base energy commitment                                            |
| `Elec_flex_Cost_plan_df`      | €    | Accumulated net cash flow of the explicit-flexibility commitment, same sign convention |

### `economic_analysis`

The final economic picture, viewed from two angles: what each market did (`market`), and what happened to each delivery slot regardless of which market did it (`slot`).

Sign convention throughout both tables: positive = income to the building, negative = expense. The one deliberate exception is noted below.

### `economic_analysis$market`

One row per:

- Scheduling market event

- Piloting market event

- Execution: Execution is not a market, so it is reported at the resolution it actually happens: one delivery slot at a time.

Rows are ordered by time, and within the same timestamp by Scheduling, then Piloting, then Execution.

**Shape**: one row per Scheduling event + one row per Piloting event + one row per market slot x 16 columns.

| Column                                 | Type      | Unit | Meaning                                                                                                                                                                  | `NA`?                                                                                                                                |
| -------------------------------------- | --------- | ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| `time`                                 | POSIXct   | -    | the market's (or slot's) `MarketUTC`                                                                                                                                     | No                                                                                                                                   |
| `market_name`                          | Character | -    | market code (`"DA"`, `"cID2"`, ...) or `"EXEC"` for Execution rows                                                                                                       | No                                                                                                                                   |
| `market_type`                          | Character | -    | `"Scheduling"`, `"Piloting"` or `"Execution"`                                                                                                                            | No                                                                                                                                   |
| `Energy_bought`                        | Numeric   | kWh  | new import volume                                                                                                                                                        | No                                                                                                                                   |
| `Energy_rebought`                      | Numeric   | kWh  | import volume bought back (unwinding an earlier export)                                                                                                                  | No                                                                                                                                   |
| `Energy_sold`                          | Numeric   | kWh  | new export volume                                                                                                                                                        | No                                                                                                                                   |
| `Energy_resold`                        | Numeric   | kWh  | export volume resold (unwinding an earlier import)                                                                                                                       | No                                                                                                                                   |
| `Flex_up_sold`, `Flex_up_rebought`     | Numeric   | kWh  | up-flexibility sold/bought back                                                                                                                                          | No                                                                                                                                   |
| `Flex_down_sold`, `Flex_down_rebought` | Numeric   | kWh  | down-flexibility sold/bought back                                                                                                                                        | No                                                                                                                                   |
| `Cash_flow`                            | Numeric   | €    | this row's total net cash flow                                                                                                                                           | No                                                                                                                                   |
| `PL_rebuy_resale`                      | Numeric   | €    | net cash flow of the unwinding operations alone (energy resales as income, energy and flexibility buybacks as expense), valued at the prices of the market that performed them | No                                                                                                                                   |
| `Flex_executed`                        | Numeric   | kWh  | committed down- and up-flexibility volume actually activated (Execution rows only)                                                                                        | `NA` on Scheduling/Piloting rows - flexibility execution has no meaning for a market decision, only for a delivered slot             |
| `Flex_executed_cash_flow`              | Numeric   | €    | cash flow of that activation                                                                                                                                             | `NA` on Scheduling/Piloting rows, same reason                                                                                        |
| `Distribution_cost`                    | Numeric   | €    | always <= 0; distribution cost of the energy delivered in this slot                                                                                                      | `NA` on Scheduling/Piloting rows - distribution is only charged at delivery (Execution), not at the time a market commitment is made |

`Flex_executed`, `Flex_executed_cash_flow` and `Distribution_cost` are numeric (not `NA`) on Execution rows. `Distribution_cost` carries the distribution cost of the energy delivered in the slot, which is 0 or negative.

Flexibility execution is not simulated yet, so `Flex_executed` and `Flex_executed_cash_flow` report 0 on every Execution row until it is.

### `economic_analysis$slot`

One row per `MarketUTC` interval of the whole simulation - the energy actually delivered in that slot, and how the position for that slot was built up across every market that traded it.

**Shape**: one row per market slot x 16 columns.

| Column                     | Type               | Unit | Meaning                                                                                                                      | `NA`?                                                 |
| -------------------------- | ------------------ | ---- | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `time`                     | POSIXct            | -    | the slot's `MarketUTC`                                                                                                       | No                                                    |
| `Energy_in`, `Energy_out`  | Numeric            | kWh  | energy actually delivered into/out of the building in this slot (from `Elec_total_exec`)                                     | No                                                    |
| `Frac_scheduling`          | Numeric (fraction) | -    | share of this slot's gross energy (`Energy_in + Energy_out`) committed in Scheduling                                         | `NA` when the slot moved no energy at all - see below |
| `Frac_rebuy_resale`        | Numeric (fraction) | -    | share unwound (bought back or resold) after being first committed                                                            | `NA`, same reason                                     |
| `Frac_execution`           | Numeric (fraction) | -    | share adjusted at Execution rather than by an earlier market                                                                 | `NA`, same reason                                     |
| `Flex_committed`           | Numeric            | kWh  | total flexibility committed in this slot (down + up legs)                                                                    | No                                                    |
| `Frac_flex_rebuy`          | Numeric (fraction) | -    | share of `Flex_committed` later bought back                                                                                  | `NA` when `Flex_committed` is 0                       |
| `Flex_down_committed`      | Numeric            | kWh  | down-flexibility committed in this slot                                                                                      | No                                                    |
| `Flex_up_committed`        | Numeric            | kWh  | up-flexibility committed in this slot                                                                                        | No                                                    |
| `Cost_energy_bought`       | Numeric            | €    | net cost of energy bought in this slot, with every resale subtracted as the avoided cost it is (see below - can be negative) | No                                                    |
| `Revenue_energy_sold`      | Numeric            | €    | net revenue from energy sold in this slot, with every rebuy subtracted as the avoided revenue it is (can be negative)        | No                                                    |
| `Distribution_cost`        | Numeric            | €    | always <= 0                                                                                                                  | No                                                    |
| `Revenue_flex_commitments` | Numeric            | €    | net cash flow of flexibility commitments in this slot (sold minus bought back)                                               | No                                                    |
| `Cash_flow`                | Numeric            | €    | this slot's total net cash flow (energy + flexibility + distribution)                                                        | No                                                    |
| `Frac_rebuy_resale_value`  | Numeric (fraction) | -    | value-weighted version of `Frac_rebuy_resale`                                                                                | `NA` when its own denominator is 0                    |

A fraction whose denominator would be 0 is reported as `NA`, not 0: with no energy traded in a slot, "the share of it committed in Scheduling" is undefined, and reporting 0 would incorrectly read as "none of it".

`Cost_energy_bought` and `Revenue_energy_sold` are not non-negative magnitudes, despite their names: a resale is an avoided cost and reduces `Cost_energy_bought`, a rebuy is an avoided revenue and reduces `Revenue_energy_sold` - only a genuinely new purchase or new sale adds to either. A slot whose position was mostly unwound can therefore show a negative cost or a negative revenue. See `accumulate_market_operation()`'s header for the full reasoning.

------------------------------------------------------------------------

[Back to README](../README.md)
