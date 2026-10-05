# Standalone market script

This repository performs a full simulation of the model-predictive control across many markets. This folder complements it with a standalone script that allows third parties to run the optimizer on their own.

The script optimizes the energy and flexibility commitments of a building for one market. It returns the new plan of the building and the operations to send to the market.

It is meant to be called once per market, with the previous commitments, the state of the building and the most recent forecasts.

The code is mostly written in R and is run with Rscript, but it is meant to be called by other tools, in R or in any other language.

The folder works on its own: it holds all the code and configuration it needs, and can be copied out of the repository.

## Requirements

- R. The script was developed with R 4.5 and also works with R 4.6. Nothing else needs to be installed by hand: `setup.R` installs the rest.
- For the in-memory Python example only: the Python package `rpy2`.

## Setup

`setup.R` prepares a computer that only has R. Run it once, before the first call:

```bash
Rscript 31_Standalone_code/setup.R
```

It does three things:

1. It installs the R packages listed in `02_Config/00_Inner_parameters/00_Libraries.txt` (`GA`, `doParallel`, `Rcpp` and `jsonlite`), with the packages they depend on. If the user cannot write in the R library folder, it uses the personal library folder of the user.
2. It checks that R can compile C++, because the script compiles the simulation loop of the building every time it starts.
3. On Windows, if no C++ file can be compiled, it downloads and installs Rtools, the compiler R uses on Windows. Windows may ask for permission. On macOS and Linux a compiler needs administrator rights, so the script only says how to install it: `xcode-select --install` on macOS, and `build-essential` (Debian, Ubuntu) or `gcc-c++ make` (Fedora) on Linux.

Running it again does no harm: it only installs what is missing. It ends with exit status 0 when everything is ready and 1 otherwise. Where it downloads from is set in `02_Config/00_Inner_parameters/02_Setup_parameters.csv`, and the Rtools release of each R version in `02_Config/00_Inner_parameters/04_Rtools_versions.csv`.

The three call examples below run `setup.R` before their first call.

## Quick start

From the folder that contains `31_Standalone_code`:

```bash
Rscript 31_Standalone_code/call_script_console.R 31_Standalone_code/01_Input/example_first_call.json output.json
```

The input describes a day-ahead market: called at 12:00 on 15 January 2024, it commits the 16th and optimizes until 06:00 on the 17th. The output holds the plan of the building and the energy and flexibility to buy and sell, per 15-minute interval.

## How to call it

| Script | Language | How it calls the market script |
| --- | --- | --- |
| `call_script_console.R` | Any | It is the market script itself, run from the console: `Rscript call_script_console.R input.json output.json [config_folder]`. |
| `call_script_from_R.R` | R | Runs `setup.R`, then calls `call_script_console.R` with JSON files, and then calls `optimize_market()` directly in memory, for a first market and a chained one. |
| `call_script_from_Python_subprocess.py` | Python | Finds Rscript, runs `setup.R`, writes the input as JSON, runs `call_script_console.R` with `subprocess` and reads the output. It only needs the Python standard library. |
| `call_script_from_Python_rpy2.py` | Python | Runs `setup.R`, starts R inside Python with `rpy2`, calls `optimize_market()` with a Python dictionary and turns the result back into a dictionary. |

### From the console

`call_script_console.R` takes the path of the input file, the path of the output file and, optionally, a configuration folder to use instead of `02_Config` with the same files. It can be run from any folder.

If the call succeeds, the output file is written and the command ends with exit status 0. If anything fails, the reason is printed on the console, no output file is written, and the command ends with exit status 1.

### From R

```r
source("31_Standalone_code/03_Functions/initialize_standalone.R")
paths  <- initialize_standalone("31_Standalone_code", NULL)
result <- optimize_market(inputs, paths)
```

`initialize_standalone()` is called once per R session. Its second argument is the configuration folder, and `NULL` means `02_Config`. `inputs` is a list with the same blocks as the input JSON file. `result` is a list with `itineraries` (three data frames) and `operations` (a data frame).

### From Python

`call_script_from_Python_subprocess.py` looks for Rscript in the environment variable `RSCRIPT`, then in the `PATH` and, on Windows, in the usual installation folders of R.

`call_script_from_Python_rpy2.py` uses the R installation that `rpy2` finds, or the one given by the `R_HOME` environment variable. With an R installed through conda, `LD_LIBRARY_PATH` may also need to point to the `lib` folder of that environment.

## Market timing

A market is described by four instants, all in UTC and all at the start of a market interval:

