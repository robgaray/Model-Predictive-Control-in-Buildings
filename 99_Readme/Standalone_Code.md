# Standalone Code

This page explains the standalone market script in `31_Standalone_code/`: what it does, how it does it, and how to call it from another program.

## Purpose

The simulation in `30_Simulation/` runs a whole year of markets in one go. It creates its own prices, its own flexibility events and its own weather forecast, and it simulates how the assets really behave between markets.

A system of assets in real operation needs something different. The system is one or more assets, buildings with a heat pump, photovoltaic installations and electric batteries, behind one connection to the grid. Before each market closes, some program has to decide which energy and which flexibility the system will buy or sell in that market. It knows the current plan of the system and of each asset, the weather forecast, the occupancy of the buildings and the prices of the market, and nothing else.

The standalone script is that program. It optimizes one market per call. It reuses the processes of `30_Simulation`: the same models of the assets, the same genetic algorithm over control modes, the same reward and the same flexibility itineraries. It leaves out everything that only exists to simulate a year.

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

The script optimizes the assets over the whole stretch from `i_begin_horizon` to `i_end_horizon`, because a decision taken now has consequences later. It commits only the stretch from `i_begin_horizon` to `i_end_control`. The rest is valued to take a good decision, but it is left for later markets to commit, when they know more.

These names are the ones the simulation of `30_Simulation/` uses for the same instants, in `run_market_role()` (`30_Simulation/03_Functions/run_market_role.R`).

## Market intervals

Everything the script receives and returns is given per market interval. The length of an interval is `market_resolution` in `02_Config/03_Run_config.csv` (15 minutes by default). An interval is identified by the time it starts.

Inside, the script simulates the assets on a finer time step, `main_resolution_sec` in `02_Config/00_Inner_parameters/01_computing_parameters.csv` (5 minutes by default). This finer step is never visible from outside.

Each kind of value is read in its own way:

- **Energy** (`Elec_total`, `Elec_PV`, `Elec_charge`, `Elec_discharge`, `Elec_flex_down`, `Elec_flex_up`, and every operation): the energy of the time steps that fall inside the interval, in kWh. The energy of the system is its net electricity at the connection to the grid: positive when taken from the grid, negative when given to it.
- **State** (`Ti`, `Te` of a building, in degC, and `Stored_energy` of a battery, in kWh): the value at the start of the interval.
- **Setpoints, modes of a battery, occupancy and prices**: the value that applies during the interval.
- **Weather** (`Text`, `SolarR`): the value at the start of the interval. Between two interval starts, the script interpolates linearly. A photovoltaic installation also needs to know which instant its radiation value stands for, to find the position of the sun: the parameter `Irradiance_time_offset` of its file says it (see "Photovoltaic installation" below).

## What one call does

A call goes through these steps:

1. **Configuration.** It reads and checks the configuration files of `02_Config` that describe the reward, the optimizer and the markets, and the asset registry. For each asset the call names, it reads and checks the files of its folder, `02_Config/20_Assets/<asset_id>/`. Any invalid value stops the call. The libraries and the setup files of `00_Inner_parameters` are read by `initialize_standalone()` and `setup.R`.
2. **Inputs.** It checks the inputs:
   - the input has the blocks `market`, `context`, `prices`, `system` and `assets`, and the assets are rows of the asset registry, each one once;
   - the four instants are aligned and in order;
   - every vector has one value per interval, without gaps;
   - every value has the right type and range (`02_Config/00_Validation/Validation_Inputs.csv`);
   - each asset meets the checks of its type: a building gives `Ti` and `Te` at `i0` and a valid climate season; a battery gives `Stored_energy` at `i0`, never stores more than its capacity, and has valid modes.
3. **Working table.** It spreads the inputs over the fine time steps, from `i0` to `i_end_horizon`, in a table of the system and a table of each asset.
4. **Comfort bands.** For each building, it works out, from the occupancy, the comfort band the reward compares the indoor temperature with. Around occupied hours the band is anticipated by `Service_Anticipation_Begin` and `Service_Anticipation_End`, and narrowed according to the climate season. The plan is measured against the more restrictive of this band and the occupancy band, and the flexibility itineraries against the occupancy band inside their windows. Every time step outside its band is penalized, occupied or not.
5. **Baseline.** It fixes what every candidate solution is valued against:
   - the commitments already held by the system, taken from the plan received;
   - the prices of the market;
   - the revenue discount.
