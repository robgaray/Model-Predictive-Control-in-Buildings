# load_01_optimization_parameters.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/load_01_optimization_parameters.R`

## Function

Loads optimization parameters from 01_Optimization_parameters.csv, validates raw values against Parameter_config.csv, calls load_optimization_parameters() for structured loading with internal clamping logic, and stores the result in parameters$optimization. Sourced from 02_load_all_parameters.R.

## Called by

- [02_load_all_parameters.R](02_load_all_parameters.md)

## What it calls, in order of appearance

- [read_and_validate_parameter_csv.R](read_and_validate_parameter_csv.md)
- [load_optimization_parameters.R](load_optimization_parameters.md)

## Input data

- paths$optimization_file : path of 01_Optimization_parameters.csv, resolved by 01_initialization.R.
- parameters : the list being assembled, to which this script adds one sub-list.

## Output data

- parameters$optimization, populated. Nothing else is modified.

## Other notes from the file header

### Code outline

1. Read the file and validate every value.
2. Turn the raw values into the optimization sub-list.
3. Store the result in parameters$optimization.

### Usage instructions

Not called: sourced by 02_load_all_parameters.R, which supplies paths and parameters and takes the updated parameters back.

## Diagram

![Block diagram of load_01_optimization_parameters.R](load_01_optimization_parameters.jpg)

Also available as [load_01_optimization_parameters.svg](load_01_optimization_parameters.svg).

---

[Back to the code structure index](../Code_Structure.md)
