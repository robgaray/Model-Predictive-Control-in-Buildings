# load_08_flexibility_event_configuration.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/load_08_flexibility_event_configuration.R`

## Function

Loads 08_Flexibility_Event_Configuration.csv, validates every value against Parameter_config.csv, and structures it with load_flexibility_event_parameters() into parameters$control. These are the parameters that define how a flexibility event is built and committed.

## Called by

- [02_load_all_parameters.R](02_load_all_parameters.md)

## What it calls, in order of appearance

- [read_and_validate_parameter_csv.R](read_and_validate_parameter_csv.md)
- [load_flexibility_event_parameters.R](load_flexibility_event_parameters.md)

## Input data

- paths$flexibility_events_file : path of 08_Flexibility_Event_Configuration.csv, resolved by 01_initialization.R.
- parameters : the list being assembled.

## Output data

- parameters$control, with these parameters added to it.

## Other notes from the file header

### Code outline

1. Read the file and validate every value.
2. Structure it with load_flexibility_event_parameters() and store it in parameters$control.

### Usage instructions

Not called: sourced by 02_load_all_parameters.R, which supplies paths and parameters and takes the updated parameters back.

## Diagram

![Block diagram of load_08_flexibility_event_configuration.R](load_08_flexibility_event_configuration.jpg)

Also available as [load_08_flexibility_event_configuration.svg](load_08_flexibility_event_configuration.svg).

---

[Back to the code structure index](../Code_Structure.md)