| Instant | Meaning |
| --- | --- |
| `i0` | The moment the script is called: the closure of the market. |
| `i_begin_horizon` | The start of the period the market trades. |
| `i_end_control` | The end of the period the market commits. |
| `i_end_horizon` | The end of the period the script optimizes. |

They must satisfy `i0 <= i_begin_horizon < i_end_control <= i_end_horizon`.

The script optimizes the building from `i_begin_horizon` to `i_end_horizon`, because a decision taken now has consequences later. It only commits the stretch from `i_begin_horizon` to `i_end_control`. Between `i0` and `i_begin_horizon` the building follows the plan it already has, because that part can no longer change: there the flexibility itineraries are only projected over the plan, and no commitment is changed.

Everything the script receives and returns is given per market interval. An interval lasts `market_resolution` minutes (`02_Config/03_Run_config.csv`, 15 minutes by default) and is identified by the time it starts. The values of an interval are read this way:

- **Energy**: the energy of the whole interval, in kWh.
- **Temperatures of the building** (`Ti`, `Te`): the value at the start of the interval.
- **Setpoints, occupancy and prices**: the value that applies during the interval.
- **Weather** (`Text`, `SolarR`): the value at the start of the interval. Between two interval starts, the script interpolates linearly.

## Input file

The input is a JSON object with four blocks: `market`, `context`, `prices` and `itineraries`.

Every vector carries one value per market interval, from the interval that starts at `i0` to the last interval before `i_end_horizon`, without gaps. Each block carries its own `time` vector with the start of each interval. Times are text in ISO 8601 UTC, for example `2024-01-15T12:00:00Z`. A missing value is `null` in JSON, `NA` in R and `None` in Python.

The type and range of every value are checked against `02_Config/00_Validation/Validation_Inputs.csv`. A value out of range stops the call or prints a warning, as that file says.

```
{
  "market":      {"aim": "E+F", "i0": "2024-01-15T12:00:00Z", ...},
  "context":     {"time": ["2024-01-15T12:00:00Z", ...], "Text": [13.7, ...], ...},
  "prices":      {"time": [...], "Elec_unit_cost_import_buy": [...], ...},
  "itineraries": {"plan": {...}, "plan_flex_down": {...}, "plan_flex_up": {...}}
}
```

### market

Single values that describe the market and the call.

| Variable | Type | Unit | Description |
| --- | --- | --- | --- |
| `aim` | Text | - | What the script may change: `E`, `E+F`, `O` or `O+F` (see "Market aims"). |
| `i0` | Time | UTC | The moment the script is called. |
| `i_begin_horizon` | Time | UTC | Start of the period the market trades. |
| `i_end_control` | Time | UTC | End of the period the market commits. |
| `i_end_horizon` | Time | UTC | End of the period the script optimizes. |
| `T_ext_24h` | Number | degC | Mean outdoor temperature of the previous 24 hours. One value for the whole call. It decides when shading and reinforced ventilation are used. |
| `Overall_Climate` | Text | - | Climate season: `Heating`, `Cooling` or `Intermediate`. One value for the whole call. It decides which side of the comfort band is narrowed inside the scheduling window around occupancy. |
| `random_seed` | Integer | - | Optional. Seed of the genetic algorithm, so that a call can be repeated with the same result. 0 or absent: not fixed. |

### context

The forecast of the building's surroundings, one value per interval.

| Variable | Type | Unit | Description |
| --- | --- | --- | --- |
| `time` | Time | UTC | Start of each interval. |
| `Text` | Number | degC | Outdoor air temperature forecast, at the start of the interval. |
| `SolarR` | Number | W/m2 | Solar radiation forecast, at the start of the interval. |
| `Occupancy` | Integer | 0/1 | 1 if the building is occupied during the interval. It sets the comfort band, and the daytime ventilation runs while it is 1. |

### prices

The prices of this market, one value per interval. Past `i_end_control` the market publishes no prices, so these values are a forecast made by the caller.

