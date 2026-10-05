# is_market_active.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/is_market_active.R`

## Function

Determines whether a market configuration value represents an active market.

## Called by

- [11_full_market_information_setup.R](11_full_market_information_setup.md)
- [12_market_commitments_setup.R](12_market_commitments_setup.md)
- [13_economic_analysis_setup.R](13_economic_analysis_setup.md)
- [14_simulation.R](14_simulation.md)
- [generate_flexibility_events.R](generate_flexibility_events.md)
- [resolve_marginal_context.R](resolve_marginal_context.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- market_name_raw : Any scalar value to evaluate.

## Output data

- Logical. TRUE if market is active, FALSE otherwise.

## Other notes from the file header

### Usage instructions

```r
is_market_active(market_name_raw)
```

### Code outline

1. Trim the name and decide: anything that is not empty, not NA and not "0" marks an active market.

## Diagram

![Block diagram of is_market_active.R](is_market_active.jpg)

Also available as [is_market_active.svg](is_market_active.svg).

---

[Back to the code structure index](../Code_Structure.md)
