# Input and Output Files

This page explains the input and output data of a simulation run.

This page does not cover parameter files. They are explained in [section 13 of the README](../README.md#13-parametrization-and-graphic-user-interface) and in `90_Structure/Parameter_Units.csv`.

## Location in the repository

- Inputs are read from `30_Simulation/01_Data/`.
- Outputs are written to `30_Simulation/90_Output/`.

## General content and purpose

Two files come in:

- `Meteo_df`: weather.
- `Energy_Prices_df`: electricity and flexibility prices.

They are read once, at the very start of a run, and merged into `Main_df`.

The two files can have a different time step from each other and from `Main_df`. So each one is first checked for a consistent, evenly spaced time step. Then both are placed on `Main_df`'s own time grid, which has one row every `main_resolution_sec` seconds (300 s, that is 5 minutes, in `30_Simulation/02_Config/00_Inner_parameters/01_computing_parameters.csv`). The weather is interpolated between its hourly values. The prices are held constant over each of their 15-minute steps, because a price applies to the whole interval it was quoted for.

Four tables come out, all written once the simulation loop has finished. Each one is written twice, as a `.csv` file and as an `.rds` file with the same content:

- `Main_df_computed`: the complete simulation, one row per timestep, with every physical and economic quantity the model computed. It holds many more columns than the two input files.
- `Sinthetized_df_computed`: a one-row summary of the simulation, with the totals of the whole simulated period (comfort, energy, cost, revenue, reward). It is useful for comparing different simulation runs side by side, for example the runs of a parametric batch.
- `Economic_analysis_market_computed` and `Economic_analysis_slot_computed`: the per-market and per-slot economic breakdown described in [Economic data structures](Economic_Data_Structures.md). They are the exported form of the `economic_analysis` object.

The number of rows of every output depends on the simulated period. The period is set by `month_subset` and `period_subset` in `30_Simulation/02_Config/16_Debug_and_config.csv`:

- `month_subset = 0` keeps the whole year. Any value from 1 to 12 keeps only that month.
- `period_subset = 0` keeps every remaining row. Any other value keeps only that many rows, counted from the start.

The configuration shipped with the repository sets `month_subset = 1` and `period_subset = 1000`, so it simulates the first 1,000 rows of January (about three and a half days). The row counts given below are those of a full-year run (`month_subset = 0`, `period_subset = 0`). The columns are the same whatever the period.

------------------------------------------------------------------------

# Inputs

## Meteo_df

Hourly weather data for the whole year. Read from `30_Simulation/01_Data/Meteo_df.rds`. The same data is also kept as `Meteo_df.csv` in that folder, for reading outside R; the simulation does not read the `.csv` copy.

**Shape**: 8,784 rows x 3 columns. That is 366 days at 1-hour resolution, because 2024 is a leap year. A non-leap year would give 8,760 rows.

| Column   | Type                | Unit | Range in the shipped file                            | Temporal resolution   | Can it be `NA`? |
| -------- | ------------------- | ---- | ---------------------------------------------------- | --------------------- | --------------- |
| `time`   | POSIXct (date-time) | -    | 2024-01-01 00:00 to 2024-12-31 23:00 (UTC)           | 1 hour, evenly spaced | No              |
| `Text`   | Numeric             | ºC   | -2.6 to 41.7 (depends on the site)                   | 1 hour                | No              |
| `SolarR` | Numeric             | W/m² | 0 to 919 (0 at night, up to full daytime irradiance) | 1 hour                | No              |

## Energy_Prices_df

Electricity and flexibility unit prices for the whole year. Read from `30_Simulation/01_Data/Energy_Prices_df.rds`. The same data is also kept as `Energy_Prices_df.csv` in that folder, for reading outside R; the simulation does not read the `.csv` copy.

**Shape**: 35,132 rows x 9 columns. That is 15-minute resolution from 2024-01-01 00:00 to 2024-12-31 22:45 (UTC).

The row count follows the market resolution the price series was generated at. `Energy_Prices_df` is held constant over each step onto the simulation's own time grid, whatever its resolution.

The price file ends 15 minutes before the weather file. When the two files do not end at the same instant, the longer one is cut to the end of the shorter one, and a warning says how many rows were dropped.

| Column                        | Type                | Unit  | Range in the shipped file                              | Temporal resolution       | Can it be `NA`? |
| ----------------------------- | ------------------- | ----- | ------------------------------------------------------ | ------------------------- | --------------- |
| `time`                        | POSIXct (date-time) | -     | 2024-01-01 00:00 to 2024-12-31 22:45 (UTC)             | 15 minutes, evenly spaced | No              |
| `Elec_unit_cost_buy`          | Numeric             | €/kWh | -0.0019 to 0.196; mostly positive, can go slightly negative | 15 minutes           | No              |
| `Elec_unit_cost_distribution` | Numeric             | €/kWh | 0 to 0.0031; never negative                            | 15 minutes                | No              |
| `Flex_unit_cost_down_com`     | Numeric             | €/kWh | -0.00001 to 0.069; can go slightly negative            | 15 minutes                | No              |
| `Flex_unit_cost_down_exec`    | Numeric             | €/kWh | -0.0031 to 0.026; can go slightly negative             | 15 minutes                | No              |
| `Flex_unit_cost_up_com`       | Numeric             | €/kWh | always 0 in the shipped file                           | 15 minutes                | No              |
| `Flex_unit_cost_up_exec`      | Numeric             | €/kWh | -0.0031 to 0.026; can go slightly negative             | 15 minutes                | No              |
| `Flex_Probab_down`            | Numeric (fraction)  | -     | 0 to 1; always 0 in the shipped file                   | 15 minutes                | No              |
| `Flex_Probab_up`              | Numeric (fraction)  | -     | 0 to 1; always 0 in the shipped file                   | 15 minutes                | No              |

Notes on the file shipped with the repository:

- `Flex_unit_cost_up_com`, `Flex_Probab_down` and `Flex_Probab_up` are always 0. This is a property of this particular dataset, not a rule.
- `Flex_Probab_down` and `Flex_Probab_up` are the activation probabilities of each flexibility leg. They are independent signals: an interval can be very likely to be called for a load reduction and unlikely to be called for a load increase, or the other way round. In the shipped file the two are identical, because `Flex_Probab_up` was created by copying `Flex_Probab_down`.

With the shipped configuration, `Price_emulation = 1` in `16_Debug_and_config.csv`. In that case `09_flexibility_price_emulation.R` overwrites the four `Flex_unit_cost_*` columns and the two `Flex_Probab_*` columns of `Main_df` with generated values before the simulation starts. The values read from the file are then not used. With `Price_emulation = 0`, the values of the file are used as they are.

The simulation loop does not read these price columns directly. First, `10_energy_price_signals_setup.R` derives twelve buy/sell price signals from them (see "Price signals" under `Main_df_computed` below). The rest of the simulation reads those twelve signals, together with the two `Flex_Probab_*` columns and `Elec_unit_cost_distribution`. See the header of `10_energy_price_signals_setup.R` for the exact formulas.

------------------------------------------------------------------------

# Outputs

## Main_df_computed

The complete simulation result: every physical and economic quantity the model computed, one row per timestep. This is `Main_df` itself, exported unchanged at the end of the run by `16_data_outputs.R`. It is the largest and most detailed output file, and every other output is derived from it.

**Shape**:

- One row per timestep of the simulated period. A full year of the shipped data gives 105,394 rows: 5-minute steps from 2024-01-01 00:00 to 2024-12-31 22:45, where the price file ends. The shipped configuration gives 1,000 rows (see "General content and purpose" above).
- 128 columns. They are the columns listed in `30_Simulation/02_Config/00_Inner_parameters/02_Needed_cols.csv`, which the simulation guarantees to have by the time it starts. No new column is created while the simulation runs.

### Context suffixes

Most physical columns exist in four versions, one per "context":

- `_exec`: what actually happened, computed with the real weather, not the forecast. This is the row's ground truth.
- `_plan`: what was committed in the last market decision (Scheduling or Piloting) that covers this row. It is computed with the weather forecast available when that decision was made.
- `_plan_flex_down`: the same commitment, with a candidate downward flexibility event applied on top. The load is reduced during the event.
- `_plan_flex_up`: the same commitment, with a candidate upward flexibility event applied instead. The load is increased during the event.

A new flexibility event is only searched when the market that made the decision has a flexibility aim, `"E+F"` or `"O+F"`. The aim of each market is set in its row of `04_Market_config_scheduling.csv` or `05_Market_config_piloting.csv`. Otherwise the two flexibility itineraries only carry the flexibility already committed by earlier markets, and mirror `_plan` everywhere else.

The two flexibility itineraries are independent of each other. A market interval can carry a downward commitment and an upward one at the same time, because each lives in its own set of columns.

### Time and weather

| Column            | Type      | Unit | Range                                                                    | Resolution | `NA`? |
| ----------------- | --------- | ---- | ------------------------------------------------------------------------ | ---------- | ----- |
| `time`            | POSIXct   | -    | simulated period                                                         | 5 min      | No    |
| `Text`            | Numeric   | ºC   | see `Meteo_df`                                                           | 5 min      | No    |
| `SolarR`          | Numeric   | W/m² | see `Meteo_df`                                                           | 5 min      | No    |
| `T_ext_24h`       | Numeric   | ºC   | average `Text` of the previous day; similar to `Text`                    | 5 min      | No    |
| `Text_forec`      | Numeric   | ºC   | forecast of `Text`; similar to `Text`                                    | 5 min      | No    |
| `SolarR_forec`    | Numeric   | W/m² | forecast of `SolarR`; similar to `SolarR`                                | 5 min      | No    |
| `Overall_Climate` | Character | -    | one of `"Heating"`, `"Cooling"`, `"Intermediate"` (`03_climate_priority.R`) | 5 min      | No    |

### Price signals

8 columns copied in from `Energy_Prices_df`, or generated when `Price_emulation = 1` (see `Energy_Prices_df` above):

- `Elec_unit_cost_buy`
- `Elec_unit_cost_distribution`
- `Flex_unit_cost_down_com`
- `Flex_unit_cost_down_exec`
- `Flex_unit_cost_up_com`
- `Flex_unit_cost_up_exec`
- `Flex_Probab_down`
- `Flex_Probab_up`

A column generated locally:

- `Flex_Act`: 1 on every row covered by a generated flexibility event, 0 elsewhere.

12 buy/sell signals derived from them, all Numeric, in €/kWh, never `NA`:

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

These are the prices that every market decision and every economic calculation uses. See [Economic data structures](Economic_Data_Structures.md) for how.

### Occupancy, scheduling and comfort bands

| Column                                  | Type    | Unit | Range                                   | Resolution | `NA`? |
| --------------------------------------- | ------- | ---- | --------------------------------------- | ---------- | ----- |
| `Occupancy`                             | Integer | -    | 0/1                                     | 5 min      | No    |
| `Scheduling`                            | Integer | -    | 0/1                                     | 5 min      | No    |
| `Service_T_Low`, `Service_T_High`       | Numeric | ºC   | temperature range, narrower than 0-50ºC | 5 min      | No    |
| `Scheduling_T_Low`, `Scheduling_T_High` | Numeric | ºC   | temperature range, narrower than 0-50ºC | 5 min      | No    |

### Market timeline

On each row, these columns describe the Scheduling market (`Sched_`) and the Piloting market (`Pilot_`) that clear at that instant, if any.

| Column                                                                                                         | Type                       | Unit | Range                                                                                             | Resolution | `NA`?                                             |
| -------------------------------------------------------------------------------------------------------------- | -------------------------- | ---- | ------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------- |
| `MarketUTC`                                                                                                    | POSIXct                    | -    | start of the market interval the row belongs to                                                   | 5 min      | No                                                |
| `Sched_Market_Name`, `Pilot_Market_Name`                                                                       | Character                  | -    | market code (e.g. `"DA"`, `"ID1"`, `"cID2"`) on the row where that market clears, `"0"` elsewhere | 5 min      | Never `NA`; `"0"` is the "no market here" value   |
| `Sched_Market_Bid_time`, `Pilot_Market_Bid_time`                                                               | Character (timestamp text) | -    | same range as `time`                                                                              | 5 min      | Same as above                                     |
| `Sched_Market_Period_Begin`, `Pilot_Market_Period_Begin`, `Sched_Market_Period_End`, `Pilot_Market_Period_End` | Character (timestamp text) | -    | same range as `time`                                                                              | 5 min      | Same as above                                     |
| `Sched_Optimization_Horizon`, `Pilot_Optimization_Horizon`                                                     | Character (timestamp text) | -    | same range as `time`                                                                              | 5 min      | Same as above                                     |
| `Sched_Market_Aim`, `Pilot_Market_Aim`                                                                         | Character                  | -    | one of `"O"`, `"E"`, `"O+F"`, `"E+F"`                                                             | 5 min      | Same as above                                     |

### Thermal state

| Column family | Type    | Unit | Range                                                                   | Resolution | `NA`?                                                   |
| ------------- | ------- | ---- | ----------------------------------------------------------------------- | ---------- | ------------------------------------------------------- |
| `Ti_<suffix>` | Numeric | ºC   | indoor temperature; typically within the setpoint bands plus some drift | 5 min      | No; row 1 is seeded from `Ti_0` in `11_Model_parameters.csv` |
| `Te_<suffix>` | Numeric | ºC   | envelope temperature                                                    | 5 min      | No; row 1 is seeded from `Te_0` in `11_Model_parameters.csv` |

### Setpoints

24 columns, one per context of each of these:

- `STP_heat_<suffix>`
- `STP_heat_high_<suffix>`
- `STP_heat_low_<suffix>`
- `STP_cool_<suffix>`
- `STP_cool_high_<suffix>`
- `STP_cool_low_<suffix>`

Each is in ºC, Numeric, never `NA`, at 5-minute resolution.

`STP_heat` and `STP_cool` are the setpoints chosen by the optimization.

The `_high` and `_low` columns are that setpoint plus and minus half of the control hysteresis band (`Deadband`).

### Comfort and activation

12 columns, one per context of each of these:

- `Comfort_<suffix>`: Numeric, 0/1. It is 1 while `Ti` is inside the comfort band during occupancy, and always 1 while the building is unoccupied.
- `Act_heat_<suffix>` and `Act_cool_<suffix>`: Numeric, 0/1. Heating and cooling activation, controlled with hysteresis. They are never both 1 on the same row; heating takes priority.

All are at 5-minute resolution and never `NA`.

### Energy per subsystem

20 columns, one per context of each of these:

- Thermal energy delivered: `Q_heat_<suffix>` and `Q_cool_<suffix>`.
- Electricity consumed, after the heat pump COP: `Elec_heat_<suffix>` and `Elec_cool_<suffix>`.
- Total electricity flow into the building: `Elec_total_<suffix>`. It would be negative during a net export, but the current model, with a heat pump only, never exports.

All are Numeric, in kWh per timestep (an energy quantity, not a power), and never `NA`.

### Flexibility and economic signals

Every money column follows the same sign convention: positive is income to the building, negative is an expense. See [Economic data structures](Economic_Data_Structures.md).

| Column                                                                                                                     | Type    | Unit                                                                                                                                  | Meaning                                                                                                                                                                                  | Resolution                                | `NA`?           |
| -------------------------------------------------------------------------------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------- | --------------- |
| `Elec_total_no_flex`                                                                                                       | Numeric | kWh                                                                                                                                   | the energy that would have been used had no flexibility event been executed. Today it always equals `Elec_total_exec`, because flexibility execution is not simulated yet               | 5 min                                     | No              |
| `Flex_phase_down_plan`                                                                                                     | Integer | - (code)                                                                                                                              | phase of the downward flexibility window on this row: 0 outside, 1 Commitment, 2 Neutral, 3 Recovery                                                                                     | 5 min                                     | No              |
| `Flex_phase_up_plan`                                                                                                       | Integer | - (code)                                                                                                                              | the same, for the upward window                                                                                                                                                          | 5 min                                     | No              |
| `Elec_flex_down_plan`                                                                                                      | Numeric | kWh                                                                                                                                   | `Elec_total_plan - Elec_total_plan_flex_down` over the Commitment Phase (phase 1), 0 elsewhere. It is the load committed to be shed, and it is never negative                             | 5 min                                     | No              |
| `Elec_flex_up_plan`                                                                                                        | Numeric | kWh                                                                                                                                   | `Elec_total_plan_flex_up - Elec_total_plan` over the Commitment Phase (phase 1), 0 elsewhere. It is the load committed to be added, and it is never negative                              | 5 min                                     | No              |
| `Elec_purchase_cost_market`, `Elec_sell_revenue_market`, `Elec_flex_purchase_cost_market`, `Elec_flex_sell_revenue_market` | Numeric | €                                                                                                                                     | lump sums of the market decision taken on this row. Only non-zero on rows where a Scheduling or Piloting market clears                                                                   | 5 min, but only non-zero on clearing rows | No, 0 elsewhere |
| `Elec_market_net_cost_h`, `Elec_deviations_net_cost_h`, `Elec_net_cost_h`                                                  | Numeric | €                                                                                                                                     | per-row net cash flow of, respectively, the market decisions covering this row, this row's execution deviation, and the sum of both                                                     | 5 min                                     | No              |
| `Elec_flex_commitment_revenue_h`                                                                                           | Numeric | €                                                                                                                                     | per-row net cash flow of the flexibility commitments covering this row                                                                                                                   | 5 min                                     | No              |
| `Elec_flex_execution_revenue_h`, `Elec_flex_deviations_net_cost_h`                                                         | Numeric | €                                                                                                                                     | reserved for flexibility execution; always 0 today, because execution is not simulated                                                                                                   | 5 min                                     | No              |
| `Elec_cost_distr_h`                                                                                                        | Numeric | €                                                                                                                                     | never positive, because distribution is only ever an expense                                                                                                                             | 5 min                                     | No              |
| `Reward`                                                                                                                   | Numeric | - (dimensionless: `alpha_comfort`, in 1/h, weights the comfort penalty in hours; `alpha_cost`, in 1/€, weights the economic terms in €) | higher is better; not a currency value, see `reward_function.R`                                                                                                                          | 5 min                                     | No              |

## Sinthetized_df_computed

One row per simulation. The whole simulated period is collapsed into totals. It is meant for comparing different configurations with each other, not for looking at any single timestep.

**Shape**: 1 row x 19 columns (5 + 14).

The first 5 columns are the genetic algorithm settings of `parameters$optimization`, read from `01_Optimization_parameters.csv`:

- `population_size`
- `iteration_number`
- `run_number`
- `pcrossover`
- `pmutation`

They are kept so that the runs of a parametric batch can be told apart. The 14 result columns below are fixed, whatever the configuration.

| Column                            | Type    | Unit                                                             | Meaning                                                                                                                                  | `NA`? |
| --------------------------------- | ------- | ---------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| `Comfort`                         | Numeric | occupied timesteps in comfort (a count, not a fraction)          | higher is better                                                                                                                         | No    |
| `Elec_total_in`, `Elec_total_out` | Numeric | kWh                                                              | energy imported and exported over the whole run; never negative                                                                          | No    |
| `Flex_plan_up`, `Flex_plan_down`  | Numeric | kWh                                                              | flexibility volume committed on each leg: the sums of `Elec_flex_up_plan` and `Elec_flex_down_plan`                                      | No    |
| `Flex_exec_up`, `Flex_exec_down`  | Numeric | kWh                                                              | flexibility volume executed on each leg; always 0 today, because flexibility execution is not simulated                                  | No    |
| `Elec_cost`                       | Numeric | €                                                                | net money spent buying energy, with every resale subtracted. It follows the sign convention, so it is negative when money is spent       | No    |
| `Elec_revenue`                    | Numeric | €                                                                | net money received selling energy, with every rebuy subtracted                                                                           | No    |
| `Flex_plan_revenue`               | Numeric | €                                                                | net cash flow of flexibility commitments (sold minus bought back)                                                                        | No    |
| `Flex_exec_revenue`               | Numeric | €                                                                | always 0 today, for the same reason as `Flex_exec_up` and `Flex_exec_down`                                                               | No    |
| `Distr_cost`                      | Numeric | €                                                                | never positive                                                                                                                           | No    |
| `Reward`                          | Numeric | see `Main_df$Reward`                                             | sum of `Main_df$Reward`; higher is better                                                                                                | No    |
| `Process_time`                    | Numeric | seconds                                                          | time the simulation loop took                                                                                                            | No    |

All the money columns follow the same sign convention as `Main_df`: positive is income, negative is an expense. So `Elec_cost + Elec_revenue + Flex_plan_revenue + Distr_cost` is the economic result of the whole simulated period for energy and flexibility, before comfort.

## Economic_analysis_market_computed and Economic_analysis_slot_computed

These are the exported form of the `economic_analysis$market` and `economic_analysis$slot` data frames. Both are documented in full, column by column, in [Economic data structures](Economic_Data_Structures.md#economic_analysismarket). They are not repeated here, so that the two pages cannot drift apart. In short:

- `Economic_analysis_market_computed` has 16 columns and one row for each Scheduling market, each Piloting market, and each delivery slot at Execution.
- `Economic_analysis_slot_computed` has 16 columns and one row for each market slot of the whole simulation.

Both row counts depend on the market configuration and on the simulated period, like `Main_df`'s market timeline columns above.

------------------------------------------------------------------------

[Back to README](../README.md)
