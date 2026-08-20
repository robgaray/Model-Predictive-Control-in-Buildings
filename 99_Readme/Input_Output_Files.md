# Input and Output Files

This page explains, input and output data.

This page does not cover parameter files ([section 13 of the README](../README.md#13-parametrization-and-graphic-user-interface) and `90_Structure/Parameter_Units.csv`)

## Location in the repository

- Inputs are read from `30_Simulation/01_Data/`
- Outputs are written to `30_Simulation/90_Output/`

## General content and purpose

Two files come in: `Meteo_df` (weather) and `Energy_Prices_df` (electricity and flexibility prices). They are read once, at the very start of a run, and merged together into `Main_df`.

Because the two source files can have a different time step from each other and from `Main_df`, they are checked for a consistent, evenly spaced time step and then interpolated onto `Main_df`'s own 5-minute grid.

Four files come out, all built once the simulation loop has finished:

- `Main_df_computed` : the complete simulation, one row per 5-minute timestep, with every physical and economic quantity the model computed. This file comprises a substantially greater number of variables than those created from the original input files.
- `Sinthetized_df_computed` : A summary of the simulation, with the whole year/period totals (comfort, energy, cost, revenue, reward). Useful comparing different simulation runs (parametric batches) side by side.
- `Economic_analysis_market_computed` and `Economic_analysis_slot_computed` - the per-market and per-slot economic breakdown described in [Economic data structures](Economic_Data_Structures.md); they are the exported form of the `economic_analysis` object.

Every column below is documented as it is at the end of a full-year run with the repository's default configuration (`30_Simulation/02_Config/*.csv` as shipped). Row counts, and a few columns noted individually, change with the configuration - this is called out explicitly wherever it applies.

------------------------------------------------------------------------

# Inputs

## Meteo_df

Hourly weather data for the whole simulated period. Read from `30_Simulation/01_Data/Meteo_df.csv` 

**Shape**: 8,784 rows (366 days at 1-hour resolution - 2024 is a leap year; a non-leap year would give 8,760 rows) x 3 columns.

| Column   | Type                | Unit | Typical range                                        | Temporal resolution   | Can it be `NA`? |
| -------- | ------------------- | ---- | ---------------------------------------------------- | --------------------- | --------------- |
| `time`   | POSIXct (date-time) | -    | full calendar year                                   | 1 hour, evenly spaced | No              |
| `Text`   | Numeric             | ºC   | -2.6 to 41.7 (site-dependent)                        | 1 hour                | No              |
| `SolarR` | Numeric             | W/m² | 0 to 919 (0 at night, up to full daytime irradiance) | 1 hour                | No              |

## Energy_Prices_df

Electricity and flexibility unit prices for the whole simulated period.

**Shape**: 35,132 rows (365.99 days at 15-minute resolution) x 8 columns.

The row count follows the market resolution the price series was generated at. `Energy_Prices_df` is interpolated onto whichever grid the simulation actually needs.

| Column                        | Type                | Unit  | Typical range                                     | Temporal resolution       | Can it be `NA`? |
| ----------------------------- | ------------------- | ----- | ------------------------------------------------- | ------------------------- | --------------- |
| `time`                        | POSIXct (date-time) | -     | full calendar year                                | 15 minutes, evenly spaced | No              |
| `Elec_unit_cost_buy`          | Numeric             | €/kWh | typically possitive, but can go slightly negative | 15 minutes                | No              |
| `Elec_unit_cost_distribution` | Numeric             | €/kWh | strictly >=0                                      | 15 minutes                | No              |
| `Flex_unit_cost_down_com`     | Numeric             | €/kWh | strictly >=0                                      | 15 minutes                | No              |
| `Flex_unit_cost_down_exec`    | Numeric             | €/kWh | strictly >=0                                      | 15 minutes                | No              |
| `Flex_unit_cost_up_com`       | Numeric             | €/kWh | strictly >=0                                      | 15 minutes                | No              |
| `Flex_unit_cost_up_exec`      | Numeric             | €/kWh | strictly >=0                                      | 15 minutes                | No              |
| `Flex_Probab`                 | Numeric (fraction)  | -     | 0 to 1                                            | 15 minutes                | No              |

Notes on the file shipped with the repository:

- `Flex_unit_cost_up_com` and `Flex_Probab` are always 0 in the file shipped with the repository. This is a property of this particular dataset, not a rule.

- No activation probability has been modelled into it 

None of these eight columns are used directly by the simulation loop: `energy_price_signals_setup.R` derives twelve buy/sell price signals from them (see `Main_df`'s "Derived buy/sell price signals" below), and `Flex_unit_cost_up_com`, `Flex_Probab` in particular are only the *legacy* signals kept for reference - see that script's header for the exact formulas.

------------------------------------------------------------------------

# Outputs

## Main_df_computed

The complete simulation result: every physical and economic quantity the model computed, one row per 5-minute timestep. This is `Main_df` itself, exported unchanged at the end of the run (`data_outputs.R`). It is the largest and most detailed output file, and the one every other output is derived from.

**Shape**: 

- One row per 5-minute timestep of the simulated period (up to 105,120 rows for a full, non-leap calendar year; fewer if `month_subset` or `period_subset` in `30_Debug_and_config.csv` restrict the run to less than a year)

- 111 columns (the count follows `30_Simulation/02_Config/02_Needed_cols.csv`, which lists every column the simulation guarantees to have by the time it starts; new columns are not created mid-run).

### Context suffixes

Most physical columns exist in three versions, one per "context":

- `_exec` - what actually happened, computed with real (not forecast) weather. This is the row's ground truth.
- `_plan` - what was committed in the last market decision (Scheduling or Piloting) that covers this row, computed with forecast weather at the time that decision was made.
- `_plan_flex` - the same commitment, but with a candidate flexibility event applied on top. Only meaningful when `parameters$control$optimization_aim` is `"flexibility"` or `"operationflex"`; otherwise it mirrors `_plan`.

### Time and weather

| Column                             | Type      | Unit | Range                                                                    | Resolution | `NA`? |
| ----------------------------------- | --------- | ---- | ------------------------------------------------------------------------ | ---------- | ----- |
| `time`                             | POSIXct   | -    | simulated period                                                         | 5 min      | No    |
| `Text`                             | Numeric   | ºC   | see `Meteo_df`                                                           | 5 min      | No    |
| `SolarR`                           | Numeric   | W/m² | see `Meteo_df`                                                           | 5 min      | No    |
| `T_ext_24h`                        | Numeric   | ºC   | similar to `Text`                                                        | 5 min      | No    |
| `Text_forec`, `Text_forec_ant`     | Numeric   | ºC   | similar to `Text`                                                        | 5 min      | No    |
| `SolarR_forec`, `SolarR_forec_ant` | Numeric   | W/m² | similar to `SolarR`                                                      | 5 min      | No    |
| `Act_vent`                         | Numeric   | -    | 0/1                                                                      | 5 min      | No    |
| `Overall_Climate`                  | Character | -    | one of `"Heating"`, `"Cooling"`, `"Intermediate"` (`climate_priority.R`) | 5 min      | No    |


### Legacy and derived price signals

8 columns copied in from `Energy_Prices_df` :

- `Elec_unit_cost_buy`

- `Elec_unit_cost_distribution`

- `Flex_unit_cost_down_com`

- `Flex_unit_cost_down_exec`

- `Flex_unit_cost_up_com`

- `Flex_unit_cost_up_exec`

- `Flex_Probab`

A new, locally generated variable:

- `Flex_Act`

12 derived buy/sell signals from them, all Numeric, in €/kWh, never `NA`:

- `Elec_unit_cost_import_buy`

- `Elec_unit_cost_import_sell`

- `Elec_unit_cost_export_buy`

- `Elec_unit_cost_export_sell`

- `Flex_unit_cost_down_com_buy`

- `Flex_unit_cost_down_com_sell`

- `Flex_unit_cost_down_exec_buy`

- `Flex_unit_cost_down_exec_sell`

- `Flex_unit_cost_up_com_buy`

- `Flex_unit_cost_up_com_sell`

- `Flex_unit_cost_up_exec_buy`

- `Flex_unit_cost_up_exec_sell`

These are the prices every market decision and every economic calculation actually uses - see [Economic data structures](Economic_Data_Structures.md) for how. 

### Occupancy, scheduling and comfort bands

| Column                                  | Type    | Unit | Range                                   | Resolution | `NA`? |
| --------------------------------------- | ------- | ---- | --------------------------------------- | ---------- | ----- |
| `Occupancy`                             | Integer | -    | 0/1                                     | 5 min      | No    |
| `Scheduling`                            | Integer | -    | 0/1                                     | 5 min      | No    |
| `Service_T_Low`, `Service_T_High`       | Numeric | ºC   | Temperature range, narrower than 0-50ºC | 5 min      | No    |
| `Scheduling_T_Low`, `Scheduling_T_High` | Numeric | ºC   | Temperature range, narrower than 0-50ºC | 5 min      | No    |



### Market timeline

| Column                                                                                                         | Type                       | Unit | Range                                                                                             | Resolution | `NA`?                                           |
| -------------------------------------------------------------------------------------------------------------- | -------------------------- | ---- | ------------------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------- |
| `MarketUTC`                                                                                                    | POSIXct                    | -    | same that ´time´                                                                                  | 5 min      | No                                              |
| `Sched_Market_Name`, `Pilot_Market_Name`                                                                       | Character                  | -    | market code (e.g. `"DA"`, `"ID1"`, `"cID2"`) on the row where that market clears, `"0"` elsewhere | 5 min      | Never `NA`; `"0"` is the "no market here" value |
| `Sched_Market_Bid_time`, `Pilot_Market_Bid_time`                                                               | Character (timestamp text) | -    | same that ´time´                                                                                  | 5 min      | Same as above                                   |
| `Sched_Market_Period_Begin`, `Pilot_Market_Period_Begin`, `Sched_Market_Period_End`, `Pilot_Market_Period_End` | Character (timestamp text) | -    | same that ´time´                                                                                  | 5 min      | Same as above                                   |
| `Sched_Optimization_Horizon`, `Pilot_Optimization_Horizon`                                                     | Character (timestamp text) | -    | same that ´time´                                                                                  | 5 min      | Same as above                                   |
| `Sched_Market_Aim`, `Pilot_Market_Aim`                                                                         | Character                  | -    | one of `"O"`, `"E"`, `"O+F"`, `"E+F"                                                              | 5 min      | Same as above                                   |



### Thermal state (Ti, Te)

| Column family | Type    | Unit | Range                                                                   | Resolution | `NA`?                                                         |
| ------------- | ------- | ---- | ----------------------------------------------------------------------- | ---------- | ------------------------------------------------------------- |
| `Ti_<suffix>` | Numeric | ºC   | indoor temperature; typically within the setpoint bands plus some drift | 5 min      | No, except row 1 which is seeded from `parameters$model$Ti_0` |
| `Te_<suffix>` | Numeric | ºC   | envelope temperature                                                    | 5 min      | No, except row 1 which is seeded from `parameters$model$Te_0` |

### Setpoints

18 columns: 

- `STP_heat_<suffix>`

- `STP_heat_high_<suffix>`

- `STP_heat_low_<suffix>`

- `STP_cool_<suffix>`

- `STP_cool_high_<suffix>`

- `STP_cool_low_<suffix>`

Each in ºC, Numeric, never `NA`, at 5-minute resolution. 

`STP_heat`/`STP_cool` are the setpoint defined after optimization

 `_high`/`_low` are that setpoint plus/minus half of the control hysteresis band.

### Comfort and activation

9 columns:

- Comfort_<suffix>`: Numeric, 0/1. 1 while `Ti` is inside the comfort band during occupancy, or whenever the building is unoccupied

- `Act_heat_<suffix>` and `Act_cool_<suffix>` : Numeric,  0/1, hysteresis-controlled heating/cooling activation (mutually exclusive, heating takes priority)

- 

All at 5-minute resolution, never `NA`.

### Energy per subsystem

15 columns:

- Thermal energy delivered:  `Q_heat_<suffix>`,  `Q_cool_<suffix>` 

- Electricity consumed, after the heat pump COP: , `Elec_heat_<suffix>`, `Elec_cool_<suffix>

- Toltal energy flow into the building: Elec_total_<suffix>` . Can be negative when there is a net export, though the current heat-pump-only model can not make it so.

All Numeric, in kWh (per 5-minute timestep, i.e. an energy quantity, not a power), never `NA`.

### Flexibility and economic signals

| Column                                                                                                                     | Type    | Unit                                                                                                    | Sign convention                                                                                                                                                         | Resolution                                | `NA`?           |
| -------------------------------------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- | --------------- |
| `Elec_total_no_flex`                                                                                                       | Numeric | kWh                                                                                                     | the energy that would have been used had a flexibility event not been executed. Today always equals `Elec_total_exec`, since flexibility execution is not simulated yet | 5 min                                     | No              |
| `Elec_flex_plan`                                                                                                           | Numeric | kWh                                                                                                     | `Elec_total_plan - Elec_total_plan_flex`; positive = down-flexibility (load reduced), negative = up-flexibility (load increased, never produced today)                  | 5 min                                     | No              |
| `Elec_purchase_cost_market`, `Elec_sell_revenue_market`, `Elec_flex_purchase_cost_market`, `Elec_flex_sell_revenue_market` | Numeric | €                                                                                                       | positive = income, negative = expense (see [Economic data structures](Economic_Data_Structures.md)); non-zero only on rows where a Scheduling or Piloting market clears | 5 min, but only non-zero on clearing rows | No, 0 elsewhere |
| `Elec_market_net_cost_h`, `Elec_deviations_net_cost_h`, `Elec_net_cost_h`                                                  | Numeric | €                                                                                                       | same sign convention; per-row net cash flow of, respectively, the market decisions covering this row, this row's execution deviation, and their sum                     | 5 min                                     | No              |
| `Elec_flex_commitment_revenue_h`, `Elec_flex_execution_revenue_h`, `Elec_flex_deviations_net_cost_h`                       | Numeric | €                                                                                                       | same sign convention; the last two are reserved for flexibility execution and are always 0 today (execution is not simulated)                                           | 5 min                                     | No              |
| `Elec_cost_distr_h`                                                                                                        | Numeric | €                                                                                                       | always <= 0 (distribution is only ever an expense)                                                                                                                      | 5 min                                     | No              |
| `Reward`                                                                                                                   | Numeric | - (the GA's own optimization units, a mix of € and the comfort penalty weighted by `Alpha_Service_Min`) | positive is better; not a pure currency value, see `reward_function.R`                                                                                                  | 5 min                                     | No              |

## Sinthetized_df_computed

One row per simulation: the whole year (or subset) collapsed into totals, meant for comparing different configurations against each other rather than for looking at any single timestep.

**Shape**: 1 row x (5 + 14) columns.

The first 5 columns come from `parameters$optimization` (`population_size`, `iteration_number`, `run_number`, `pcrossover`, `pmutation` - kept so parametric batches can be told apart by hyperparameter) and never change shape; the 14 result columns listed below are fixed regardless of configuration.

| Column                            | Type    | Unit                                                             | Sign convention                                                                                                    | `NA`? |
| --------------------------------- | ------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ----- |
| `Comfort`                         | Numeric | occupied 5-minute timesteps in comfort (a count, not a fraction) | higher is better                                                                                                   | No    |
| `Elec_total_in`, `Elec_total_out` | Numeric | kWh                                                              | non-negative magnitudes: energy imported and exported over the whole run                                           | No    |
| `Flex_plan_up`, `Flex_plan_down`  | Numeric | kWh                                                              | committed volumes; `Flex_plan_up` is always 0 today (only down-flexibility is offered)                             | No    |
| `Flex_exec_up`, `Flex_exec_down`  | Numeric | kWh                                                              | executed volumes; always 0 today (flexibility execution is not simulated)                                          | No    |
| `Elec_cost`                       | Numeric | €                                                                | positive number representing total money spent (already negated from the underlying signed convention, see header) | No    |
| `Elec_revenue`                    | Numeric | €                                                                | total money received                                                                                               | No    |
| `Flex_plan_revenue`               | Numeric | €                                                                | net cash flow of flexibility commitments (sold minus bought back)                                                  | No    |
| `Flex_exec_revenue`               | Numeric | €                                                                | always 0 today                                                                                                     | No    |
| `Distr_cost`                      | Numeric | €                                                                | always <= 0                                                                                                        | No    |
| `Reward`                          | Numeric | see `Main_df$Reward`                                             | higher is better                                                                                                   | No    |
| `Process_time`                    | Numeric | seconds                                                          | wall-clock time the simulation loop took                                                                           | No    |

`Elec_cost + Elec_revenue + Flex_plan_revenue + Distr_cost` is the year's whole energy-and-flexibility economic result, before comfort.

## Economic_analysis_market_computed and Economic_analysis_slot_computed

The exported form of the `economic_analysis$market` and `economic_analysis$slot` data frames. Both are documented in full, column by column, in [Economic data structures](Economic_Data_Structures.md#economic_analysismarket) - they are not repeated here to avoid the two pages drifting apart. In short: `Economic_analysis_market_computed` has one row per Scheduling market, per Piloting market, and per delivery slot at Execution (16 columns); `Economic_analysis_slot_computed` has one row per market slot of the whole simulation (15 columns). Both row counts follow the market configuration, exactly like `Main_df`'s market timeline columns above.

------------------------------------------------------------------------

[Back to README](../README.md)
