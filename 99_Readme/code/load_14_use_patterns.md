# load_14_use_patterns.R

**Script** &nbsp;·&nbsp; `30_Simulation/05_Models/01_Building/04_Scripts/load_14_use_patterns.R`

## Function

Loads occupancy use patterns from 14_Use_Patterns.csv, validates both tables (TYPE and MONTH blocks), and stores them in parameters$use_patterns. Sourced from load_building_parameters(), which supplies the paths of the asset.

## Called by

- [load_building_parameters.R](load_building_parameters.md)

## What it calls, in order of appearance

- [drop_unit_row.R](drop_unit_row.md) &nbsp;(2 call sites)

## Input data

- paths$use_patterns_file : path of 14_Use_Patterns.csv, in the configuration folder of the asset, as build_asset_paths() gives it.
- parameters : the list being assembled, to which this script adds one sub-list.

## Output data

- parameters$use_patterns, populated. Nothing else is modified.
- load_building_parameters() gathers the group into the groups of the building.

## Other notes from the file header

### Code outline

1. Read the two tables, dropping the units row of each with drop_unit_row().
2. Check the required columns are there.
3. Store the table in parameters$use_patterns.

### Usage instructions

Not called: sourced by load_building_parameters(), which supplies paths, the paths of the asset, and parameters, and takes the updated parameters back.

## Diagram

![Block diagram of load_14_use_patterns.R](load_14_use_patterns.jpg)

Also available as [load_14_use_patterns.svg](load_14_use_patterns.svg).

---

[Back to the code structure index](../Code_Structure.md)
