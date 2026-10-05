# load_energy_prices_df.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/load_energy_prices_df.R`

## Function

Loads Energy_Prices_df (energy and flexibility market price input data) from disk and validates it before it is used by assemble_main_df.R.

## Called by

- [assemble_main_df.R](assemble_main_df.md)

## What it calls, in order of appearance

- [validate_time_grid.R](validate_time_grid.md)
- [validate_dataframe_config.R](validate_dataframe_config.md)

## Input data

- paths$energy_prices_file            : Character. Path to Energy_Prices_df.rds.
- paths$energy_prices_validation_file : Character. Path to Validation_Energy_Prices_df.csv.

## Output data

- Energy_Prices_df       : Data frame. Columns: time (POSIXct), Elec_unit_cost_buy, Elec_unit_cost_distribution, Flex_unit_cost_down_com, Flex_unit_cost_down_exec, Flex_unit_cost_up_com, Flex_unit_cost_up_exec, Flex_Probab_down, Flex_Probab_up.
- energy_prices_step_sec : Numeric. Detected step (seconds) of Energy_Prices_df$time.

## Other notes from the file header

### Code outline

1. Read Energy_Prices_df.rds
2. Validate required columns are present and numeric
3. Validate the time grid (equispaced, compatible with Main_df's resolution)
4. Validate column ranges against Validation_Energy_Prices_df.csv

### Usage instructions

```r
source(file.path("30_Simulation", "04_Scripts", "load_energy_prices_df.R"))
```

Not called: sourced by assemble_main_df.R while it builds Main_df out of the input series.

## Diagram

![Block diagram of load_energy_prices_df.R](load_energy_prices_df.jpg)

Also available as [load_energy_prices_df.svg](load_energy_prices_df.svg).

---

[Back to the code structure index](../Code_Structure.md)
