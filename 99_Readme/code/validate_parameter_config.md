# validate_parameter_config.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/validate_parameter_config.R`

## Function

Validates a named list of parameter values against the rules of the parameter catalogue (Parameter_catalogue.csv) for a given file name. For each matching rule the function checks:

- Integer : value is numeric, a whole number within the integer tolerance, and within [min, max]
- Real    : value is numeric and within [min, max]
- Options : as.character(value) is one of the allowed options
- Text    : no additional constraint beyond existence

An empty min or max means no bound on that side. A parameter that is missing stops the run (or warns, as the rule says), and the message gives its default value from the catalogue: the value is never filled in silently. Validation failures trigger stop() for output == "Error" or warning() for output == "Warning". Three things stop the run whatever the output of the rules, because they mean the file and its rules do not match:

- a file with no rule at all;
- a parameter of the file that no rule describes, usually a name written wrong or left over. The message names the closest rule;
- a rule whose type is none of the four above.

## Called by

- [load_12_asset_registry.R](load_12_asset_registry.md)
- [load_parameter_block.R](load_parameter_block.md)
- [read_and_validate_parameter_csv.R](read_and_validate_parameter_csv.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- values : the named list of values read from a configuration file.
- file_name : the name the catalogue files its rules under, e.g. "09_Reward_parameters.csv".
- validation_config : the parameter catalogue, already read by load_parameter_catalogue().

## Output data

- TRUE, invisibly, when every rule passes. Otherwise it stops, naming:
    - the parameter
    - the rule it broke
    - its value

## Other notes from the file header

### Arguments

values            Named list. parameter_name -> raw value (character

- or numeric) as read from the CSV file.

file_name         Character. Base name of the config file

- (e.g. "11_Model_parameters.csv").

validation_config Named list, as load_parameter_catalogue()

- returns it: the rules of the catalogue and the
- integer tolerance.

### Returns

invisible(TRUE) on success; stops on first Error-class failure.

### Code outline

1. Keep the rules filed under this file name. Stop when there are none, or when the file holds a parameter no rule describes.
2. Check each rule against its one value: the type, the range and, for an options rule, the allowed set.
3. Stop on the first breach, or warn, as the rule's output says.

### Usage instructions

```r
validate_parameter_config(values, "09_Reward_parameters.csv",
  validation_config)
```

## Diagram

![Block diagram of validate_parameter_config.R](validate_parameter_config.jpg)

Also available as [validate_parameter_config.svg](validate_parameter_config.svg).

---

[Back to the code structure index](../Code_Structure.md)
