# Standalone market script

This repository performs a full simulation of the model-predictive control across many markets. This folder complements it with a standalone script that allows third parties to run the optimizer on their own.

The script optimizes the energy and flexibility commitments of a system of assets for one market. The system is one or more assets behind one connection to the grid: buildings with a heat pump, photovoltaic installations and electric batteries. It returns the new plan of the system and of each asset, and the operations to send to the market.

It is meant to be called once per market, with the previous commitments, the state of the assets and the most recent forecasts. Each call names the assets it operates.

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

1. It installs the R packages listed in `02_Config/00_Inner_parameters/00_Libraries.txt` (`GA`, `doParallel`, `doRNG`, `Rcpp` and `jsonlite`), with the packages they depend on. If the user cannot write in the R library folder, it uses the personal library folder of the user.
2. It checks that R can compile C++, because the script compiles the simulation code of the buildings and of the batteries every time it starts.
3. On Windows, if no C++ file can be compiled, it downloads and installs Rtools, the compiler R uses on Windows. Windows may ask for permission. On macOS and Linux a compiler needs administrator rights, so the script only says how to install it: `xcode-select --install` on macOS, and `build-essential` (Debian, Ubuntu) or `gcc-c++ make` (Fedora) on Linux.

Running it again does no harm: it only installs what is missing. It ends with exit status 0 when everything is ready and 1 otherwise. Where it downloads from is set in `02_Config/00_Inner_parameters/02_Setup_parameters.csv`, and the Rtools release of each R version in `02_Config/00_Inner_parameters/04_Rtools_versions.csv`.

The three call examples below run `setup.R` before their first call.

## Quick start

From the folder that contains `31_Standalone_code`:

```bash
Rscript 31_Standalone_code/call_script_console.R 31_Standalone_code/01_Input/example_first_call.json output.json
```

The input describes a day-ahead market for one building: called at 12:00 on 15 January 2024, it commits the 16th and optimizes until 06:00 on the 17th. The output holds the plan of the system and of the building, and the energy and flexibility to buy and sell, per 15-minute interval.

