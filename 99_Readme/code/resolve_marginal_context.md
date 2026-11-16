# resolve_marginal_context.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/resolve_marginal_context.R`

## Function

Computes the baseline commitment (E_orig) and current-market prices needed to value a candidate control schedule at its marginal (differential) cost, per target market interval of the horizon about to be optimized. This is called once per market process (Scheduling or Piloting), before the GA runs, so that every candidate evaluated by the fitness function is priced against the same fixed baseline and prices. Both the base-energy track and the explicit-flexibility track are always resolved, and reward_function() values both whatever the aim and whatever the market family. A market with the "energy" aim places no new window, but the flexibility earlier markets sold is restated over its plan: inside the control horizon any change of it is settled at this market's prices, and beyond it the part the plan can no longer hold is valued as the re-purchase a later market will have to make. The explicit-flexibility track is what values that obligation. A Scheduling market with a "flexibility" aim explores flexibility exactly the same way Piloting does. Reuses exactly the same row/column resolution as settle_market.R (row_m_full on the full market-resolution grid for column offsets; row_m, the sparse row of the current event in full_market_information's own row set, for price lookups) and the same per-interval SUM aggregation of Main_df's existing *_plan columns, so that the baseline priced here is guaranteed to match what settle_market() will later treat as E_orig for the same market event. The event is keyed by the market interval its clearing instant falls in (instant_market_slot()), and every target interval is a MarketUTC interval: the interval of the time steps the market values. The row at Period_Begin is not one of them, since its time step ends the interval before the market's period.

## Called by

- [run_market_role.R](run_market_role.md)

## What it calls, in order of appearance

- [instant_market_slot.R](instant_market_slot.md)
- [system_net_energy.R](system_net_energy.md) &nbsp;(2 call sites)
- [price_estimate_sources.R](price_estimate_sources.md)
- [estimate_price_signal.R](estimate_price_signal.md)
- [revenue_discount_factor.R](revenue_discount_factor.md)

## Input data

- row_index               : Integer. Current simulation row index (CONT_003).
- Main_df                 : Data frame. The main simulation data frame, in its state before this market's optimization overwrites any *_plan columns.
- simulation_control      : Named list. Must contain indexes_global$idx_horizon, the current market's optimization horizon, which is what gets valued, and indexes_global$idx_ctrl, its control horizon, which is where the published prices stop.
- market_time             : POSIXct vector. Sorted unique MarketUTC intervals on the full market-resolution grid; used only to compute future-step column offsets (col_j).
- market_index            : Data frame. The market events of both families and the periods they trade, as market_event_index() lists them for "Sched" and "Pilot", one after the other. It is where the earlier prices are looked up beyond the control horizon.
- full_market_information : Named list of 13 market-event price data frames (read-only), as built by prepare_market_information().
- parameters              : Named list. Reads:
    - parameters$market$market_resolution, to key the market events
    - parameters$reward$Revenue_discount_per_hour
    - parameters$forecast$price_forecast_type: with "inaccurate", the prices beyond the control horizon are estimated from what the markets already know

## Output data

