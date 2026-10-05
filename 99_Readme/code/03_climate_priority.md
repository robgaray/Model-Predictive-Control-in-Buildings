# 03_climate_priority.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/03_climate_priority.R`

## Function

Generates Main_df$Overall_Climate on a daily basis from Main_df$Text and parameters$operational_temperature_corrections. Sourced by Main.R before simulation. A day is tagged "Heating" only when every one of the preceding HDD_period individual 24h periods has its own mean Text below T_ref_Heating_Season - not when their HDD_period-day trailing average does. "Cooling" is the equivalent check against T_ref_Cooling_Season with CDD_period 24h periods and a mean above the threshold. Any day failing both is "Intermediate". Each 24h period's mean is computed with cumulative sums over Main_df$time (sorted, strictly increasing) plus findInterval() to locate its row range in O(log rows) - equivalent to, but avoids, rescanning the full Main_df$time vector once per day and per 24h period (which is O(days x period x rows) and measurably slower over a full year at 5' resolution). Verified against a per-day boolean-scan implementation over randomized series, including fractional HDD_period/CDD_period, missing whole days, and series shorter than the window.

## Called by

- [Main.R](Main.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- Main_df, with its time and Text columns.
- parameters$operational_temperature_corrections : the season reference temperatures and the number of trailing periods each verdict is taken over.

## Output data

- Main_df$Overall_Climate, one verdict per row: Heating, Cooling or neither, held constant over the calendar day.

## Other notes from the file header

### Code outline

1. Resolve the daily mean of Text.
2. Tag a day Heating when every one of the preceding periods is below the heating reference, Cooling on the mirror test.
3. Spread the daily verdict over every row of its day.

### Usage instructions

Not called: sourced by Main.R before the simulation, once Main_df carries its weather columns.

## Diagram

![Block diagram of 03_climate_priority.R](03_climate_priority.jpg)

Also available as [03_climate_priority.svg](03_climate_priority.svg).

---

[Back to the code structure index](../Code_Structure.md)
