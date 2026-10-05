# load_09_reward_parameters.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/load_09_reward_parameters.R`

## Function

Loads reward parameters from 09_Reward_parameters.csv, validates values against Parameter_config.csv, and stores the result in parameters$reward. Sourced from 02_load_all_parameters.R.

## Called by

- [02_load_all_parameters.R](02_load_all_parameters.md)

## What it calls, in order of appearance

- [read_and_validate_parameter_csv.R](read_and_validate_parameter_csv.md)

## Input data

- paths$reward_file : path of 09_Reward_parameters.csv, resolved by 01_initialization.R.
- parameters : the list being assembled, to which this script adds one sub-list.

## Output data

- parameters$reward, populated. Nothing else is modified.

## Other notes from the file header

### Code outline

1. Read the file and validate every value.
2. Store the result in parameters$reward.

### Usage instructions

Not called: sourced by 02_load_all_parameters.R, which supplies paths and parameters and takes the updated parameters back.

## Diagram

![Block diagram of load_09_reward_parameters.R](load_09_reward_parameters.jpg)

Also available as [load_09_reward_parameters.svg](load_09_reward_parameters.svg).

---

[Back to the code structure index](../Code_Structure.md)