6. **From `i0` to `i_begin_horizon`.** The assets follow the plan they already have, because that part can no longer change. The script simulates that plan, asset by asset, and projects the two flexibility itineraries over it: the windows committed from `i0` onwards are drawn as the new plan allows, without judging them and without changing any commitment. This gives the state of each asset at `i_begin_horizon`, and the tail of any window that runs into the horizon, which the optimization continues over the plan of each candidate. The state of the heating and cooling systems of a building is deduced from its indoor temperature and its setpoints, and their previous power is taken as 0.
7. **From `i_begin_horizon` to `i_end_horizon`.** It decides according to the aim of the market (see "Market aims").
8. **Result.** It writes the result over the committed stretch and turns it back into market intervals, for the system and for each asset. It also computes the operations of the system: the difference between what was committed before this market and what is committed after it.

## Market aims

The aim of a market says what the script may change. It uses the codes of `30_Simulation`:

| Aim | What the script does |
| --- | --- |
| `E` | Optimizes the control mode of every building and the mode of every battery in every interval to minimize the cost of energy of the system while keeping comfort. |
| `E+F` | Same as `E`, and also sells flexibility (upward and downward) where it pays. |
| `O` | Keeps the setpoints and the battery modes of the plan received and recomputes its energy with the latest forecast. |
| `O+F` | Same as `O`, and also searches flexibility over the recomputed plan. |

With `O` and `O+F` nothing is optimized, so the plan of each building must carry every setpoint, and the plan of each battery every mode, from `i_begin_horizon` to `i_end_horizon`.

An asset that has no control to choose, such as a photovoltaic installation, is simulated as it is with every aim. A photovoltaic installation cannot move its electricity in time, so a call with only photovoltaic installations sells their production as energy and sells no flexibility. A battery offers flexibility within its limits, as described in the flexibility page of the repository (`99_Readme/Flexibility_Events.md`, section "Batteries").

Whatever the aim, the commitments of the committed stretch are kept inside `flexibility_commitment_margin`: the part the new plan no longer holds is bought back. With the `O` aim that is the only flexibility the script trades.

## Inputs

The call operates a system of assets: one or more rows of the asset registry, `02_Config/12_Asset_registry.csv`. The registry comes with a building, `Building_001`, a photovoltaic installation, `Photovoltaic_001`, and an electric battery, `Battery_001`. Each call names the assets it operates as the entries of the block `assets` of its input, each one once. The net electricity of the system is the sum of the net electricity of its assets. It is charged distribution on its absolute net flow in every interval: energy taken from the grid and energy given to it both pay `Elec_unit_cost_distribution`.

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

The rest of the system is the other assets of the call. The battery never goes beyond its limits: the lowest and the highest state of charge, and the largest power at which it charges and discharges. Self-discharge may take a battery at rest a little below its lowest state of charge.

Not every value is used:

- `Stored_energy` is only read at `i0`, from `plan`. It is the starting energy of the battery, and it is required.
- The modes of `plan` are followed from `i0` to `i_begin_horizon`. With the aims `O` and `O+F` they are followed up to `i_end_horizon`, so they must be given from `i_begin_horizon` to `i_end_horizon`. Modes missing before `i_begin_horizon` take mode 5 (stop), whatever the aim.
- `Elec_total` of `plan` is what the battery had committed before this market. Missing energies count as 0.
- The script computes `Elec_charge`, `Elec_discharge` and `Elec_total` again from the modes, so the values of the input only set a starting point.

On the first call, a battery carries `null` everywhere except `Stored_energy` of `plan` at `i0`.

The parameters of the battery are in `02_Config/20_Assets/<asset_id>/19_Battery_parameters.csv`: its capacity (`Capacity`), its lowest and highest state of charge (`SOC_min` and `SOC_max`, as a share of the capacity), the largest power at which it charges and discharges (`Charge_power_max` and `Discharge_power_max`), the share of the energy kept when it charges and when it discharges (`Charge_efficiency` and `Discharge_efficiency`), and the share of the stored energy it loses per day (`Self_discharge`).

