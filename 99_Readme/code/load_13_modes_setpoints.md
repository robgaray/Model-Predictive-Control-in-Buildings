# load_13_modes_setpoints.R

**Script** &nbsp;·&nbsp; `30_Simulation/05_Models/01_Building/04_Scripts/load_13_modes_setpoints.R`

## Function

Loads the setpoint-modes table from 13_Modes_setpoints.csv and stores it in parameters$setpoint_modes. The table is the whole file, or the part of it that follows a block of parameters above it, which another reader loads. Drops the units row, the first row under the header, with drop_unit_row(), which stops when that row holds data. Validates:

- the required columns
- the absence of NA values
- integer mode codes
- consecutive mode numbering starting at 1

Sourced from load_building_parameters(), which supplies the paths of the asset.

## Called by

- [load_building_parameters.R](load_building_parameters.md)

## What it calls, in order of appearance

- [split_config_sections.R](split_config_sections.md)
- [drop_unit_row.R](drop_unit_row.md)

## Input data

- paths$setpoint_mode_file : path of 13_Modes_setpoints.csv, in the configuration folder of the asset, as build_asset_paths() gives it.
- parameters : the list being assembled, to which this script adds one sub-list.

## Output data

- parameters$setpoint_modes, populated. Nothing else is modified.
- load_building_parameters() gathers the group into the groups of the building.

## Other notes from the file header

### Code outline

1. Read the table of the file, dropping the unit placeholder row.
2. Check the columns, the absence of NA, and that the mode codes are consecutive integers from one.
3. Store the table in parameters$setpoint_modes.

### Usage instructions

Not called: sourced by load_building_parameters(), which supplies paths, the paths of the asset, and parameters, and takes the updated parameters back.

## Diagram

![Block diagram of load_13_modes_setpoints.R](load_13_modes_setpoints.jpg)

Also available as [load_13_modes_setpoints.svg](load_13_modes_setpoints.svg).

---

[Back to the code structure index](../Code_Structure.md)