- Named list with: market_utc               : POSIXct vector. MarketUTC of each target interval, in the same order as every other element below. E_orig_base_by_market    : Numeric vector. Main_df$Elec_total_plan summed per target interval, before this market's optimization. E_orig_gross_by_market   : Numeric vector. The absolute value of Main_df$Elec_total_plan summed per target interval, before this market's optimization: the gross volume the distribution cost is settled on. E_orig_expflex_down_by_market : Numeric vector. Main_df$Elec_flex_down_plan summed per target interval, before this market's optimization. E_orig_expflex_up_by_market : Numeric vector. Main_df$Elec_flex_up_plan summed per target interval, before this market's optimization. One baseline per leg: both signals are non-negative by construction, so they cannot be told apart by sign once added together. P_import_buy_by_market, P_import_sell_by_market, P_export_buy_by_market, P_export_sell_by_market : Numeric vectors. Current-market energy prices per target interval, ready to pass straight into calc_differential_cost()/ compute_marginal_energy_cost() for the base-energy and flex-adjusted-energy terms. distribution_rate_by_market : Numeric vector. Current-market Elec_unit_cost_distribution rate per target interval, ready to pass into compute_marginal_distribution_cost() for the base-energy term only (not used for flexibility). p_up_buy_by_market, p_up_sell_by_market, p_down_buy_by_market, p_down_sell_by_market : Numeric vectors. Effective up/down flexibility prices per target interval (commitment + execution * probability), ready to pass into the same functions for the explicit-flexibility term. p_down_com_buy_by_market, p_down_com_sell_by_market, p_up_com_buy_by_market, p_up_com_sell_by_market, p_down_exec_buy_by_market, p_down_exec_sell_by_market, p_up_exec_buy_by_market, p_up_exec_sell_by_market : Numeric vectors. The two halves of those effective prices, unbundled: the commitment price, which is paid for certain, and the execution price, which is only paid if the operator calls the service. flex_probab_down_by_market, flex_probab_up_by_market : Numeric vectors in [0, 1]. Activation probability of each leg per target interval. Together with the two price families above they let the caller value the certain and the conditional halves of the service separately, which the bundled effective price cannot express: the execution of a commitment also moves the building's energy during the Recovery Phase, and that cost is conditional on the same probability. revenue_discount_by_market : Numeric vector. Revenue discount factor of each target interval, as returned by revenue_discount_factor(). It weighs down income that is far from the decision instant, and only income. revenue_discount_per_hour  : Numeric scalar (%). The rate those factors were built from, carried so that the caller can build the same factors for instants outside the target set. discount_origin_time       : POSIXct scalar. The decision instant H the factors are counted from, this market event's own market interval. beyond_control_by_market   : Logical vector. TRUE for the target intervals after the close of the control horizon, where the flexibility a candidate is valued at is capped at the commitment that stands. stored_energy_price        : Numeric scalar (EUR/kWh). The mean of the prices at which the market buys energy over its horizon (P_import_buy_by_market): the price at which the energy that the assets leave stored is valued. stored_energy_discount     : Numeric scalar (-). The revenue discount factor of the last interval of the horizon, the one applied to the value of that energy when it is an income.

## Other notes from the file header

### What is valued and what is committed

These are two different sets of market intervals, and keeping them apart is the whole point of this function's shape. The intervals returned here are those of the OPTIMIZATION HORIZON, because the optimizer decides the setpoints of that whole horizon and every energy flow and unit cost of it has to reach the reward. Their prices are the published ones inside the control horizon and an estimate beyond it. The intervals that are COMMITTED are only those of the control horizon, and they are built inside settle_market() from idx_ctrl, not here. The stretch valued with estimated prices therefore never reaches the settlement: the next market finds those hours with nothing booked on them and values them again with prices it does know, which is what keeps the double counting away with no artifice. The flexibility earlier markets sold beyond the control horizon is the exception: it is booked, and no market changes it until it falls inside a control horizon. There the candidate is valued at most at the commitment that stands (beyond_control_by_market): a restatement that holds it is worth nothing, and one that falls short costs the re-purchase the later market will have to make.

### Code outline

1. Market row (full grid and sparse) and target market intervals
2. Baseline commitments before this market (SUM aggregation)
3. Current-market prices per target interval
4. Price estimate beyond the control horizon
5. Revenue discount factors and value of the stored energy

### Usage instructions

```r
marginal_context <- resolve_marginal_context(row_index, Main_df,
  simulation_control, market_time, market_index,
  full_market_information, parameters)
```

## Diagram

![Block diagram of resolve_marginal_context.R](resolve_marginal_context.jpg)

Also available as [resolve_marginal_context.svg](resolve_marginal_context.svg).

---

[Back to the code structure index](../Code_Structure.md)
