# 06_generate_scheduling_profiles.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/06_generate_scheduling_profiles.R`

## Function

Generates Main_df$Scheduling from Main_df$Occupancy and the anticipation parameters stored in parameters$operational_temperature_corrections. Sourced by Main.R before simulation. For each calendar day with at least one occupied row, computes one [interval_begin, interval_end] window (first/last occupied row's time, shifted by the anticipation parameters) and marks Scheduling = 1 over it. Window boundaries are located in the sorted Main_df$time vector via findInterval() (O(log rows) per day) instead of a per-day full boolean scan of Main_df$time (previously O(days x rows), measurably slower over a full year at fine time resolution); only the resulting row ranges are then written to 1, so the total assignment cost stays O(rows) across all days combined instead of being repeated per day. Verified against the previous per-day boolean-scan implementation over randomized occupancy patterns, including negative/reversed anticipation windows, sparse/zero/full occupancy, and windows spanning into neighboring days.

## Called by

- [Main.R](Main.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- Main_df, with its time and Occupancy columns.
- parameters$operational_temperature_corrections : the anticipation applied to the start and the end of each occupied stretch.

## Output data

- Main_df$Scheduling, one flag per row, marking the window the building is prepared over.

## Other notes from the file header

### Code outline

1. Find, for each calendar day, the first and last occupied row.
2. Shift that pair by the anticipation parameters.
3. Mark Scheduling over the resulting window.

### Usage instructions

Not called: sourced by Main.R after 05_generate_occupancy_profiles.R, whose column it reads.

## Diagram

![Block diagram of 06_generate_scheduling_profiles.R](06_generate_scheduling_profiles.jpg)

Also available as [06_generate_scheduling_profiles.svg](06_generate_scheduling_profiles.svg).

---

[Back to the code structure index](../Code_Structure.md)
