# load_16_debug_and_config.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/load_16_debug_and_config.R`

## Function

Loads debug and configuration parameters from 16_Debug_and_config.csv, validates raw values against Parameter_config.csv, calls load_debug_and_config_parameters() for structured loading, and stores the result in parameters$debug_and_config. Sourced from 02_load_all_parameters.R.

## Called by

- [02_load_all_parameters.R](02_load_all_parameters.md)

## What it calls, in order of appearance

- [read_and_validate_parameter_csv.R](read_and_validate_parameter_csv.md)
- [load_debug_and_config_parameters.R](load_debug_and_config_parameters.md)

## Input data

- paths$debug_and_config_file : path of 16_Debug_and_config.csv, resolved by 01_initialization.R.
- parameters : the list being assembled, to which this script adds one sub-list.

## Output data

- parameters$debug_and_config, populated. Nothing else is modified.

## Other notes from the file header

### Code outline

1. Read the file and validate every value.
2. Turn the raw values into the debug sub-list.
3. Store the result in parameters$debug_and_config.

### Usage instructions

Not called: sourced by 02_load_all_parameters.R, which supplies paths and parameters and takes the updated parameters back.

## Diagram

![Block diagram of load_16_debug_and_config.R](load_16_debug_and_config.jpg)

Also available as [load_16_debug_and_config.svg](load_16_debug_and_config.svg).

---

[Back to the code structure index](../Code_Structure.md)
