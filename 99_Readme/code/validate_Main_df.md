# validate_Main_df.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/validate_Main_df.R`

## Function

This function performs structural and content validation of the main simulation data frame (Main_df) before it is used in the MPC simulation loop. Main_df is assembled by assemble_main_df.R from:

- 2 real input dataframes:
    - Meteo_df
    - Energy_Prices_df
- 3 synthetic dataframes:
    - System_variables_df
    - Flexibility_actions_df
    - Meteo_transformations_df

It checks the following aspects:

1. That Main_df is a non-empty data frame.
2. That all required columns are present.
3. That the 'time' column is POSIXct, contains no NAs, and is strictly increasing.
4. That all non-time required columns are numeric.
5. Soft physical range check on Elec_unit_cost_buy (warning).
6. That SolarR contains no negative values (hard check).

The table of each asset, with its own columns, is checked by validate_asset_df().

## Called by

- [load_all_parameters.R](load_all_parameters.md)

## What it calls, in order of appearance

- [get_validation_bounds.R](get_validation_bounds.md)

## Input data

- Main_df : Data frame. The main simulation data frame. It must contain every column of required_cols. By origin:
    - time
    - Meteo_df: the weather series
    - Energy_Prices_df: the energy and flexibility prices and the flexibility probabilities
    - System_variables_df, with the columns of:
        - the net electricity of the system, in four versions: _exec (what was executed), _plan (the plan), _plan_flex_down and _plan_flex_up (the downward and upward flexibility itineraries)
        - the flexibility committed on each leg
        - the cash flows of the system
    - Flexibility_actions_df: Flex_Act
    - Meteo_transformations_df: T_ext_24h and the forecasts

Output columns are present from the start, to be filled during the simulation run.

- bounding_validation_config : Data frame. The plausibility bounds of the columns, from Validation_bounding_simulation.csv.
- required_cols : Character vector. The columns the assembled Main_df must hold: those of stage assembly in 02_Needed_cols.csv, as load_needed_columns() returns them.

## Output data

- Invisibly returns TRUE if all checks pass.
- Nothing is written to the console when all checks pass.

## Other notes from the file header

### Code outline

1. Check data frame structure
2. Check required columns
3. Validate time column
4. Validate numeric columns
5. Plausibility range checks

### Usage instructions

```r
validate_Main_df(Main_df, bounding_validation_config,
  parameters$needed_cols_assembly)
```

### Exceptions and special cases

- If Main_df is not a data frame, an error is raised via stop().
- If Main_df is empty (zero rows), an error is raised via stop().
- If any required column is missing, an error is raised listing all missing column names.
- If 'time' is not POSIXct, contains NAs, or is not strictly increasing, an error is raised via stop().
- If any non-time required column is not numeric, an error is raised listing the offending column names.
- Text is not checked here: it is the weather input itself, interpolated, so the range of Validation_Meteo_df.csv, checked when the weather is read, already covers it.
- If Elec_unit_cost_buy falls below its plausibility bound, a warning() is issued (soft check, simulation continues). The bound is that of Validation_bounding_simulation.csv.
- A magnitude whose bound is empty on one side in Validation_bounding_simulation.csv is not checked on that side.
- If SolarR contains any negative value, an error is raised via stop().

## Diagram

![Block diagram of validate_Main_df.R](validate_Main_df.jpg)

Also available as [validate_Main_df.svg](validate_Main_df.svg).

---

[Back to the code structure index](../Code_Structure.md)