| Variable | Type | Unit | Description |
| --- | --- | --- | --- |
| `time` | Time | UTC | Start of each interval. |
| `Elec_unit_cost_import_buy` | Number | EUR/kWh | Price to buy energy. |
| `Elec_unit_cost_import_sell` | Number | EUR/kWh | Price received when reselling energy bought before. |
| `Elec_unit_cost_export_buy` | Number | EUR/kWh | Price paid when buying back energy sold before. |
| `Elec_unit_cost_export_sell` | Number | EUR/kWh | Price received when selling energy. |
| `Elec_unit_cost_distribution` | Number | EUR/kWh | Grid distribution cost of the energy moved. |
| `Flex_unit_cost_down_com_buy` | Number | EUR/kWh | Downward flexibility, commitment: price paid to buy back a commitment sold before. |
| `Flex_unit_cost_down_com_sell` | Number | EUR/kWh | Downward flexibility, commitment: price received to sell it. |
| `Flex_unit_cost_down_exec_buy` | Number | EUR/kWh | Downward flexibility, execution: price paid to buy back. |
| `Flex_unit_cost_down_exec_sell` | Number | EUR/kWh | Downward flexibility, execution: price received when it is called. |
| `Flex_unit_cost_up_com_buy` | Number | EUR/kWh | Upward flexibility, commitment: price paid to buy back a commitment sold before. |
| `Flex_unit_cost_up_com_sell` | Number | EUR/kWh | Upward flexibility, commitment: price received to sell it. |
| `Flex_unit_cost_up_exec_buy` | Number | EUR/kWh | Upward flexibility, execution: price paid to buy back. |
| `Flex_unit_cost_up_exec_sell` | Number | EUR/kWh | Upward flexibility, execution: price received when it is called. |
| `Flex_Probab_down` | Number | 0-1 | Likelihood that the grid operator calls the downward flexibility. |
| `Flex_Probab_up` | Number | 0-1 | Likelihood that the grid operator calls the upward flexibility. |

Downward flexibility is a reduction of the electricity the building uses, and upward flexibility an increase.

### itineraries

An itinerary is a planned path of the building. The input always carries the three of them, with the same format; a call without any of them stops with an error:

- `plan`: the base plan, the one the building follows.
- `plan_flex_down`: the path if all the downward flexibility sold is called.
- `plan_flex_up`: the path if all the upward flexibility sold is called.

Every itinerary carries these variables, one value per interval:

| Variable | Type | Unit | Description |
| --- | --- | --- | --- |
| `time` | Time | UTC | Start of each interval. |
| `Ti` | Number | degC | Indoor air temperature at the start of the interval. |
| `Te` | Number | degC | Temperature of the building envelope at the start of the interval. It cannot be measured: the usual source is the plan returned by the previous call. |
| `STP_heat` | Number | degC | Heating setpoint. |
| `STP_heat_low` | Number | degC | Heating starts when the indoor temperature falls below this value. |
| `STP_heat_high` | Number | degC | Heating stops when the indoor temperature rises above this value. |
| `STP_cool` | Number | degC | Cooling setpoint. |
| `STP_cool_low` | Number | degC | Cooling stops when the indoor temperature falls below this value. |
| `STP_cool_high` | Number | degC | Cooling starts when the indoor temperature rises above this value. |
| `Elec_total` | Number | kWh | Net electricity of the building in the interval: positive when taken from the grid, negative when given to it. In `plan`, it is the energy already committed. |

The `plan` itinerary also carries the flexibility already sold:

| Variable | Type | Unit | Description |
| --- | --- | --- | --- |
| `Elec_flex_down` | Number | kWh | Downward flexibility already committed in the interval. 0 or more. |
| `Elec_flex_up` | Number | kWh | Upward flexibility already committed in the interval. 0 or more. |

Not every value is used:

- `Ti` and `Te` are only read at `i0`, from `plan`. They are the starting state of the building, and they are required.
- The setpoints of `plan` are followed from `i0` to `i_begin_horizon`. With the aims `O` and `O+F` they are followed up to `i_end_horizon`, so they must be given from `i_begin_horizon` to `i_end_horizon`. Setpoints missing before `i_begin_horizon` take the defaults of `02_Config/02_Control.csv`, whatever the aim.
- `Elec_total`, `Elec_flex_down` and `Elec_flex_up` of `plan` are what was committed before this market. The operations of the output are measured against them.
- The script rebuilds `plan_flex_down` and `plan_flex_up` from the plan and the commitments. They travel in the input so that the input and the output have the same format.

On the first call there is no previous plan. The input then has the same format, with `null` everywhere except `Ti` and `Te` of `plan` at `i0`. The two flexibility itineraries are `null` throughout:

- setpoints missing between `i0` and `i_begin_horizon` take the default setpoints of `02_Config/02_Control.csv`;
- missing energies and commitments count as 0.

## Market aims

| Aim | What the script does |
| --- | --- |
| `E` | Optimizes the control mode of every interval to minimize the cost of energy while keeping comfort. |
| `E+F` | Same as `E`, and also sells flexibility, downward and upward, where it pays. |
| `O` | Keeps the setpoints of the plan received and recomputes its energy with the latest forecast. |
| `O+F` | Keeps the plan received as it is and only searches flexibility over it. |

