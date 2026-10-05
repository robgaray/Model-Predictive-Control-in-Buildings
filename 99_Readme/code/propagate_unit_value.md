# propagate_unit_value.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/propagate_unit_value.R`

## Function

Accumulates an already-resolved net cash flow (delta_C) for a single market/target-interval decision into a market-resolution cost matrix, and propagates its unit value, weighted by energy, to the 5-minute rows of Main_df that share the target interval's MarketUTC. This is the reusable second half of propagate_differential_cost(): that function additionally resolves delta_C itself via calc_differential_cost() for a single (E_orig, E_new, four prices) transition; this function is called directly whenever delta_C has already been resolved some other way (e.g. the down/up-leg flexibility valuation of integrate_market_process.R, via value_flex_operation(), which is not a single import/export transition and so cannot go through calc_differential_cost()).

## Called by

- [integrate_market_process.R](integrate_market_process.md)
- [propagate_differential_cost.R](propagate_differential_cost.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- row_m      : Integer. Row of the current market event in cost_df (a sparse, market-event row set; not the full market-resolution grid).
- col_j      : Character. Market-resolution column (future-step offset) of the target interval in cost_df.
- mkt_target : POSIXct scalar. MarketUTC of the target interval, used to locate its Main_df rows.
- delta_C    : Numeric scalar. Net cash flow to accumulate for the target interval (positive = income, negative = expense).
- cost_df    : Data frame. Market-resolution cost matrix to accumulate delta_C into (e.g. market_commitments$Elec_flex_Cost_plan_df).
- Main_df    : Data frame. The main simulation data frame.
- weight_col : Character. Name of the Main_df column holding the per-timestamp energy used to weight the value propagation (e.g. "Elec_flex_down_plan"). The column is a signed position; its absolute value is what is used as the weight - see block 2.
- target_col : Character. Name of the Main_df column to add the propagated unit value to (e.g. "Elec_flex_commitment_revenue_h").

## Output data

- Named list with: Main_df : Data frame. Updated in place at target_col for the 5-minute rows of the target interval. cost_df : Data frame. Updated in place at [row_m, col_j].

## Other notes from the file header

### Code outline

1. Accumulation into cost_df
2. Unit value propagation to Main_df, weighted by energy per timestamp

### Usage instructions

```r
result  <- propagate_unit_value(row_m, col_j, mkt_target, delta_C, cost_df, Main_df, weight_col, target_col)
```

Main_df <- result$Main_df cost_df <- result$cost_df

## Diagram

![Block diagram of propagate_unit_value.R](propagate_unit_value.jpg)

Also available as [propagate_unit_value.svg](propagate_unit_value.svg).

---

[Back to the code structure index](../Code_Structure.md)