To operate a building and a photovoltaic installation together, use `31_Standalone_code/01_Input/example_building_and_photovoltaic.json` in the same way. To add an electric battery to them, use `31_Standalone_code/01_Input/example_building_photovoltaic_and_battery.json`.

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
close_standalone(paths)
```

`initialize_standalone()` is called once per R session. Its second argument is the configuration folder, and `NULL` means `02_Config`. When `03_Run_config.csv` asks for `parallel = 1`, `initialize_standalone()` also starts the worker processes of the genetic algorithm: it exports every function to them and compiles the C++ code on each of them. Those steps take several seconds, so they are done once per session, and every later call to `optimize_market()` reuses the same workers. `close_standalone(paths)` stops them after the last call; without it, they end when the R session ends. If `03_Run_config.csv` changes, `initialize_standalone()` has to be called again. `inputs` is a list with the same blocks as the input JSON file. `result` is a list with `system` (its `itineraries`: three data frames), `assets` (one entry per asset, each with its `itineraries`) and `operations` (a data frame).

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

The script optimizes the assets from `i_begin_horizon` to `i_end_horizon`, because a decision taken now has consequences later. It only commits the stretch from `i_begin_horizon` to `i_end_control`. Between `i0` and `i_begin_horizon` the assets follow the plan they already have, because that part can no longer change: there the flexibility itineraries are only projected over the plan, and no commitment is changed.

Everything the script receives and returns is given per market interval. An interval lasts `market_resolution` minutes (`02_Config/03_Run_config.csv`, 15 minutes by default) and is identified by the time it starts. The values of an interval are read this way:

- **Energy**: the energy of the whole interval, in kWh. The energy of the system is the net electricity at its connection to the grid: positive when taken from the grid, negative when given to it.
- **Temperatures of a building** (`Ti`, `Te`) **and energy stored in a battery** (`Stored_energy`): the value at the start of the interval.
- **Setpoints, modes of a battery, occupancy and prices**: the value that applies during the interval.
- **Weather** (`Text`, `SolarR`): the value at the start of the interval. Between two interval starts, the script interpolates linearly. A photovoltaic installation also needs to know which instant its radiation value stands for, to find the position of the sun: the parameter `Irradiance_time_offset` of its file says it (see "Photovoltaic installation" below).

## Assets

The assets a call can operate are the rows of the asset registry, `02_Config/12_Asset_registry.csv`. It comes with three:

| Asset | Type | What it is |
| --- | --- | --- |
| `Building_001` | Building | A building with a heat pump. The script chooses its control mode in every interval. |
| `Photovoltaic_001` | Photovoltaic | A photovoltaic installation. It produces electricity from the solar radiation and the outdoor temperature, and has no control to choose. |
| `Battery_001` | Battery | An electric battery. It charges from the system and discharges into it. The script chooses its mode in every interval. |

Each call names the assets it operates, one or more, as the entries of the block `assets` of its input. They must be rows of the registry, each one once. The system of the call is those assets together, behind one connection to the grid. The net electricity of the system is the sum of the net electricity of its assets: a building takes electricity from the grid, a photovoltaic installation gives it, and a battery takes it while it charges and gives it while it discharges.

The electricity of the system is charged distribution on its absolute net flow in every interval: energy taken from the grid and energy given to it both pay `Elec_unit_cost_distribution`.

## Input file

The input is a JSON object with five blocks: `market`, `context`, `prices`, `system` and `assets`.

Every vector carries one value per market interval, from the interval that starts at `i0` to the last interval before `i_end_horizon`, without gaps. Each block carries its own `time` vector with the start of each interval. Times are text in ISO 8601 UTC, for example `2024-01-15T12:00:00Z`. A missing value is `null` in JSON, `NA` in R and `None` in Python.

The type and range of every value are checked against `02_Config/00_Validation/Parameter_catalogue.csv` for the values of the `market` block and of each asset block, and against `02_Config/00_Validation/Validation_Inputs.csv` for the vectors. A value out of range stops the call or prints a warning, as those files say.

A call stops with a message that names the problem when:

- the input is in the old format of one building (the blocks `itineraries` at the top level, and no block `assets`);
- the block `assets` is empty, names an asset more than once, or names an asset that is not in the registry;
- a block lacks a vector, a time, or an interval, or holds a value of the wrong type or out of range.

```
{
  "market":  {"aim": "E+F", "i0": "2024-01-15T12:00:00Z", ...},
  "context": {"time": ["2024-01-15T12:00:00Z", ...], "Text": [13.7, ...], ...},
  "prices":  {"time": [...], "Elec_unit_cost_import_buy": [...], ...},
  "system":  {"itineraries": {"plan": {...}, "plan_flex_down": {...}, "plan_flex_up": {...}}},
  "assets":  {
    "Building_001":     {"Overall_Climate": "Heating", "context": {...}, "itineraries": {...}},
    "Photovoltaic_001": {"itineraries": {...}},
    "Battery_001":      {"itineraries": {...}}
  }
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
| `T_ext_24h` | Number | degC | Mean outdoor temperature of the calendar day before the date the market clears. One value for the whole call. It decides when shading and reinforced ventilation are used in the buildings. |
| `random_seed` | Integer | - | Optional. Seed of the genetic algorithm, so that a call can be repeated with the same result. 0 or absent: not fixed. |

### context

The forecast of the surroundings of the system, one value per interval. It is the same for every asset.

| Variable | Type | Unit | Description |
| --- | --- | --- | --- |
| `time` | Time | UTC | Start of each interval. |
| `Text` | Number | degC | Outdoor air temperature forecast, at the start of the interval. |
| `SolarR` | Number | W/m2 | Solar radiation forecast on the horizontal plane, at the start of the interval. |

### prices

The prices of this market, one value per interval. Past `i_end_control` the market publishes no prices, so these values are a forecast made by the caller.

| Variable | Type | Unit | Description |
| --- | --- | --- | --- |
| `time` | Time | UTC | Start of each interval. |
| `Elec_unit_cost_import_buy` | Number | EUR/kWh | Price to buy energy. |
| `Elec_unit_cost_import_sell` | Number | EUR/kWh | Price received when reselling energy bought before. |
| `Elec_unit_cost_export_buy` | Number | EUR/kWh | Price paid when buying back energy sold before. |
| `Elec_unit_cost_export_sell` | Number | EUR/kWh | Price received when selling energy. |
| `Elec_unit_cost_distribution` | Number | EUR/kWh | Grid distribution cost, charged on the absolute net flow of the system: energy imported and energy exported both pay it. |
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

Downward flexibility is a reduction of the electricity the system takes from the grid, and upward flexibility an increase.

### Itineraries

An itinerary is a planned path of the system or of an asset. Every call carries three of them for the system and for each asset, all with the same format, and a call without any of them stops with an error:

- `plan`: the base plan, the one the system follows.
- `plan_flex_down`: the path if all the downward flexibility sold is called.
- `plan_flex_up`: the path if all the upward flexibility sold is called.

The itineraries of the system and of each asset have their own variables, described below. Each one carries a `time` vector, with the start of each interval, and one value per interval of the other variables.

On the first call there is no previous plan. The itineraries then have the same format, with `null` values everywhere, except for what the assets need to start (the state of a building and the energy stored in a battery at `i0`, see below).

### system

The block `system` holds the itineraries of the system, in `system.itineraries`. They carry the net electricity of all the assets together:

| Variable | Itineraries | Type | Unit | Description |
| --- | --- | --- | --- | --- |
| `Elec_total` | All three | Number | kWh | Net electricity of the system in the interval: positive when taken from the grid, negative when given to it. In `plan`, it is the energy already committed before this market. |
| `Elec_flex_down` | `plan` | Number | kWh | Downward flexibility already committed in the interval. 0 or more. |
| `Elec_flex_up` | `plan` | Number | kWh | Upward flexibility already committed in the interval. 0 or more. |

`Elec_total`, `Elec_flex_down` and `Elec_flex_up` of `plan` are what was committed before this market. The operations of the output are measured against them. Missing values count as 0. The script rebuilds `plan_flex_down` and `plan_flex_up` from the plan and the commitments. They travel in the input so that the input and the output have the same format.

### assets

The block `assets` holds one entry per asset of the call, named after its asset id. What an entry holds depends on the type of the asset.

#### Building

| Entry | Type | Unit | Description |
| --- | --- | --- | --- |
| `Overall_Climate` | Text | - | Climate season: `Heating`, `Cooling` or `Intermediate`. One value for the whole call. It decides which side of the comfort band is narrowed inside the scheduling window around occupancy. |
| `context.time` | Time | UTC | Start of each interval. |
| `context.Occupancy` | Integer | 0/1 | 1 if the building is occupied during the interval. It sets the comfort band, and the daytime ventilation runs while it is 1. |
| `itineraries` | - | - | `plan`, `plan_flex_down` and `plan_flex_up`, with the variables below. |

Every itinerary of a building carries these variables, one value per interval:

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

Not every value is used:

- `Ti` and `Te` are only read at `i0`, from `plan`. They are the starting state of the building, and they are required.
- The setpoints of `plan` are followed from `i0` to `i_begin_horizon`. With the aims `O` and `O+F` they are followed up to `i_end_horizon`, so they must be given from `i_begin_horizon` to `i_end_horizon`. Setpoints missing before `i_begin_horizon` take the setpoints of the lowest-numbered mode of `02_Config/20_Assets/<asset_id>/13_Modes_setpoints.csv`, whatever the aim.
- `Elec_total` of `plan` is what the building had committed before this market. Missing energies count as 0.

On the first call, a building carries `null` everywhere except `Ti` and `Te` of `plan` at `i0`.

#### Photovoltaic installation

A photovoltaic installation has no occupancy, no climate season and no state to start from. Its entry holds only its `itineraries`, and every itinerary carries these variables, one value per interval:

| Variable | Type | Unit | Description |
| --- | --- | --- | --- |
| `time` | Time | UTC | Start of each interval. |
| `Elec_PV` | Number | kWh | Electricity the installation produces in the interval. 0 or more. |
| `Elec_total` | Number | kWh | Net electricity of the installation in the interval: minus its production. |

The script computes the production of the installation again from the weather forecast, with the parameters in `02_Config/20_Assets/<asset_id>/17_Photovoltaic_parameters.csv`, so the values of the input only set a starting point. On the first call they are all `null`.

The production depends on where the installation is and how its modules face. The file sets the location (`Latitude` and `Longitude`), the orientation (`Tilt`, `Azimuth` and `Albedo`) and the modules and the inverter (`Module_area`, `Module_efficiency`, `DC_losses`, `Temperature_coefficient`, `NOCT`, `Inverter_efficiency` and `Inverter_power`). From the position of the sun, the script turns the solar radiation of the weather forecast into the radiation on the plane of the modules. `Diffuse_threshold` and `Min_sun_elevation` set how it splits the radiation into direct and diffuse. `Irradiance_time_offset` is the time added to the instant of each interval to find the position of the sun, so that the sun is taken at the instant the radiation stands for. The default, -30 minutes, is right for hourly means dated at the end of the hour, as in the examples of this folder. If the radiation of your input is the value at an instant, set it to 0. The output does not change: it holds only the energy of each interval.

#### Battery

An electric battery has no occupancy and no climate season. Its entry holds only its `itineraries`, and every itinerary carries these variables, one value per interval:

| Variable | Type | Unit | Description |
| --- | --- | --- | --- |
| `time` | Time | UTC | Start of each interval. |
| `Mode` | Integer | - | Mode of the battery during the interval, from 1 to 5 (see below). |
| `Stored_energy` | Number | kWh | Energy stored in the battery at the start of the interval. Between 0 and the capacity of the battery. |
| `Elec_charge` | Number | kWh | Electricity the battery takes from the system in the interval. 0 or more. |
| `Elec_discharge` | Number | kWh | Electricity the battery gives to the system in the interval. 0 or more. |
| `Elec_total` | Number | kWh | Net electricity of the battery in the interval: `Elec_charge` minus `Elec_discharge`. In `plan`, it is the energy already committed. |

In each interval the battery works in one of five modes:

| Mode | Name | What the battery does |
| --- | --- | --- |
| 1 | Surplus charge | It charges only with the electricity the rest of the system gives to the grid, never from the grid. |
| 2 | Charge | It charges as much as it can, also from the grid. |
| 3 | Local discharge | It discharges only to cover the electricity the rest of the system takes from the grid, never to give it to the grid. |
| 4 | Discharge | It discharges as much as it can, also giving electricity to the grid. |
| 5 | Stop | It neither charges nor discharges. |

The rest of the system is the other assets of the call. The battery never goes beyond its limits: the lowest and the highest state of charge, and the largest power at which it charges and discharges.

Not every value is used:

- `Stored_energy` is only read at `i0`, from `plan`. It is the starting energy of the battery, and it is required.
- The modes of `plan` are followed from `i0` to `i_begin_horizon`. With the aims `O` and `O+F` they are followed up to `i_end_horizon`, so they must be given from `i_begin_horizon` to `i_end_horizon`. Modes missing before `i_begin_horizon` take mode 5 (stop), whatever the aim.
- `Elec_total` of `plan` is what the battery had committed before this market. Missing energies count as 0.
- The script computes `Elec_charge`, `Elec_discharge` and `Elec_total` again from the modes, so the values of the input only set a starting point.

On the first call, a battery carries `null` everywhere except `Stored_energy` of `plan` at `i0`.

The parameters of the battery are in `02_Config/20_Assets/<asset_id>/19_Battery_parameters.csv`: its capacity (`Capacity`), its lowest and highest state of charge (`SOC_min` and `SOC_max`, as a share of the capacity), the largest power at which it charges and discharges (`Charge_power_max` and `Discharge_power_max`), the share of the energy kept when it charges and when it discharges (`Charge_efficiency` and `Discharge_efficiency`), and the share of the stored energy it loses per day (`Self_discharge`).

## Market aims

| Aim | What the script does |
| --- | --- |
| `E` | Optimizes the control mode of every building and the mode of every battery in every interval to minimize the cost of energy of the system while keeping comfort. |
| `E+F` | Same as `E`, and also sells flexibility, downward and upward, where it pays. |
| `O` | Keeps the setpoints and the modes of the plan received and recomputes its energy with the latest forecast. |
| `O+F` | Same as `O`, and also searches flexibility over the recomputed plan. |

An asset that has no control to choose, such as a photovoltaic installation, is simulated as it is with every aim. It has nothing to offer in a new flexibility window, so a call with only photovoltaic installations sells their production as energy and sells no flexibility.

Whatever the aim, the commitments of the committed stretch are kept inside the commitment margin (`flexibility_commitment_margin`, `02_Config/08_Flexibility_Event_Configuration.csv`): the part the new plan no longer holds is bought back, and shows up in `Flex_down_rebought` or `Flex_up_rebought`. With the `O` aim that is the only flexibility the script trades. An upward commitment whose system is no longer clear from the plan is redrawn with the heating or the cooling, whichever delivers more of it without raising both systems, and the part it cannot deliver is bought back. A commitment that cannot be redrawn at all, because it would raise both the heating and the cooling system of a building or because the new plan leaves it no room, is kept as far as the equipment allows: each row stays between zero and what the system that provides the window can draw. The part that does not fit is bought back, the candidate is penalized as technically infeasible, and the script prints a warning. The rule that forbids raising the heating and the cooling of a building together applies inside each building: two different buildings may do it.

## Output file

The output is a JSON object with three blocks: `system`, `assets` and `operations`. Every array of the output is an array, even when it holds a single value.

### system and assets

The block `system` holds the three itineraries of the system, `plan`, `plan_flex_down` and `plan_flex_up`, with the same variables, types and units as in the input. The block `assets` holds one entry per asset of the call, named after its asset id, with its three itineraries in the same format as in the input. The entries of the assets carry only the itineraries: the climate season and the occupancy of a building are not returned.

They cover the committed period: from the interval that starts at `i_begin_horizon` to the interval that starts at `i_end_control`.

The last interval, the one that starts at `i_end_control`, only carries `Ti` and `Te` of a building and `Stored_energy` of a battery: the state of the asset at the end of the committed period. All its other values are `null`. It is there so that the next market can start from that state.

The `Elec_total` of the system is the sum of the `Elec_total` of its assets. The output `plan` of the system carries `Elec_flex_down` and `Elec_flex_up` with every commitment held after this market: the earlier ones and the new ones.

With the `O` and `O+F` aims, `plan` keeps the setpoints and the modes it came with, and its energy, temperatures and stored energy are the ones simulated again with the latest forecast, from the state at `i0`. The change of its energy against the input is traded as energy, like any other aim. The flexibility itineraries and the commitments are measured against that recomputed plan.

### operations

The operations this market sends to the grid, one value per interval, from the interval that starts at `i_begin_horizon` to the last interval before `i_end_control`. They are the operations of the system, not of each asset. Each one is a change from what was committed before this market to what is committed after it. All are 0 or more.

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

1. Takes the blocks `system` and `assets` returned by the previous markets.
2. Builds from them the blocks `system` and `assets` of the new call: the itineraries of the system and of each asset, from its own `i0` to its own `i_end_horizon`. Where the previous markets did not reach, the values are `null`.
3. Adds what the output does not carry: the climate season and the occupancy of each building. It also adds the new weather forecast, the new prices and the `market` block of the new market.

The caller may replace `Ti` at `i0` with a measured value. The script does not tell the two cases apart.

## Example inputs

| File | What it shows |
| --- | --- |
| `01_Input/example_first_call.json` | A first call with one building. Day-ahead market with the `E+F` aim, from 12:00 on 15 January 2024 to 06:00 on the 17th (168 intervals), committing the 16th. There is no previous plan: the plan of `Building_001` carries only `Ti` and `Te` at `i0`, and all the other values are `null`. |
| `01_Input/example_chained_call.json` | A chained call with one building. Later market with the `O+F` aim, from 05:00 to 18:00 on the 16th (52 intervals), committing 06:00 to 12:00. Its itineraries are those returned by the first call. |
| `01_Input/example_building_and_photovoltaic.json` | A first call with a building and a photovoltaic installation (`Building_001` and `Photovoltaic_001`). The market is that of the first example. |
| `01_Input/example_building_photovoltaic_and_battery.json` | The previous call with a battery as well (`Battery_001`). The battery starts with 5 kWh stored at `i0`, and all its other values are `null`. |

The four use the same weather and the same energy prices, cut to the period of each call. The chained call also offers a downward flexibility signal (commitment and execution prices and activation probability) from 06:00 to 08:00 on the 16th, which the first call does not have.

The outputs of the examples are in `90_Output/`.

## Configuration

The configuration is in `02_Config/`, and a different folder with the same files can be given to the console script as its third argument.

- `12_Asset_registry.csv` lists the assets the script can operate, with the type of each one.
- The files of the folder `02_Config/` itself are common to every asset: the optimizer, the markets and their resolution, the flexibility events and the reward.
- Each asset has its own folder, `02_Config/20_Assets/<asset_id>/`, with the files of its type. A building has the corrections of its operational temperatures, its model parameters, its setpoint modes with the deadband of their hysteresis, and its comfort weight and comfort bands. A photovoltaic installation has its parameters: its location, the treatment of the solar radiation, the orientation of its modules, the modules and the inverter. A battery has its parameters: its capacity, its power and its efficiency.
- To add an asset, copy the folder of an asset of the same type under a new asset id, change its values, and add its row to the registry.

Every configuration file is checked against `02_Config/00_Validation/Parameter_catalogue.csv` before the script uses it.

## Contents

| Path | Content |
| --- | --- |
| `call_script_console.R` | The market script, run from the console. |
| `setup.R` | Installs, once, what the script needs. |
| `call_script_from_R.R` | Example of a call from R. |
| `call_script_from_Python_subprocess.py` | Example of a call from Python, through the console. |
| `call_script_from_Python_rpy2.py` | Example of a call from Python, in memory. |
| `01_Input/` | Example inputs: a first call, a chained call, a first call with a building and a photovoltaic installation, and the same call with a battery. |
| `02_Config/` | Configuration of the reward, the optimizer, the flexibility windows, the market resolution, the asset registry and the setup. |
| `02_Config/20_Assets/<asset_id>/` | The configuration of each asset, in a folder named after it. |
| `02_Config/00_Validation/` | The parameter catalogue, with the type, range, unit and description of every parameter of the configuration files, and the other validation tables. |
| `03_Functions/` | The functions of the script. `optimize_market()` is the main one. |
| `05_Models/` | The code of each type of model, in one folder per type. |
| `05_Models/01_Building/` | The functions and the C++ simulation loop of the building and the electrical model of its heat pump. |
| `05_Models/02_Photovoltaic/` | The functions of the photovoltaic installation. |
| `05_Models/03_Battery/` | The functions and the C++ code of the battery. |
| `90_Output/` | Outputs of the examples. |

## Documentation

How the script works inside, and how it differs from `30_Simulation/`, is explained in `99_Readme/Standalone_Code.md` of the repository.
