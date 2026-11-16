# assemble_main_df.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/assemble_main_df.R`

## Function

Loads the 2 real input dataframes:

- Meteo_df
- Energy_Prices_df

and generates the 3 synthetic dataframes:

- System_variables_df
- Flexibility_actions_df
- Meteo_transformations_df

on a common master grid, then assembles them into a single Main_df: what is common to every asset and the balances of the system. The columns of each asset are not in Main_df: they are in the table of the asset, which load_all_parameters() builds on the same grid once the asset registry is loaded.

## Called by

- [load_all_parameters.R](load_all_parameters.md)

## What it calls, in order of appearance

- [load_meteo_df.R](load_meteo_df.md)
- [load_energy_prices_df.R](load_energy_prices_df.md)
- [console_message.R](console_message.md) &nbsp;(3 call sites)
- [console_time.R](console_time.md) &nbsp;(4 call sites)
- [generate_variables_df.R](generate_variables_df.md)
- [generate_flexibility_actions_df.R](generate_flexibility_actions_df.md)
- [generate_meteo_transformations_df.R](generate_meteo_transformations_df.md)

## Blocks

The piece calls 7 items, so it is documented in blocks:

- [Called items, block 1 of 2](assemble_main_df__1.md)
- [Called items, block 2 of 2](assemble_main_df__2.md)

## Input data

- paths      : List, built by initialize_simulator(). Must contain:
    - meteo_file
    - meteo_validation_file
    - energy_prices_file
    - energy_prices_validation_file
    - system_variables_file
- parameters : List. Must contain parameters$computing, already loaded by load_internal_parameters.R, whose main_resolution_sec defines the master grid built here.

## Output data

- Main_df : Data frame on the master grid, with the columns of:
    - time (POSIXct, master grid)
    - Meteo_df (interpolated)
    - Energy_Prices_df (step-held, at the start of each row's time step)
    - System_variables_df
    - Flexibility_actions_df
    - Meteo_transformations_df

The last three are generated directly on the master grid.

- One DATA line is written to the console, and a WARNING line when the end of a series is trimmed.

## Other notes from the file header

### Code outline

1. Load and validate Meteo_df, Energy_Prices_df
2. Determine the common time range (start strict, end trimmed with warning) and build the master grid
3. Interpolate Meteo_df onto the master grid
4. Step-hold Energy_Prices_df onto the master grid, at the start of each row's time step
5. Generate System_variables_df, Flexibility_actions_df, Meteo_transformations_df
6. Assemble Main_df

### Usage instructions

```r
source(file.path("30_Simulation", "04_Scripts", "assemble_main_df.R"))
```

Not called: sourced by load_all_parameters(), once the configuration is loaded and before Main_df is validated.

### Exceptions and special cases

- If Meteo_df$time and Energy_Prices_df$time do not start at exactly the same instant, stop() (no permissive fallback for the start of the series).
- If one series ends later than the other, the longer one is trimmed to the shorter one's end, and a WARNING line of the console reports how many rows were discarded and from which file.
- The first row has no time step before it, so it takes the first price of Energy_Prices_df.

## Diagram

![Block diagram of assemble_main_df.R](assemble_main_df.jpg)

Also available as [assemble_main_df.svg](assemble_main_df.svg).

---

[Back to the code structure index](../Code_Structure.md)
