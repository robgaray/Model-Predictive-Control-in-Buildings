# Standalone Code

This page explains the standalone market script in `31_Standalone_code/`: what it does, how it does it, and how to call it from another program.

## Purpose

The simulation in `30_Simulation/` runs a whole year of markets in one go. It creates its own prices, its own flexibility events and its own weather forecast, and it simulates how the building really behaves between markets.

A building in real operation needs something different. Before each market closes, some program has to decide which energy and which flexibility the building will buy or sell in that market. It knows the current plan of the building, the weather forecast, the occupancy and the prices of the market, and nothing else.

The standalone script is that program. It optimizes one market per call. It reuses the processes of `30_Simulation`: the same building model, the same genetic algorithm over control modes, the same reward and the same flexibility itineraries. It leaves out everything that only exists to simulate a year.

The folder works on its own. It holds its own copy of the code and of the configuration it needs, so it can be copied out of the repository and used elsewhere.

## Market timing

A market is described by four instants, all in UTC and all at the start of a market interval:

| Instant | Meaning |
| --- | --- |
| `i0` | The moment the script is called: the closure of the market. |
| `i_begin_horizon` | The start of the period the market trades. |
| `i_end_control` | The end of the period the market commits. |
| `i_end_horizon` | The end of the period the script optimizes. |

They must satisfy `i0 <= i_begin_horizon < i_end_control <= i_end_horizon`.

The script optimizes the building over the whole stretch from `i_begin_horizon` to `i_end_horizon`, because a decision taken now has consequences later. It commits only the stretch from `i_begin_horizon` to `i_end_control`. The rest is valued to take a good decision, but it is left for later markets to commit, when they know more.

These names are the ones `30_Simulation/04_Scripts/14_simulation.R` uses for the same instants.

## Market intervals

Everything the script receives and returns is given per market interval. The length of an interval is `market_resolution` in `02_Config/03_Run_config.csv` (15 minutes by default). An interval is identified by the time it starts.

Inside, the script simulates the building on a finer time step, `main_resolution_sec` in `02_Config/00_Inner_parameters/01_computing_parameters.csv` (5 minutes by default). This finer step is never visible from outside.

Each kind of value is read in its own way:

- **Energy** (`Elec_total`, `Elec_flex_down`, `Elec_flex_up`, and every operation): the energy of the time steps that fall inside the interval, in kWh.
- **State** (`Ti`, `Te`): the value at the start of the interval, in degC.
- **Setpoints, occupancy and prices**: the value that applies during the interval.
- **Weather** (`Text`, `SolarR`): the value at the start of the interval. Between two interval starts, the script interpolates linearly.

## What one call does

A call goes through these steps:

1. **Configuration.** It reads and checks the configuration files of `02_Config` that describe the building, the control, the reward and the optimizer. Any invalid value stops the call. The libraries and the setup files of `00_Inner_parameters` are read by `initialize_standalone()` and `setup.R`.
2. **Inputs.** It checks the inputs:
   - the four instants are aligned and in order;
   - every vector has one value per interval, without gaps;
   - every value has the right type and range (`02_Config/00_Validation/Validation_Inputs.csv`).
3. **Working table.** It spreads the inputs over the fine time steps, from `i0` to `i_end_horizon`.
4. **Comfort bands.** It works out, from the occupancy, the comfort band the reward compares the indoor temperature with. Around occupied hours the band is anticipated by `Service_Anticipation_Begin` and `Service_Anticipation_End`, and narrowed according to the climate season. The plan is measured against the more restrictive of this band and the occupancy band, and the flexibility itineraries against the occupancy band inside their windows. Every time step outside its band is penalized, occupied or not.
5. **Baseline.** It fixes what every candidate solution is valued against:
   - the commitments already held, taken from the plan received;
   - the prices of the market;
   - the revenue discount.
6. **From `i0` to `i_begin_horizon`.** The building follows the plan it already has, because that part can no longer change. The script simulates that plan with its setpoints and projects the two flexibility itineraries over it: the windows committed from `i0` onwards are drawn as the new plan allows, without judging them and without changing any commitment. This gives the state of the building at `i_begin_horizon`, and the tail of any window that runs into the horizon, which the optimization continues over the plan of each candidate. The state of the heating and cooling systems is deduced from the indoor temperature and the setpoints, and their previous power is taken as 0.
7. **From `i_begin_horizon` to `i_end_horizon`.** It decides according to the aim of the market (see "Market aims").
8. **Result.** It writes the result over the committed stretch and turns it back into market intervals. It also computes the operations: the difference between what was committed before this market and what is committed after it.

