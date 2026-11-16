# convert_modes_to_setpoints.R

**Function** &nbsp;·&nbsp; `30_Simulation/05_Models/01_Building/03_Functions/convert_modes_to_setpoints.R`

## Function

HVAC modes are used to define heating and cooling setpoints. This function performs a conversion from modes to setpoints: each market period carries exactly one mode, and its heating and cooling setpoints are read from the table of modes. Once the setpoints are defined, this function converts high-level setpoints to low-level setpoints with hysteresis deadbands. The output carries exactly one row per market period. It runs once per candidate of the genetic algorithm. The table of modes is checked once, when load_13_modes_setpoints.R reads it (no missing values, modes numbered 1..n), so it is not checked again here.

## Called by

- [decode_building_genes.R](decode_building_genes.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- setpoint_modes_df : Data frame. Mode of each market period, as returned by maxmode(). Columns: period  – POSIXct. Market period timestamps. maxmode – Integer. Active mode index per period.
- setpoint_modes    : Data frame. Lookup table mapping mode indices to heating and cooling setpoint values, as read by load_13_modes_setpoints.R. Columns: mode    – Integer. Mode index. heating – Numeric. Heating setpoint (°C). cooling – Numeric. Cooling setpoint (°C).
- Deadband          : Numeric scalar. Deadband width for the hysteresis thermostat. Applied symmetrically: STP_xxx_low  = STP_xxx - Deadband/2 STP_xxx_high = STP_xxx + Deadband/2
- target_periods    : POSIXct vector. Market period timestamps, in increasing order. The output carries one row per period.

## Output data

- Data frame (df) with columns: period        – POSIXct. Market period timestamps. STP_heat      – Numeric. Heating setpoint. STP_cool      – Numeric. Cooling setpoint. STP_heat_low  – Numeric. Heating activation threshold (lower). STP_heat_high – Numeric. Heating deactivation threshold (upper). STP_cool_low  – Numeric. Cooling activation threshold (lower). STP_cool_high – Numeric. Cooling deactivation threshold (upper).

## Other notes from the file header

### Code outline

1. Mode of each target period
2. Look up setpoint values for each mode from setpoint_modes table
3. Apply deadband offsets

### Usage instructions

```r
sp_df <- convert_modes_to_setpoints(setpoint_modes_df = maxmode_result,
  setpoint_modes = asset$setpoint_modes,
  Deadband = asset$control$Deadband,
  target_periods = timestamps$target_periods)
```

### Exceptions and special cases

- If there are fewer modes than periods, the function stops with an error: every period needs a mode.
- If a requested mode does not exist in setpoint_modes, the function stops with an error so the simulation does not continue with missing setpoints.
- Deadband is applied symmetrically (see above).

## Diagram

![Block diagram of convert_modes_to_setpoints.R](convert_modes_to_setpoints.jpg)

Also available as [convert_modes_to_setpoints.svg](convert_modes_to_setpoints.svg).

---

[Back to the code structure index](../Code_Structure.md)