Whatever the aim, the commitments of the committed stretch are kept inside the commitment margin (`flexibility_commitment_margin`, `02_Config/08_Flexibility_Event_Configuration.csv`): the part the new plan no longer holds is bought back, and shows up in `Flex_down_rebought` or `Flex_up_rebought`. With the `O` aim that is the only flexibility the script trades. A commitment that cannot be redrawn because it would raise both the heating and the cooling system is kept as it stands, and the script prints a warning.

## Output file

The output is a JSON object with two blocks: `itineraries` and `operations`. Every array of the output is an array, even when it holds a single value.

### itineraries

The three itineraries, `plan`, `plan_flex_down` and `plan_flex_up`, with the same variables, types and units as in the input. They cover the committed period: from the interval that starts at `i_begin_horizon` to the interval that starts at `i_end_control`.

The last interval, the one that starts at `i_end_control`, only carries `Ti` and `Te`: the state of the building at the end of the committed period. Its other values are `null`. It is there so that the next market can start from that state.

The output `plan` carries `Elec_flex_down` and `Elec_flex_up` with every commitment held after this market: the earlier ones and the new ones.

With the `O+F` aim, `plan` is returned as it came, except `Ti` and `Te` at `i_begin_horizon`, which are simulated again from `i0`. They only differ from the input when the caller has replaced `Ti` at `i0` with a measured value. Only the flexibility itineraries and the commitments change.

### operations

The operations this market sends to the grid, one value per interval, from the interval that starts at `i_begin_horizon` to the last interval before `i_end_control`. Each one is a change from what was committed before this market to what is committed after it. All are 0 or more.

| Variable | Type | Unit | Description |
| --- | --- | --- | --- |
| `time` | Time | UTC | Start of each interval. |
| `Energy_bought` | Number | kWh | New purchase of energy. |
| `Energy_resold` | Number | kWh | Resale of energy bought before. |
| `Energy_sold` | Number | kWh | New sale of energy. |
| `Energy_rebought` | Number | kWh | Buy back of energy sold before. |
| `Flex_down_sold` | Number | kWh | Downward flexibility sold. |
| `Flex_down_rebought` | Number | kWh | Downward flexibility bought back. |
| `Flex_up_sold` | Number | kWh | Upward flexibility sold. |
| `Flex_up_rebought` | Number | kWh | Upward flexibility bought back. |

The money of these operations is not returned, because the caller already has the prices.

## Chaining markets

The plan returned by one call is the plan the next call receives. To call the next market, the caller:

1. Takes the itineraries returned by the previous markets.
2. Builds from them the itineraries of the new call, from its own `i0` to its own `i_end_horizon`. Where the previous markets did not reach, the values are `null`.
3. Adds the new weather forecast, the occupancy and the prices of the new market.

The caller may replace `Ti` at `i0` with a measured value. The script does not tell the two cases apart.

## Example inputs

| File | What it shows |
| --- | --- |
| `01_Input/example_first_call.json` | A first call. Day-ahead market with the `E+F` aim, from 12:00 on 15 January 2024 to 06:00 on the 17th (168 intervals), committing the 16th. There is no previous plan: `plan` carries only `Ti` and `Te` at `i0`, and the two flexibility itineraries are `null` throughout. |
| `01_Input/example_chained_call.json` | A chained call. Later market with the `O+F` aim, from 05:00 to 18:00 on the 16th (52 intervals), committing 06:00 to 12:00. Its itineraries are those returned by the first call. |

Both use the same weather and the same energy prices, cut to the period of each call. The chained call also offers a downward flexibility signal (commitment and execution prices and activation probability) from 06:00 to 08:00 on the 16th, which the first call does not have.

## Contents

| Path | Content |
| --- | --- |
| `call_script_console.R` | The market script, run from the console. |
| `setup.R` | Installs, once, what the script needs. |
| `call_script_from_R.R` | Example of a call from R. |
| `call_script_from_Python_subprocess.py` | Example of a call from Python, through the console. |
| `call_script_from_Python_rpy2.py` | Example of a call from Python, in memory. |
| `01_Input/` | Example inputs: a first call and a chained call. |
| `02_Config/` | Configuration of the building, the control, the reward, the optimizer and the setup. |
| `03_Functions/` | The functions. `optimize_market()` is the main one. |
| `03_1_Functions_Cpp/` | The C++ simulation loop of the building. |
| `90_Output/` | Outputs of the examples. |

## Documentation

How the script works inside, and how it differs from `30_Simulation/`, is explained in `99_Readme/Standalone_Code.md` of the repository.
