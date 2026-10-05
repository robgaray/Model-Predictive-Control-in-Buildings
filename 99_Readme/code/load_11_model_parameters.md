# load_11_model_parameters.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/load_11_model_parameters.R`

## Function

Loads model parameters from 11_Model_parameters.csv, validates them against Parameter_config.csv, applies the domain-specific validate_model_parameters() check, computes Rvent parameters via compute_Rvent(), and stores the result in parameters$model. Sourced from 02_load_all_parameters.R. Requires parameters$physical_properties to be already loaded.

## Called by

- [02_load_all_parameters.R](02_load_all_parameters.md)

## What it calls, in order of appearance

- [read_and_validate_parameter_csv.R](read_and_validate_parameter_csv.md)
- [validate_model_parameters.R](validate_model_parameters.md)
- [compute_Rvent.R](compute_Rvent.md)

## Input data

- paths$model_file : path of 11_Model_parameters.csv, resolved by 01_initialization.R.
- parameters : the list being assembled, to which this script adds one sub-list.

## Output data

- parameters$model, populated. Nothing else is modified.

## Other notes from the file header

### Code outline

1. Read the file and validate every value.
2. Resolve the ventilation resistance of each regime.
3. Check the model parameters against their ranges.
4. Store the result in parameters$model.

### Usage instructions

Not called: sourced by 02_load_all_parameters.R, which supplies paths and parameters and takes the updated parameters back.

## Diagram

![Block diagram of load_11_model_parameters.R](load_11_model_parameters.jpg)

Also available as [load_11_model_parameters.svg](load_11_model_parameters.svg).

---

[Back to the code structure index](../Code_Structure.md)
