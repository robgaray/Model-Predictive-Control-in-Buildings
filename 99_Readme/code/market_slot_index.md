# market_slot_index.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/market_slot_index.R`

## Function

Says which market slot each timestep of a candidate belongs to, as a factor whose levels are the target slots in their own order.

It exists so that the answer is worked out once and not once per candidate. The slots a decision targets and the instants of its period do not change while the optimizer searches, so this index is constant over the whole search, while the quantity aggregated on it changes with every candidate.

## Called by

- [compute_marginal_distribution_cost.R](compute_marginal_distribution_cost.md)
- [compute_marginal_energy_cost.R](compute_marginal_energy_cost.md)
- [compute_marginal_flex_revenue.R](compute_marginal_flex_revenue.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- candidate_market_utc : POSIXct vector. The market slot of each timestep of the candidate.
- market_utc           : POSIXct vector. The target market slots, in the order the totals are wanted.

## Output data

- Factor, the same length as candidate_market_utc, with one level per entry of market_utc. A timestep whose slot is not among the targets comes back as NA, and aggregate_by_market_slot() then leaves it out of every total, which is what the masking walk did.

## Other notes from the file header

### Code outline

1. Match each timestep against the target slots.

### Usage instructions

```r
slot_index <- market_slot_index(period_chunk$MarketUTC, market_utc)
```

## Diagram

![Block diagram of market_slot_index.R](market_slot_index.jpg)

Also available as [market_slot_index.svg](market_slot_index.svg).

---

[Back to the code structure index](../Code_Structure.md)
