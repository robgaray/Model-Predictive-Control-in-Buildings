# Main.R

**Script** &nbsp;·&nbsp; `30_Simulation/Main.R`

## Function

This script performs a simulation of a Model Predictive Control (MPC) strategy applied to building energy management. It loads the necessary model parameters, control settings, and optimization parameters, then runs the simulation and exports the results.

## Called by

- Nothing calls it: this is the entry point of the simulation.

## What it calls, in order of appearance

- [01_initialization.R](01_initialization.md)
- [02_load_all_parameters.R](02_load_all_parameters.md)
- [03_climate_priority.R](03_climate_priority.md)
- [04_subset_main_df.R](04_subset_main_df.md)
- [05_generate_occupancy_profiles.R](05_generate_occupancy_profiles.md)
- [06_generate_scheduling_profiles.R](06_generate_scheduling_profiles.md)
- [07_reference_temperature_profiles.R](07_reference_temperature_profiles.md)
- [08_market_columns_setup.R](08_market_columns_setup.md)
- [09_flexibility_price_emulation.R](09_flexibility_price_emulation.md)
- [10_energy_price_signals_setup.R](10_energy_price_signals_setup.md)
- [11_full_market_information_setup.R](11_full_market_information_setup.md)
- [12_market_commitments_setup.R](12_market_commitments_setup.md)
- [13_economic_analysis_setup.R](13_economic_analysis_setup.md)
- [14_simulation.R](14_simulation.md)
- [15_economic_analysis_finalize.R](15_economic_analysis_finalize.md)
- [16_data_outputs.R](16_data_outputs.md)

## Blocks

The code of Main.R is split into 4 blocks, each made of numbered steps. A block that calls more than six items is split again into consecutive steps.

- [A. Initialization & parameter loading](Main__A.md) &nbsp;(steps 1 to 2)
- [B. Pre-processing](Main__B.md) &nbsp;(steps 3 to 14)
    - [B.1. Random seed](Main__B_1.md)
    - [B.2. Climate and period](Main__B_2.md)
    - [B.3. Profiles](Main__B_3.md)
    - [B.4. Markets and prices](Main__B_4.md)
- [C. Simulation](Main__C.md) &nbsp;(step 15)
- [D. Post-process & Export](Main__D.md) &nbsp;(steps 16 to 17)

## Input data

- 30_Simulation/02_Config/ : every configuration file, with the file names listed in 04_File_paths.csv and their validation tables in 00_Validation/.
- 30_Simulation/01_Data/   : Meteo_df.rds and Energy_Prices_df.rds, the input series.

## Output data

- 30_Simulation/90_Output/ : four tables, each as .csv and .rds, written by 16_data_outputs.R:
    - Main_df_computed
    - Sinthetized_df_computed
    - Economic_analysis_market_computed
    - Economic_analysis_slot_computed

## Other notes from the file header

### The MPC concept

A model is used to set the control criteria over a long-term horizon. Typical control horizon is in the range of 24 hours.

### The aim of the optimization

Depending on the selected configuration, the MPC is set to optimize the energy consumption over the control horizon, or even to deliver flexibility to the grid.

### The Building

The building is modeled using a simplified thermal model with parameters defined in external configuration files. The model includes thermal dynamics, HVAC system characteristics, and occupant comfort settings. The relevant file for this is "11_Model_parameters.csv".

### Control Strategy

The control strategy can be based on either fixed setpoints or predefined modes. The optimizer will select the best control actions within a set of modes (discrete options) or a set of setpoints (real-values) as per the selected control option. The control parameters are defined in:

- "02_Control.csv": the parameters of either control option
- "08_Flexibility_Event_Configuration.csv": the parameters that define the flexibility events
- "12_Temperature_Setpoints.csv": the setpoint ranges, used by the setpoints option
- "13_Modes_setpoints.csv": the modes, used by the modes option

### Weather forecast

MPC requires a forecast of the contextual information. In this case, the weather forecast. Here, two options are considered:

1. Inaccurate forecast: The forecast has some errors compared to the actual weather conditions.
2. Accurate forecast: The forecast matches the actual weather conditions perfectly.

MPC is executed with either of these options but then the "optimal" control actions are applied to the real building model with the actual weather conditions. The forecast parameters for the inaccurate forecast are defined in "15_Forecast_parameters.csv".

### Optimal criteria (reward)

The optimization aims to maximize a reward function that balances energy costs and occupant comfort. The reward parameters are defined in "09_Reward_parameters.csv".

### Code outline

A. Initialization & parameter loading

1. Initialization
2. Load data and model parameters

B. Pre-processing

- B.1 Random seed
3. Fix the random seed (reproducibility of the whole run)

B.2 Climate and period

4. Climate priority (before subsetting, needs full-year trailing averages)
5. Subset Main_df by month / period

B.3 Profiles

6. Generate occupancy profiles
7. Generate scheduling profiles
8. Reference temperature profiles

B.4 Markets and prices

9. Initialise market columns in Main_df
10. Flexibility generation (conditional)

11. Energy/flexibility price signals (buy/sell derivation)

12. Build future-horizon price matrices

13. Initialise market output matrices (market commitments)

14. Initialise the economic analysis accumulators

C. Simulation

15. Perform simulation (calls to external script)

D. Post-process & Export

16. Complete the economic analysis (execution phase and fractions)

17. Export results to files

### Usage instructions

From the repository root:

- Rscript 30_Simulation/Main.R

It is the only file of the simulation meant to be run directly.

## Diagram

![Block diagram of Main.R](Main.jpg)

Also available as [Main.svg](Main.svg).

---

[Back to the code structure index](../Code_Structure.md)