## Market aims

The aim of a market says what the script may change. It uses the codes of `30_Simulation`:

| Aim | What the script does |
| --- | --- |
| `E` | Optimizes the mode of every interval to minimize the cost of energy while keeping comfort. |
| `E+F` | Same as `E`, and also sells flexibility (upward and downward) where it pays. |
| `O` | Keeps the setpoints of the plan received and recomputes its energy with the latest forecast. |
| `O+F` | Keeps the plan received as it is and only searches flexibility over it. |

With `O` and `O+F` nothing is optimized, so the plan received must carry every setpoint from `i_begin_horizon` to `i_end_horizon`.

Whatever the aim, the commitments of the committed stretch are kept inside `flexibility_commitment_margin`: the part the new plan no longer holds is bought back. With the `O` aim that is the only flexibility the script trades.

## Inputs

The input has four blocks. Every vector carries one value per market interval, from the interval that starts at `i0` to the last interval before `i_end_horizon`, together with its own `time` vector. Times are text in ISO 8601 UTC, for example `2024-01-15T12:00:00Z`. A missing value is `null` in JSON, `NA` in R and `None` in Python.

Some values are only used over part of the period, but every vector covers the whole period, so that all blocks share the same shape.

### market

| Name | Unit | Description |
| --- | --- | --- |
| `aim` | - | `E`, `E+F`, `O` or `O+F`. |
| `i0`, `i_begin_horizon`, `i_end_control`, `i_end_horizon` | UTC | See "Market timing". |
| `T_ext_24h` | degC | Mean outdoor temperature of the previous 24 hours. One value for the whole call. |
| `Overall_Climate` | - | `Heating`, `Cooling` or `Intermediate`. One value for the whole call. |
| `random_seed` | - | Optional. Seed of the genetic algorithm. 0 or absent: not fixed. |

### context

| Name | Unit | Description |
| --- | --- | --- |
| `time` | UTC | Start of each interval. |
| `Text` | degC | Outdoor temperature forecast. |
| `SolarR` | W/m2 | Solar radiation forecast. |
| `Occupancy` | 0/1 | Whether the building is occupied. |

### prices

The prices of this market. Past `i_end_control` the market does not publish prices, so these values are a forecast made by the caller.

| Name | Unit | Description |
| --- | --- | --- |
| `time` | UTC | Start of each interval. |
| `Elec_unit_cost_import_buy` | EUR/kWh | Price to buy energy. |
| `Elec_unit_cost_import_sell` | EUR/kWh | Price received when reselling energy bought before. |
| `Elec_unit_cost_export_buy` | EUR/kWh | Price to buy back energy sold before. |
| `Elec_unit_cost_export_sell` | EUR/kWh | Price received to sell energy. |
| `Elec_unit_cost_distribution` | EUR/kWh | Grid distribution cost of the energy moved. |
| `Flex_unit_cost_down_com_buy`, `Flex_unit_cost_down_com_sell` | EUR/kWh | Downward flexibility: commitment price, to buy back and to sell. |
| `Flex_unit_cost_down_exec_buy`, `Flex_unit_cost_down_exec_sell` | EUR/kWh | Downward flexibility: execution price, to buy back and to sell. |
| `Flex_unit_cost_up_com_buy`, `Flex_unit_cost_up_com_sell` | EUR/kWh | Upward flexibility: commitment price. |
| `Flex_unit_cost_up_exec_buy`, `Flex_unit_cost_up_exec_sell` | EUR/kWh | Upward flexibility: execution price. |
| `Flex_Probab_down`, `Flex_Probab_up` | 0-1 | Likelihood that the grid operator calls each service. |

### itineraries

An itinerary is a planned path of the building. There are three:

- `plan`: the base plan.
- `plan_flex_down`: the path if all the downward flexibility sold is called.
- `plan_flex_up`: the path if all the upward flexibility sold is called.

The input always carries the three, with the same format; a call without any of them stops with an error. The script rebuilds both flexibility itineraries from the plan and the commitments, so they only travel in the input to keep inputs and outputs symmetric.

