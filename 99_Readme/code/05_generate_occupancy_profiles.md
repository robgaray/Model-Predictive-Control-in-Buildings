# 05_generate_occupancy_profiles.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/05_generate_occupancy_profiles.R`

## Function

Generates Main_df$Occupancy from parameters$use_patterns. Each timestamp is mapped to a MONTH row, weekday column and hourly TYPE value. Hour 00 is mapped to H24. Sourced by Main.R before simulation.

## Called by

- [Main.R](Main.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- Main_df, with its time column.
- parameters$use_patterns : the occupancy table, by month, weekday and hour.

## Output data

- Main_df$Occupancy, one value per row.

## Other notes from the file header

### Code outline

1. Map each timestamp to its month row, weekday column and hour.
2. Read the occupancy of that cell, with hour 00 taken as H24.

### Usage instructions

Not called: sourced by Main.R before the simulation, and before 06_generate_scheduling_profiles.R, which reads its result.

## Diagram

![Block diagram of 05_generate_occupancy_profiles.R](05_generate_occupancy_profiles.jpg)

Also available as [05_generate_occupancy_profiles.svg](05_generate_occupancy_profiles.svg).

---

[Back to the code structure index](../Code_Structure.md)
