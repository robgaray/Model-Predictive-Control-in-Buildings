# validate_model_parameters.R

**Function** &nbsp;·&nbsp; `30_Simulation/05_Models/01_Building/03_Functions/validate_model_parameters.R`

## Function

This function checks what the parameter catalogue cannot express about the building volume loaded from 11_Model_parameters.csv. The types and ranges of every model parameter are those of the parameter catalogue, already applied when the file is read; that range admits 0 for Volume, so:

- a volume that is not positive stops the simulation;
- a volume below the plausibility bound of Validation_bounding_simulation.csv is reported with a warning.

## Called by

- [load_11_model_parameters.R](load_11_model_parameters.md)

## What it calls, in order of appearance

- [get_validation_bounds.R](get_validation_bounds.md)

## Input data

- model_parameters : Named list. Model parameters as loaded from 11_Model_parameters.csv via load_11_model_parameters.R.
- bounding_validation_config : Data frame. Content of Validation_bounding_simulation.csv, holding the plausibility bound below which the building volume is reported as unusually small.
- model_file_name  : Character. Name of the model parameter file, the one its rows of Validation_bounding_simulation.csv carry.

## Output data

- model_parameters : Named list. The input list, unchanged. A volume that is not positive stops the simulation.

## Other notes from the file header

### Code outline

1. Validate Volume parameter

### Usage instructions

```r
model_parameters <- validate_model_parameters(model_parameters,
  bounding_validation_config, model_file_name)
```

## Diagram

![Block diagram of validate_model_parameters.R](validate_model_parameters.jpg)

Also available as [validate_model_parameters.svg](validate_model_parameters.svg).

---

[Back to the code structure index](../Code_Structure.md)