## Outputs

The output is a JSON object with three blocks: `system`, `assets` and `operations`. Every array of the output is an array, even when it holds a single value.

### system and assets

The block `system` holds the three itineraries of the system, `plan`, `plan_flex_down` and `plan_flex_up`, with the same variables, types and units as in the input. The block `assets` holds one entry per asset of the call, named after its asset id, with its three itineraries in the same format as in the input. The entries of the assets carry only the itineraries: the climate season and the occupancy of a building are not returned.

They cover the committed period: from the interval that starts at `i_begin_horizon` to the interval that starts at `i_end_control`.

The last interval, the one that starts at `i_end_control`, only carries `Ti` and `Te` of a building and `Stored_energy` of a battery: the state of each asset at the end of the committed period. All its other values are `null`. It is there so that the next market can start from that state.

The `Elec_total` of the system is the sum of the `Elec_total` of its assets. The output `plan` of the system carries `Elec_flex_down` and `Elec_flex_up` with every commitment held after this market: the earlier ones and the new ones.

With the `O` and `O+F` aims, `plan` keeps the setpoints and the battery modes it came with, and its energy, temperatures and stored energy are the ones simulated again with the latest forecast, from the state at `i0`. The change of its energy against the input is traded as energy, like any other aim. The flexibility itineraries and the commitments are measured against that recomputed plan.

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

The caller may replace `Ti` of a building, or `Stored_energy` of a battery, at `i0` with a measured value. The script does not tell the two cases apart.

`01_Input/example_chained_call.json` is built this way from the output of `01_Input/example_first_call.json`.

## How to call it

The script needs R with the packages listed in `02_Config/00_Inner_parameters/00_Libraries.txt` (`GA`, `doParallel`, `doRNG`, `Rcpp` and `jsonlite`), and a C++ compiler for `Rcpp`. It was developed with R 4.5. `setup.R`, run once, installs the packages and, on Windows, the compiler.

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

Every array of the output is an array, even when it holds a single value.

### From R

```
source("31_Standalone_code/03_Functions/initialize_standalone.R")
paths  <- initialize_standalone("31_Standalone_code", NULL)
result <- optimize_market(inputs, paths)
close_standalone(paths)
```

`initialize_standalone()` is called once per R session. The second argument is the configuration folder, and `NULL` means `02_Config`. When `03_Run_config.csv` asks for `parallel = 1`, `initialize_standalone()` also starts the worker processes of the genetic algorithm: it exports every function to them and compiles the C++ modules of the buildings and of the batteries on each of them. Those steps take several seconds, so they are done once per session, and every later call to `optimize_market()` reuses the same workers. `close_standalone(paths)` stops them after the last call; without it, they end when the R session ends. If `03_Run_config.csv` changes, `initialize_standalone()` has to be called again.

`inputs` is a list with the five blocks. `result` is a list with `system` (its `itineraries`: three data frames), `assets` (one entry per asset, each with its `itineraries`) and `operations` (a data frame). `call_script_from_R.R` runs a first market and then a chained one.

### From Python

There are two ways:

- **Through the command line.** `call_script_from_Python_subprocess.py` writes the input as JSON, runs `call_script_console.R` with `subprocess` and reads the output. It only needs the Python standard library. The environment variable `RSCRIPT` can give the path of `Rscript`.
- **In memory, with rpy2.** `call_script_from_Python_rpy2.py` starts R inside Python, turns a Python dictionary into an R list, calls `optimize_market()` and turns the result back with `format_market_output()`. rpy2 must use the R installation that has the packages, for instance through the `R_HOME` environment variable. With an R installed through conda, `LD_LIBRARY_PATH` may also need to point to the `lib` folder of that environment.

## Configuration

`02_Config/` holds the configuration of the assets the script operates. Its values start as copies of those of `30_Simulation/02_Config/`, but they belong to the script and may diverge.

