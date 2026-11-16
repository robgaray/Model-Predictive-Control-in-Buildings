# build_market_timeline.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/build_market_timeline.R`

## Function

Builds the market timeline (bid time, period begin/end, optimization horizon, aim) for one market role (Scheduling or Piloting) and writes it into the role's Sched_*/Pilot_* columns of Main_df. Supports two modes:

- Basic  (complex_market_config == "no")  : deterministic market timeline from the role's optimisation horizon parameters.
- Complex (complex_market_config == "yes") : timeline built from the role's market-config table. The optimization horizon is computed from end_optimization.

This is the logic shared by the Scheduling and Piloting blocks of prepare_market_calendar(), parametrized by role. Every time is clipped to the simulation range. A market whose control period is left with no length, because it falls at the edge of the simulation or outside it, controls no time step and trades nothing, so it is not placed.

## Called by

- [prepare_market_calendar.R](prepare_market_calendar.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- role                   : Character. Column prefix for this market role, "Sched" or "Pilot".
- config_table           : Data frame. The role's market config table (parameters$market_config_scheduling or parameters$market_config_piloting), used only when complex_market_config == "yes".
- implementation_horizon : Numeric (hours). The role's Implementation_horizon_scheduling/piloting.
- optimization_horizon   : Numeric (hours). The role's Optimization_horizon_scheduling/piloting.
- anticipation           : Numeric (hours). The role's Anticipation_scheduling/piloting.
- optimization_aim       : Character. The role's optimization_aim_scheduling/piloting, already resolved by map_optimization_aim() to "energy"/"flexibility" (Scheduling) or "operation"/"operationflex" (Piloting).
- aim_label_energy       : Character. Market_Aim label used in basic mode when optimization_aim is neither "flexibility" nor "operationflex" ("E" for Scheduling, "O" for Piloting).
- aim_label_flex         : Character. Market_Aim label used in basic mode when optimization_aim is "flexibility" (Scheduling) or "operationflex" (Piloting) ("E+F" for Scheduling, "O+F" for Piloting).
- complex_market_config  : Character. "yes" or "no" (already validated by the caller).
- time_min, time_max     : POSIXct scalars. Main_df$time range.
- Main_df                : Data frame. The main simulation data frame.

## Output data

- Main_df : Data frame. Updated with the role's <role>_Market_Name/Bid_time/Period_Begin/Period_End/ Optimization_Horizon/Market_Aim columns.

## Other notes from the file header

### Code outline

1. Build the role's market timeline (basic or complex mode)
2. Leave out the markets whose control period has no length
3. Write the timeline into Main_df at each market's bid time

### Usage instructions

```r
Main_df <- build_market_timeline(
  role                   = "Sched",
  config_table           = parameters$market_config_scheduling,
  implementation_horizon =
  parameters$market$Implementation_horizon_scheduling,
  optimization_horizon   = parameters$market$Optimization_horizon_scheduling,
  anticipation           = parameters$market$Anticipation_scheduling,
  optimization_aim       = parameters$market$optimization_aim_scheduling,
  aim_label_energy       = "E",
  aim_label_flex         = "E+F",
  complex_market_config  = complex_market_config,
  time_min               = time_min,
  time_max               = time_max,
  Main_df                = Main_df
  )
```

## Diagram

![Block diagram of build_market_timeline.R](build_market_timeline.jpg)

Also available as [build_market_timeline.svg](build_market_timeline.svg).

---

[Back to the code structure index](../Code_Structure.md)
