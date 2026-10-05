# load_03_market_config.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/load_03_market_config.R`

## Function

Loads market configuration from 03_Market_config.csv, which also holds the six limits of the flexibility price emulation, used by both the basic and the complex modes of 09_flexibility_price_emulation.R:

- Max_flex_periods_day
- Max_flex_com_price
- Max_flex_exec_price
- Max_flex_period_duration
- Max_flex_probability_down
- Max_flex_probability_up

It validates raw values against Parameter_config.csv, calls load_market_parameters() for structured loading with the horizon clamping logic of Validation_Market_Config.csv, resolves the raw scheduling/piloting aim codes (O/E/O+F/E+F) to internal text labels ("energy"/"flexibility"/"operation"/"operationflex") via map_optimization_aim(), and sets parameters$control$optimization_aim. Stores the result in parameters$market. Sourced from 02_load_all_parameters.R. Requires parameters$control and parameters$optimization to be already loaded.

## Called by

- [02_load_all_parameters.R](02_load_all_parameters.md)

## What it calls, in order of appearance

- [read_and_validate_parameter_csv.R](read_and_validate_parameter_csv.md)
- [load_market_parameters.R](load_market_parameters.md)
- [map_optimization_aim.R](map_optimization_aim.md) &nbsp;(2 call sites)

## Input data

- paths$market_file : path of 03_Market_config.csv, resolved by 01_initialization.R.
- Its validation table, Validation_Market_Config.csv, read alongside it.
- parameters : the list being assembled, to which this script adds one sub-list.

## Output data

- parameters$market, populated. Nothing else is modified.

## Other notes from the file header

### Code outline

1. Read the file and validate every value.
2. Turn the raw values into the market sub-list.
3. Translate each aim letter into its internal name.
4. Store the result in parameters$market.

### Usage instructions

Not called: sourced by 02_load_all_parameters.R, which supplies paths and parameters and takes the updated parameters back.

## Diagram

![Block diagram of load_03_market_config.R](load_03_market_config.jpg)

Also available as [load_03_market_config.svg](load_03_market_config.svg).

---

[Back to the code structure index](../Code_Structure.md)
