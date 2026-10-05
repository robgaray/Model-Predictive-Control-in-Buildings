# load_02_control.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/load_02_control.R`

## Function

Loads 02_Control.csv, validates every value against Parameter_config.csv, and structures it with load_control_parameters() into parameters$control. These are the control parameters that apply whatever control_type is chosen; control_type is read as text, and its validity is enforced by Parameter_config.csv (Options "modes,setpoints").

## Called by

- [02_load_all_parameters.R](02_load_all_parameters.md)

## What it calls, in order of appearance

- [read_and_validate_parameter_csv.R](read_and_validate_parameter_csv.md)
- [load_control_parameters.R](load_control_parameters.md)

## Input data

- paths$control_file : path of 02_Control.csv, resolved by 01_initialization.R.
- parameters : the list being assembled.

## Output data

- parameters$control, created with the global control parameters.

## Other notes from the file header

### Code outline

1. Read the file and validate every value.
2. Structure it with load_control_parameters() and store it in parameters$control.

### Usage instructions

Not called: sourced by 02_load_all_parameters.R, which supplies paths and parameters and takes the updated parameters back.

## Diagram

![Block diagram of load_02_control.R](load_02_control.jpg)

Also available as [load_02_control.svg](load_02_control.svg).

---

[Back to the code structure index](../Code_Structure.md)
