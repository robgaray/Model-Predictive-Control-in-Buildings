# implement_control_step.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/implement_control_step.R`

## Function

This function implements a single MPC control step by running the physical simulation of the building over the control implementation horizon with the setpoints that were previously optimized by optimize_control_step(). The weather it uses is the one period_calculation() reads for the calculation context: the actual (measured) weather for "execution", and the forecast for "plan" and the flexibility contexts. It performs the following steps:

1. Determines the end index of the control window based on optimization_frequency_sec starting from i0.
2. Trims period_chunk to the control window.
3. Calls period_calculation() with the provided setpoints.
4. Appends forecasted state columns from forecast_states to the result for later comparison and logging.
5. For calculation_context == "execution" only: resolves Elec_deviations_net_cost_h for the just-simulated rows via calc_differential_cost(), since period_calculation() itself performs no economic calculation (see period_calculation.R and period_simulation_cpp.cpp headers). E_orig is the row's last committed plan (Elec_total_plan) and E_new is the realized Elec_total_exec, so this values the deviation from what was planned, not the whole executed energy from zero (positive = net income, negative = net expense, per calc_differential_cost()'s sign convention). Also resolves Elec_cost_distr_h for the same rows, as -Elec_unit_cost_distribution * abs(Elec_total_exec) (negative, since distribution is always an expense) - the net of all electricity bought/sold in that hour, market and deviations combined, since Elec_total_exec is already that net by construction. Finally, Elec_net_cost_h = Elec_market_net_cost_h (already accumulated in Main_df by any prior market decision for that row, via integrate_market_process.R) + the just-resolved Elec_deviations_net_cost_h. Elec_total_no_flex is also fixed for the same rows, since it is execution-phase state (see step 3 below).
Sign convention of the flexibility-execution columns Elec_flex_execution_revenue_h and Elec_flex_deviations_net_cost_h are reserved for the execution of explicit flexibility, which is not simulated yet, so nothing writes to them today and both stay 0 for every row. When they are written, they must carry the repository's usual sign - positive = income to the building, negative = expense - exactly like every other economic column here. Their consumer, 15_economic_analysis_finalize.R, adds them together to get the executed- flexibility cash flow; it does not negate either of them. Writing Elec_flex_deviations_net_cost_h as a positive "cost" magnitude would therefore flip the sign of that cash flow.

## Called by

- [14_simulation.R](14_simulation.md)
- [run_market_process.R](run_market_process.md)

## What it calls, in order of appearance

- [period_calculation.R](period_calculation.md)
- [calc_differential_cost.R](calc_differential_cost.md)

## Input data

- period_chunk               : Data frame. Full simulation data for at least the current control window. Must contain all columns required by period_calculation(), plus (for calculation_context == "execution") Elec_total_plan, Elec_total_exec, Elec_unit_cost_import_buy/sell, Elec_unit_cost_export_buy/sell, Elec_unit_cost_distribution, Elec_market_net_cost_h, Elec_deviations_net_cost_h, Elec_cost_distr_h, Elec_net_cost_h and Elec_total_no_flex, plus a 'time' column of POSIXct values.
- simulation_control         : Named list. Control metadata. Only simulation_control$calculation_mode is read here (default: 1 = Setpoint mode, used when NULL/absent).
- timestamps                 : Named list. Timestamp metadata, forwarded unused to this function's signature but kept for interface symmetry with run_market_process().
- parameters                 : Named list. Model parameters passed to period_calculation(). Must contain: parameters$debug_and_config$verbose : Logical. Enables console logging.
- calculation_context        : Character. Passed to period_calculation(). One of "execution", "plan", or "plan_flex".

## Output data

- period_chunk : Data frame. The trimmed and simulated control window, with all columns from period_calculation() updated according to calculation_context.

## Other notes from the file header

### Code outline

0. Extract calculation_mode from simulation_control (default 1)
1. Validate: if period_chunk has fewer than 2 rows, return it unchanged (see EXCEPTIONS below)
2. Run period_calculation() with calculation_mode/calculation_context
3. If calculation_context == "execution": resolve, for the new rows (see header above):
    - Elec_deviations_net_cost_h
    - Elec_cost_distr_h
    - Elec_net_cost_h
    - Elec_total_no_flex
4. Return updated period_chunk

### Usage instructions

```r
result <- implement_control_step(period_chunk, simulation_control, timestamps, parameters, calculation_context)
```

### Exceptions and special cases

- If the trimmed period_chunk has fewer than 2 rows, the function returns early without calling period_calculation(). A warning message is printed if verbose = TRUE. This is a defensive fallback: the execution-phase call from 14_simulation.R already skips calling this function entirely at the last simulation row (where this condition would otherwise always occur), but the guard remains here in case of degenerate horizons from other callers.
- calculation_mode defaults to 1 (Setpoint) when simulation_control$calculation_mode is NULL or absent.

## Diagram

![Block diagram of implement_control_step.R](implement_control_step.jpg)

Also available as [implement_control_step.svg](implement_control_step.svg).

---

[Back to the code structure index](../Code_Structure.md)
