# compute_max_steps_ahead.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/compute_max_steps_ahead.R`

## Function

Works out how far ahead any market of the simulation looks, as a number of market-resolution steps. It is the width of the price matrices and of the market commitment matrices: one column per step ahead of a market event. The distance of a market is measured from its bid time to the end of its optimization horizon, and it is read from the market configuration that the simulation actually uses:

- Basic mode (Complex_Market_Config = "no"): the Scheduling and the Piloting market of 03_Market_config.csv. hours = Anticipation + Optimization_horizon
- Complex mode (Complex_Market_Config = "yes"): every market of 04_Market_config_scheduling.csv and 05_Market_config_piloting.csv. hours = closure + end + end_optimization

The largest distance found is turned into steps of market_resolution, rounded up, so that a horizon that is not an exact multiple of the resolution still gets a column for its last partial step.

## Called by

- [11_full_market_information_setup.R](11_full_market_information_setup.md)
- [12_market_commitments_setup.R](12_market_commitments_setup.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- parameters : Named list. Uses:
    - market$market_resolution (min)
    - market$Complex_Market_Config ("yes"/"no")
    - market$Anticipation_scheduling, market$Optimization_horizon_scheduling, market$Anticipation_piloting and market$Optimization_horizon_piloting (h), in basic mode
    - market_config_scheduling and market_config_piloting (data frames with closure, end and end_optimization, in h), in complex mode

## Output data

- Integer scalar. The number of market-resolution steps ahead.

## Other notes from the file header

### Code outline

1. Distance of the furthest market, in hours
2. Conversion to market-resolution steps

### Usage instructions

```r
max_steps_ahead <- compute_max_steps_ahead(parameters)
```

## Diagram

![Block diagram of compute_max_steps_ahead.R](compute_max_steps_ahead.jpg)

Also available as [compute_max_steps_ahead.svg](compute_max_steps_ahead.svg).

---

[Back to the code structure index](../Code_Structure.md)