| File | Content |
| --- | --- |
| `01_Optimization_parameters.csv` | Genetic algorithm: population, iterations, runs, crossover, mutation. |
| `03_Run_config.csv` | Market resolution and parallel workers. |
| `08_Flexibility_Event_Configuration.csv` | Phases, margins and limits of the flexibility windows. |
| `09_Reward_parameters.csv` | Weight of cost and revenue discount. They apply to the whole system. |
| `12_Asset_registry.csv` | The assets the script can operate, with the type of each one. |
| `20_Assets/<asset_id>/` | The configuration of each asset. A building has `10_Operational_temperature_corrections.csv` (anticipation of the comfort band and seasonal corrections), `11_Model_parameters.csv` (building and heat pump model), `13_Modes_setpoints.csv` (the control modes, their setpoints and the deadband of their hysteresis) and `18_Comfort_parameters.csv` (the weight of comfort and the comfort bands). A photovoltaic installation has `17_Photovoltaic_parameters.csv` (its location, the treatment of the solar radiation, the orientation of its modules, the modules and the inverter). A battery has `19_Battery_parameters.csv` (its capacity, the limits of its state of charge, its powers, its efficiencies and its self-discharge). |
| `00_Inner_parameters/` | Libraries, internal time step and tolerance, physical properties, and the download sources of `setup.R`. |
| `00_Validation/` | The parameter catalogue and the other validation rules of the configuration and of the inputs. |

To add an asset, copy the folder of an asset of the same type under a new asset id, change its values, and add its row to the registry.

The control is mode-based, as in `30_Simulation`.

## Folder structure

| Path | Content |
| --- | --- |
| `call_script_console.R` | Command line entry point. |
| `setup.R` | Installs, once, what the script needs. |
| `call_script_from_R.R`, `call_script_from_Python_subprocess.py`, `call_script_from_Python_rpy2.py` | Examples of calls from R and from Python. |
| `01_Input/` | Example inputs: a first call, a chained call, a first call with a building and a photovoltaic installation, and the same call with a battery. |
| `02_Config/` | Configuration. |
| `02_Config/20_Assets/<asset_id>/` | The configuration of each asset. |
| `03_Functions/` | The functions of the script. `optimize_market()` is the main one. |
| `05_Models/` | The code of each type of model, in one folder per type. |
| `05_Models/01_Building/` | The functions and the C++ simulation loop of the building, and the electrical model of its heat pump. |
| `05_Models/02_Photovoltaic/` | The functions of the photovoltaic installation. |
| `05_Models/03_Battery/` | The functions and the C++ code of the battery. |
| `90_Output/` | The outputs of the example inputs. |

## Differences from 30_Simulation

The script follows the processes of `30_Simulation`, with these deliberate differences:

- **Inputs from the caller.** Weather, prices and flexibility signals come from the caller. The script does not forecast or emulate them.
- **State at `i0`.** It is the state of the plan received. The heating and cooling state is deduced from the indoor temperature and the setpoints, and the previous power is 0. The energy stored in a battery is `Stored_energy` of the plan received at `i0`, so the battery file of the script has no `SOC_initial`.
- **Energy per interval.** It is the energy of the time steps inside the interval, as in `30_Simulation`.
- **`T_ext_24h` and `Overall_Climate`.** `T_ext_24h` is a single value for the whole call. `Overall_Climate` is a single value for the whole call for each building.
- **Daytime ventilation.** It runs while the building is occupied, as in `30_Simulation`: the C++ core takes it from `Occupancy`.

Both codes have been compared on the same markets. With the same plan, both give the same indoor temperature and the same energy per interval.

## Known limitations

- The script only sees the occupancy of each building up to `i_end_horizon`. If the occupancy of a day starts after `i_end_horizon`, the anticipated comfort band before it is not applied, even when that anticipation falls inside the horizon.
- When a plan that comes from another call is recomputed with the `O` aim, its energy may change slightly, because the state of the heating and cooling systems of a building and their previous power are not passed between calls.
- A battery has no cost of wear, as in `30_Simulation`: charging and discharging cost only the electricity bought and the energy lost.

------------------------------------------------------------------------

[Back to README](../README.md)