| Name | Unit | Description |
| --- | --- | --- |
| `time` | UTC | Start of each interval. |
| `Ti`, `Te` | degC | Indoor and envelope temperature at the start of the interval. Only the value at `i0` is used. |
| `STP_heat`, `STP_heat_low`, `STP_heat_high` | degC | Heating setpoint and its hysteresis band. |
| `STP_cool`, `STP_cool_low`, `STP_cool_high` | degC | Cooling setpoint and its hysteresis band. |
| `Elec_total` | kWh | Net electricity of the interval. In `plan`, it is the energy already committed. |

The `plan` itinerary also carries the flexibility already sold:

| Name | Unit | Description |
| --- | --- | --- |
| `Elec_flex_down` | kWh | Downward flexibility already committed. |
| `Elec_flex_up` | kWh | Upward flexibility already committed. |

In the first call there is no previous plan. The input keeps the same format, with `null` everywhere except `Ti` and `Te` of `plan` at `i0`. The two flexibility itineraries are `null` throughout:
- setpoints missing between `i0` and `i_begin_horizon` take the default setpoints of `02_Config/02_Control.csv`;
- missing energies and commitments count as 0.

`Te`, the temperature of the building envelope, cannot be measured. The usual source is the plan returned by the previous call.

## Outputs

The output has two blocks.

### itineraries

The three itineraries, with the same variables as in the input, from the interval that starts at `i_begin_horizon` to the interval that starts at `i_end_control`.

The last interval, the one that starts at `i_end_control`, only carries the state (`Ti`, `Te`) reached at the end of the committed period. Its other values are missing. It is there so that the next market can start from that state.

With the `O+F` aim the `plan` itinerary is returned as it came, except `Ti` and `Te` at `i_begin_horizon`, which are simulated again from `i0`: only the flexibility itineraries and the commitments change.

### operations

The operations this market sends to the grid, one value per interval from `i_begin_horizon` to the last interval before `i_end_control`. Each one is a change from what was committed before this market to what is committed after it.

| Name | Unit | Description |
| --- | --- | --- |
| `time` | UTC | Start of each interval. |
| `Energy_bought` | kWh | New purchase. |
| `Energy_resold` | kWh | Resale of energy bought before. |
| `Energy_sold` | kWh | New sale. |
| `Energy_rebought` | kWh | Buy back of energy sold before. |
| `Flex_down_sold`, `Flex_down_rebought` | kWh | Downward flexibility sold and bought back. |
| `Flex_up_sold`, `Flex_up_rebought` | kWh | Upward flexibility sold and bought back. |

The cash flow of these operations is not returned, because the caller already has the prices.

## Chaining markets

The plan returned by one call is the plan the next call receives. To call the next market, the caller does this:

1. Takes the itineraries returned by the previous markets.
2. Builds from them the itineraries of the new call, from its own `i0` to its own `i_end_horizon`.
3. Adds the new weather forecast, the occupancy and the prices of the new market.

Where the previous markets did not reach, the plan is left missing.

The caller may also replace `Ti` at `i0` with a measured value before calling. The script does not tell the two cases apart.

`01_Input/example_chained_call.json` is built this way from the output of `01_Input/example_first_call.json`.

## How to call it

The script needs R with the packages listed in `02_Config/00_Inner_parameters/00_Libraries.txt` (`GA`, `doParallel`, `Rcpp` and `jsonlite`), and a C++ compiler for `Rcpp`. It was developed with R 4.5. `setup.R`, run once, installs the packages and, on Windows, the compiler.

A call with the example of a day-ahead market (168 intervals, aim `E+F`) takes about 80 seconds on a computer with 4 logical cores, with the 50 iterations of `01_Optimization_parameters.csv`. The genetic algorithm runs in parallel when `parallel` is 1 in `03_Run_config.csv`.

### Command line

```
Rscript 31_Standalone_code/call_script_console.R input.json output.json
Rscript 31_Standalone_code/call_script_console.R input.json output.json my_config_folder
```

The first argument is the input file and the second the output file. The optional third argument is a configuration folder to use instead of `02_Config`, with the same files. The command can be run from any folder.

If the call succeeds, the output file is written and the command ends with exit status 0. If anything fails, the reason is printed on the console, no output file is written, and the command ends with exit status 1.

The JSON files have the structure of the tables above:

```
{
  "market": {"aim": "E+F", "i0": "2024-01-15T12:00:00Z", ...},
  "context": {"time": ["2024-01-15T12:00:00Z", ...], "Text": [13.7, ...], ...},
  "prices": {"time": [...], "Elec_unit_cost_import_buy": [...], ...},
  "itineraries": {"plan": {"time": [...], "Ti": [20.5, null, ...], ...}, "plan_flex_down": {...}, "plan_flex_up": {...}}
}
```

