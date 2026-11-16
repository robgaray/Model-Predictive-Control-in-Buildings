# prepare_commitments.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/prepare_commitments.R`

## Function

Initialises the market output matrices that record, per market step, what the Scheduling and Piloting processes produce:

- the energy commitments (buy, sell and net)
- the flexibility commitments
- the accumulated differential costs

## Called by

- [run_simulation.R](run_simulation.md)

## What it calls, in order of appearance

- [compute_max_steps_ahead.R](compute_max_steps_ahead.md)

## Input data

- Main_df                  : data frame, with MarketUTC and the market columns that say where a market clears.
- market_events            : Data frame. The market events of the run, as build_market_events() returns them. Uses event_slot.
- market                   : List, parameters$market. The resolution and the horizons that size the matrices.
- market_config_scheduling : data frame, parameters$market_config_scheduling, the markets of the complex mode.
- market_config_piloting   : data frame, parameters$market_config_piloting, the markets of the complex mode.

## Output data

- market_commitments, a list of matrices with one row per market event and one column per step ahead, holding:
    - the energy bought, sold and net
    - the two flexibility legs
    - the accumulated differential cost

## Other notes from the file header

### Flexibility commitments: up and down legs

A flexibility commitment is a service the building sells to the grid, and it has two independent legs: down-flexibility (a promise to reduce load on request) and up-flexibility (a promise to increase it). Each leg can be sold (a new or larger commitment) and bought back (unwinding part or all of a commitment sold in an earlier market), so four matrices are kept:

- Elec_flex_down_sell_plan_df - down-flexibility newly sold
- Elec_flex_down_buy_plan_df  - down-flexibility bought back
- Elec_flex_up_sell_plan_df   - up-flexibility newly sold
- Elec_flex_up_buy_plan_df    - up-flexibility bought back

Each leg has its own committed volume, and both are non-negative by construction: Main_df$Elec_flex_down_plan = Elec_total_plan - Elec_total_plan_flex_down over the Commitment Phase, the load the building commits to shed, and Main_df$Elec_flex_up_plan = Elec_total_plan_flex_up - Elec_total_plan over its own Commitment Phase, the load it commits to add. Each is recorded on its own pair of matrices; neither is read off the sign of the other. Every row corresponds to a market event (a row of Main_df where a Scheduling or Piloting market actually clears, i.e. Main_df$Sched_Market_Name or Main_df$Pilot_Market_Name is active there), keyed by the market interval its clearing instant falls in (instant_market_slot()), and every future-step column holds the value committed for the market-resolution interval that many steps ahead of that event. Twelve data frames are created, each with one row per market event (column 'time') and one column per future step ahead, named "0" (the event's own interval) to as.character(max_steps_ahead - 1). All future-step cells are initialised to 0 (double); they are filled later by the market integration logic. Since the energy signals are aggregated by sum over each MarketUTC interval, the committed value written to an interval is the sum of the underlying commitments. The twelve data frames are bundled into a single named list, market_commitments (e.g. market_commitments$Elec_net_plan_df), which is what the function returns. max_steps_ahead is the same horizon that prepare_market_information() uses, derived from the market configuration by compute_max_steps_ahead().

### Code outline

1. Locate the rows where a market actually clears.
2. Create every matrix at zero, sized by those rows and by the furthest horizon any market looks at, each with columns of its own.

### Usage instructions

```r
market_commitments <- prepare_commitments(
  Main_df                  = Main_df,
  market                   = parameters$market,
  market_config_scheduling = parameters$market_config_scheduling,
  market_config_piloting   = parameters$market_config_piloting
  )
```

## Diagram

![Block diagram of prepare_commitments.R](prepare_commitments.jpg)

Also available as [prepare_commitments.svg](prepare_commitments.svg).

---

[Back to the code structure index](../Code_Structure.md)