Every array of the output is an array, even when it holds a single value.

### From R

```
source("31_Standalone_code/03_Functions/initialize_standalone.R")
paths  <- initialize_standalone("31_Standalone_code", NULL)
result <- optimize_market(inputs, paths)
```

`initialize_standalone()` is called once per R session. The second argument is the configuration folder, and `NULL` means `02_Config`.

`inputs` is a list with the four blocks. `result` is a list with `itineraries` (three data frames) and `operations` (a data frame). `call_script_from_R.R` runs a first market and then a chained one.

### From Python

There are two ways:

- **Through the command line.** `call_script_from_Python_subprocess.py` writes the input as JSON, runs `call_script_console.R` with `subprocess` and reads the output. It only needs the Python standard library. The environment variable `RSCRIPT` can give the path of `Rscript`.
- **In memory, with rpy2.** `call_script_from_Python_rpy2.py` starts R inside Python, turns a Python dictionary into an R list, calls `optimize_market()` and turns the result back with `format_market_output()`. rpy2 must use the R installation that has the packages, for instance through the `R_HOME` environment variable. With an R installed through conda, `LD_LIBRARY_PATH` may also need to point to the `lib` folder of that environment.

## Configuration

`02_Config/` holds the configuration of the building the script operates. Its values start as copies of those of `30_Simulation/02_Config/`, but they belong to the script and may diverge.

| File | Content |
| --- | --- |
| `01_Optimization_parameters.csv` | Genetic algorithm: population, iterations, runs, crossover, mutation. |
| `02_Control.csv` | Hysteresis deadband and default setpoints. |
| `03_Run_config.csv` | Market resolution and parallel workers. |
| `08_Flexibility_Event_Configuration.csv` | Phases, margins and limits of the flexibility windows. |
| `09_Reward_parameters.csv` | Weights of comfort and cost, comfort bands and revenue discount. |
| `10_Operational_temperature_corrections.csv` | Anticipation of the comfort band and seasonal corrections. |
| `11_Model_parameters.csv` | Building and heat pump model. |
| `13_Modes_setpoints.csv` | The control modes and their setpoints. |
| `00_Inner_parameters/` | Libraries, internal time step and tolerance, air properties, and the download sources of `setup.R`. |
| `00_Validation/` | Validation rules of the configuration and of the inputs. |

The control is always mode-based. The setpoint-based control of `30_Simulation` is not part of the script.

## Folder structure

| Path | Content |
| --- | --- |
| `call_script_console.R` | Command line entry point. |
| `setup.R` | Installs, once, what the script needs. |
| `call_script_from_R.R`, `call_script_from_Python_subprocess.py`, `call_script_from_Python_rpy2.py` | Examples of calls from R and from Python. |
| `01_Input/` | Example inputs: a first call and a chained call. |
| `02_Config/` | Configuration. |
| `03_Functions/` | The functions of the script. `optimize_market()` is the main one. |
| `03_1_Functions_Cpp/` | The C++ simulation loop of the building. |
| `90_Output/` | The outputs of the example inputs. |

## Differences from 30_Simulation

The script follows the processes of `30_Simulation`, with these deliberate differences:

- **Inputs from the caller.** Weather, prices and flexibility signals come from the caller. The script does not forecast or emulate them.
- **State at `i0`.** It is the state of the plan received. The heating and cooling state is deduced from the indoor temperature and the setpoints, and the previous power is 0.
- **Energy per interval.** It is the energy of the time steps inside the interval. `30_Simulation` groups its rows one step later.
- **`T_ext_24h` and `Overall_Climate`.** Each is a single value for the whole call.
- **Daytime ventilation.** It runs while the building is occupied, as in `30_Simulation`: the C++ core takes it from `Occupancy`.

A comparison of both codes on the same markets is reported in `03_Agent_Reports/20261001_Standalone_Code_Fidelity.md`. With the same plan, both give the same indoor temperature and the same energy per interval.

## Known limitations

- The script only sees the occupancy up to `i_end_horizon`. If the occupancy of a day starts after `i_end_horizon`, the anticipated comfort band before it is not applied, even when that anticipation falls inside the horizon.
- When a plan that comes from another call is recomputed with the `O` aim, its energy may change slightly, because the state of the heating and cooling systems and their previous power are not passed between calls.

------------------------------------------------------------------------

[Back to README](../README.md)
