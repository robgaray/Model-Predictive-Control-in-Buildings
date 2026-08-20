# execution_flow.md

Complete walkthrough of `30_Simulation/Main.R` and every script and function it invokes, **in real execution order**. For each block, the document explains what it does, which scripts/functions it calls, and why (the reason/use of that call within the MPC flow).

This document complements `90_Structure/relations.csv` and `90_Structure/Main_relations.md` (which document the call hierarchy in a structural/graphical way) with a **sequential** narrative: the exact order in which things happen when `Main.R` is executed.

Convention: file names refer to `30_Simulation/04_Scripts/*.R` unless `03_Functions/*.R` is indicated.

---

## Index of Main.R's 13 phases

1. Initialization (`initialization.R`)
2. Data and parameter loading (`load_all_parameters.R`)
3. Subsetting `Main_df` by month/period (inline block)
4. Market columns in `Main_df` (`market_columns_setup.R`)
5. Flexibility generation (conditional) (`flexibility_generation.R`)
5b. Buy/sell price signals (`energy_price_signals_setup.R`)
6. Occupancy profiles (`generate_occupancy_profiles.R`)
7. Scheduling profiles (`generate_scheduling_profiles.R`)
8. Climate priority (`climate_priority.R`)
9. Future price matrices (`full_market_information_setup.R`)
10. Market commitment matrices (`market_commitments_setup.R`)
11. Reference temperature profiles (`reference_temperature_profiles.R`)
12. Main simulation loop (`simulation.R`)
13. Results export (`data_outputs.R`)

---

## Phase 1 — Initialization (`initialization.R`)

**What it does.** Clears the working environment (`rm(list=ls()); gc()`), sets `options(stringsAsFactors = FALSE)`, and builds the `paths` list with the absolute paths to all configuration files under `30_Simulation/02_Config/` (the parameter CSVs, `01_Libraries.txt`, and `00_Validation/Parameter_config.csv`) and data files (`30_Simulation/01_Data/*.rds`). Before continuing, it validates that all required directories and files exist (`stop()` if any is missing), so it fails as early as possible with a clear message instead of failing later with a cryptic "file not found" error.

**What it calls and why.**
- `initialization(paths$library_file, functions_path)` — the like-named function from `03_Functions/initialization.R`. This function:
  1. Reads `01_Libraries.txt` line by line (ignoring `#` comments and blank lines) and calls `requireNamespace()` for each package; if it is missing, it attempts `install.packages(..., repos = "https://cloud.r-project.org")` and then `library(pkg, character.only = TRUE)`. This ensures all dependencies (`GA`, `doParallel`, `Rcpp`, etc.) are loaded before the rest of the code uses them.
  2. Walks through every file in `30_Simulation/03_Functions/*.R` and `source()`s them one by one, leaving **all** the functions of the simulation subsystem (validations, GA, physical calculation, markets...) available in the global environment.
- `Rcpp::sourceCpp("30_Simulation/03_1_Functions_Cpp/period_simulation_cpp.cpp")` — compiles the physical engine in C++ (2C thermal model) and exposes the function `period_simulation_cpp()` to the R environment. This is done here, once, because compiling on every call would be prohibitively slow; the rest of the pipeline invokes the already-compiled function.

**Why.** Without this step nothing else works: neither the `03_Functions` functions nor the physical C++ core would be available. It is deliberately the first `source()` in `Main.R` and does not require "looking inside" except to debug environment issues (packages/compiler).

---

## Phase 2 — Data and parameter loading (`load_all_parameters.R`)

**What it does.** This is the master parameter-loading script. It replaces the old `data_model_parameters.R` / `control_optimization_parameters.R` / `market_config_parameters.R` (which no longer exist) with a single entry point that executes, in this exact order:

1. **Loads `validation_config`** from `30_Simulation/02_Config/00_Validation/Parameter_config.csv`: the table that defines, for each configuration file and each parameter, its type (`Integer`/`Real`/`Options`/`Text`), severity (`Error`/`Warning`), and valid range/options. This table is the validation contract used by all the subsequent `load_XX_*.R` scripts.
2. **Assembles `Main_df`** via `assemble_main_df.R` (04_Scripts), which replaces the old `Main_df <- readRDS(paths$main_file)` — see `01_Agent_Comments/20260722b_Plan_Señales_por_Procedencia.md`. This script:
   1. Loads and validates the 2 real input dataframes (`load_meteo_df.R` → `Meteo_df`: `Text`, `SolarR`; `load_energy_prices_df.R` → `Energy_Prices_df`: `Elec_unit_cost_buy`, `Elec_unit_cost_distribution` — replaces `Elec_unit_cost_sell` —, the 4 legacy `Flex_unit_cost_*` columns, `Flex_Probab`), each with 5 safeguards: evenly spaced timestamps (detected step, not forced to 1h/15'), step and origin that are multiples of `Main_df`'s resolution (5'/300s), correct data type, and value range checked against `Validation_Meteo_df.csv`/`Validation_Energy_Prices_df.csv` (`00_Validation/`).
   2. Determines the common time range: the start must match exactly between both files (`stop()` if not); if they end at different instants, the longer one is trimmed to the end of the shorter one, with a `warning()`. Builds the master 5' grid over that range.
   3. Interpolates `Meteo_df` linearly over the 5' grid; keeps `Energy_Prices_df` at the last available value ("step-hold") over the same grid.
   4. Generates the 3 synthetic dataframes directly on the 5' grid, all set to 0: `System_df` (via `generate_system_df()`, which reads `30_Simulation/02_Config/01_Model_Descriptions/01_Building/Simulation_Variables_Building.txt` and expands each `scenario=yes` variable into 3 columns `_exec`/`_plan`/`_plan_flex`, or leaves it as 1 column if `scenario=no` — 65 columns), `Flexibility_actions_df` (`Flex_Act`), and `Meteo_transformations_df` (`T_ext_24h`, `Text_forec(_ant)`, `SolarR_forec(_ant)`).
   5. Combines everything into `Main_df` (`cbind`). Forces `Main_df$Occupancy <- 0L` and `Main_df$Scheduling <- 0L` — these two columns will be **regenerated** later (phases 6 and 7); they are set to 0 here only so that `validate_Main_df()` does not fail due to inconsistent previous values. Calls `validate_Main_df(Main_df)` (`03_Functions/validate_Main_df.R`), which checks structure (non-empty data frame), presence of all required columns (the 80: 2 from `Meteo_df`, 7 from `Energy_Prices_df`, 65 from `System_df`, 1 from `Flexibility_actions_df`, 5 from `Meteo_transformations_df`), that `time` is a strictly increasing `POSIXct` with no `NA`, that numeric columns really are numeric, that the binary flags (`Occupancy`, `Scheduling`, `Act_vent`, `Act_heat_exec`, `Act_cool_exec`) contain only 0/1, and physical range checks (`Text` in `[-50, 60]` as a warning, `Elec_unit_cost_buy >= -1` as a warning, `SolarR >= 0` as a hard error).
3. **Initializes `parameters <- list()`** — the structure that will accumulate all the sub-parameters.
4. **Sources 13 sub-scripts**, one per configuration file, each detailed below.
5. **Loads `parameters$needed_cols`** from `02_Needed_cols.csv` (filtering out comments/blank lines): the list of `Main_df` columns that the simulation loop needs to exist (used in `simulation.R` to create any missing column, initialized to 0).
6. **Recalculates `Main_df$T_ext_24h`** as the mean of `Text` over the **previous calendar day** (`tapply(Main_df$Text, as.Date(Main_df$time), mean, na.rm = TRUE)`), using `parameters$forecast$t_ext_24h_default` as a fallback value when there is no previous day (e.g. the first day of the year). If that default value is missing or `NA`, `stop()`.

### The 13 loading sub-scripts (in execution order)

All of them share the same pattern: `read_and_validate_parameter_csv()` (`03_Functions/`) reads the CSV as parameter/value pairs, validates for duplicate names, and validates each value against `validation_config` (`03_Functions/validate_parameter_config.R`); afterwards, a domain-specific `load_XX_*()` function structures the already-validated values into a `parameters` sub-list, also applying its own clamping/default-value logic where applicable.

1. **`load_03_physical_properties.R`** → `parameters$physical_properties`. Reads `Cp_air`/`dens_air`; calls `validate_physical_properties()` (checks that they are positive and warns if they differ from the reference values 1.005/1.204).
2. **`load_11_model_parameters.R`** → `parameters$model`. Reads the 27 parameters of the 2C thermal model (capacitances `Ci`/`Ce`, resistances `Rie`/`Rea`, surfaces `Aw`/`Ae`, heat pump curves, ventilation rates `RENventXX`, initial temperatures...); calls `validate_model_parameters()` (ranges for `Efi_Vent_Rec`/`Volume`/ `inertial_fact` — `RENventXX` is already validated when the CSV is loaded via `Parameter_config.csv`, range `[0,20]` with `stop()`) and then `compute_Rvent()` (`03_Functions/`), which converts the air renewal rates (`RENvent01/1/2`, in ACH) into ventilation thermal resistances (`Rvent01/1/2`, in K/kW) via `Rvent = 3600 / (ACH · Volume · dens_air · Cp_air)`, and also computes their heat-recovery equivalents (`RventXX_HR`). It *requires* `parameters$physical_properties` to already exist (previous step).
3. **`load_04_use_patterns.R`** → `parameters$use_patterns`. Reads `04_Use_Patterns.csv`, which contains **two tables** in the same file (a `TYPE` block with 24 hourly columns `H01..H24`, and a `MONTH` block with 7 weekday columns `D01..D07`); locates both headers, separates them, validates required columns, types, and cross-consistency (every `TYPE` referenced from `MONTH` must exist). The result (`day_types`, `month_profiles`) is what `generate_occupancy_profiles.R` will consume in phase 6.
4. **`load_18_reward_parameters.R`** → `parameters$reward`. Reads the reward function weights (`Alpha_Service_Min`, comfort bands `Service_T_Low/High`, `Setback_T_Low/High`, service anticipation, HDD/CDD…). No domain logic beyond the generic validation.
5. **`load_19_forecast_parameters.R`** → `parameters$forecast`. Reads `forecast_type` ("accurate"/"inaccurate") as text and validates it strictly; the rest of the values (`forecast_n_days_back`, `forecast_weight_history`, `t_ext_24h_default`) are converted to numeric.
6. **`load_12_control_parameters.R`** → `parameters$control`. Calls `load_control_parameters()` (`03_Functions/`), which structures setpoint ranges (`set_point_range_heating/cooling`), `Deadband`, `control_type` ("modes"/"setpoints"), default setpoints, and the flexibility parameters (`flexibility_event_length_max`, `flexibility_recover_timespan`, `thermal_stabilization_timespan`, `minimum_flexibility`, `flexibility_splits`). Explicitly validates that `control_type` is one of the two accepted values and that `Deadband` exists.
7. **`load_13_modes_setpoints.R`** → `parameters$setpoint_modes`. Reads `13_Modes_setpoints.csv` directly (without going through `read_and_validate_parameter_csv()`, because it is a table, not a parameter/value list); validates the `mode`/`heating`/`cooling` columns, absence of `NA`, that `mode` is an integer, no duplicates, and that the modes form a consecutive sequence starting at 1 (1, 2, 3...) — this is what allows `optimize_modes()` to treat the mode index as a bounded integer gene `[1, n_modes]` with no gaps.
8. **`load_14_optimization_parameters.R`** → `parameters$optimization`. Calls `load_optimization_parameters()` (`03_Functions/`), which validates and clamps the GA hyperparameters: `population_size`, `iteration_number`, `run_number` (all `>= 1`, error if not), `pcrossover`/`pmutation` (clamped to `[0, 1]` with a warning).
9. **`load_15_market_config.R`** → `parameters$market`. Calls `load_market_parameters()` (`03_Functions/`), which structures and clamps the Scheduling/Piloting horizons (`Optimization_horizon_*`, `Implementation_horizon_*`, `Anticipation_*`) to the ranges declared in `Parameter_config.csv`, and normalizes `Complex_Market_Config` to lowercase `"yes"`/`"no"`. Afterwards:
   - Resolves `optimization_aim_scheduling`/`optimization_aim_piloting` (raw codes `O`/`E`/`O+F`/`E+F`) to the internal labels `"energy"`/`"flexibility"`/`"operation"`/`"operationflex"` via `map_optimization_aim()` (`03_Functions/`).
   - Sets `parameters$control$optimization_aim` to the *scheduling* aim (it will be overwritten per-market inside the loop, in `run_market_process()`, but serves as a default value).
   - Validates that `Optimization_horizon_scheduling * 60` is a multiple of `market_resolution` (if not, `stop()`).
10. **`load_16_market_config_scheduling.R`** → `parameters$market_config_scheduling`. Calls `load_market_config_table()` (`03_Functions/`), which reads `16_Market_config_scheduling.csv`, discards a `"texto"` units-header row if present, validates the required columns (`Market`, `closure`, `begin`, `end`, `end_optimization`, `aim`), validates that the four hourly columns are numeric and `>= 0`, and validates each `aim` value with `map_optimization_aim()`. This table is only used when `Complex_Market_Config == "yes"`.
11. **`load_17_market_config_piloting.R`** → `parameters$market_config_piloting`. Identical to the previous one but for `17_Market_config_piloting.csv`.
12. **`load_21_energy_price_parameters.R`** → `parameters$energy_price`. Reads `21_Energy_price_parameters.csv` (`Energy_Export_discount`, `Energy_Sell_discount`, and the 4 `Price_variation_in_time` premiums per time-of-day band), validated against `Parameter_config.csv`. No derivation script consumes it yet (see `energy_price_signals_setup.R` below, which for now only duplicates buy/sell without applying these discounts — see `01_Agent_Comments/20260720_Plan_Redefinicion_Precios_Energia.md`, Phase 3).
13. **`load_30_debug_and_config.R`** → `parameters$debug_and_config`. Calls `load_debug_and_config_parameters()` (`03_Functions/`), which structures `month_subset`, `period_subset`, `verbose` (converted to logical), `parallel`, `Price_emulation`.

**Why.** By the end of this phase, `parameters` contains *everything* the rest of the pipeline needs, already validated; `Main_df` is the complete dataset (not yet subset) with `T_ext_24h` recalculated. Splitting the loading into 13 small scripts (instead of a single monolithic script) gives each configuration file its own localized failure point and its own isolated business logic (clamping, default values).

---

## Phase 3 — Subsetting `Main_df` by month/period (inline block in `Main.R`)

**What it does.** A block of code directly in `Main.R` (not a separate script). If `parameters$debug_and_config$month_subset != 0`, it filters `Main_df` to the rows of that month (`month(Main_df$time) == month_subset`). If `period_subset != 0`, it trims to the first `period_subset` rows (clamped to `nrow(Main_df)` if it exceeds the available size). Both temporary variables (`month_subset`, `period_subset`) are removed at the end of the block.

**Why.** It allows running short simulations (for debugging or for diagnosing this same repository) without having to edit `Meteo_df.rds`/`Energy_Prices_df.rds`; with the repo's default configuration (`month_subset = 1, period_subset = 2000`) the simulation only runs over January and its first 2000 rows (5-minute resolution ⇒ ~6.9 days).

---

## Phase 4 — Market columns in `Main_df` (`market_columns_setup.R`)

**What it does.** Initializes to 0 the 12 `Sched_*`/`Pilot_*` columns of `Main_df` (`Market_Name`, `Market_Bid_time`, `Market_Period_Begin`, `Market_Period_End`, `Optimization_Horizon`, `Market_Aim`, for each of the two roles). It then calls, twice (once per role):

- **`build_market_timeline()`** (`03_Functions/`) — builds the complete market calendar for that role and writes it into `Main_df` in the row corresponding to each `Market_Bid_time`. It has two modes:
  - **Basic** (`Complex_Market_Config == "no"`): a single market (`"Basic_Market"`) repeated every `Implementation_horizon_{scheduling|piloting}` hours, from `time_min` to `time_max` of `Main_df`. The aim is fixed (energy or flexibility, according to `optimization_aim`) for all instances.
  - **Complex** (`Complex_Market_Config == "yes"`, the active mode in the repo's current configuration, `15_Market_config.csv`): iterates over each row of the `parameters$market_config_scheduling` / `..._piloting` table (one row = one market type, e.g. day-ahead, intraday...) and, for each day in `Main_df`'s range, generates an instance of that market with `begin`/`closure`/`end`/`end_optimization` hours relative to midnight. If the resulting `Market_Bid_time` does not exactly match any row of `Main_df$time`, it issues an explicit `warning()` and discards that instance (behavior fixed in the previous session; it used to fail silently).

**Why.** These are the columns that `simulation.R` inspects at each step of the loop (`is_market_active(Main_df$Sched_Market_Name[i])`) to decide whether that timestep triggers a Scheduling and/or a Piloting process.

---

## Phase 5 — Flexibility generation (conditional) (`flexibility_generation.R`)

**What it does.** Only runs if `parameters$debug_and_config$Price_emulation == 1` (as in the repo's current configuration). Overwrites the flexibility columns of `Main_df` (`Flex_unit_cost_down/up_com/exec`, `Flex_Probab`, `Flex_Act`) with generated values, in two modes depending on `parameters$market$Complex_Market_Config` (emulation parameters — `Max_flex_periods_day`, `Max_flex_com_price`, `Max_flex_exec_price`, `Max_flex_period_duration`, `Max_flex_probability` — now in `15_Market_config.csv`, merged from the old `20_Flex_price_simulation.csv`):

- **Basic** (`"no"`): same as before, day by day a number of non-zero price "windows" (`Flex_periods`) is drawn, along with a single commitment/execution price for that day; each window is now placed discretized into `market_resolution` slots within the day's `[0, 24h)` window (`place_flex_candidate()`), instead of with a continuous Dirichlet-type partition.
- **Market-aware** (`"yes"`, delegates to `generate_flexibility_events()`): processes the Scheduling markets in `Bid_time` order — for each one, an "echo" step (`try_flex_echo()`) offers advance/delay to previous, not-yet-shifted events whose exclusion zone (±3h) overlaps the new market's horizon, and then places new candidates only in the segments that remain free (`compute_available_segments()` + `place_flex_candidate()`) — and, after all Scheduling, the Piloting markets in `Bid_time` order, placing candidates without any overlap check and accepting them with a probability that decreases exponentially with the horizon (`P_event_base * exp(-decay_rate * h)`). Its own parameters are in `22_Flexibility_generation_parameters.csv` (`Max_shift_hours`/`P_advance`/`P_delay` for Scheduling; `P_event_base`/`decay_rate` for Piloting). See `01_Agent_Comments/20260723_Plan_Generacion_Flexibilidad.md` for the full design.

**Why.** It allows generating synthetic, reproducible flexibility scenarios without depending on a real market feed, respecting (in market-aware mode) the real structure and overlaps of the market configuration tables — intended for testing/demonstrating the flexibility subsystem.

---

## Phase 5b — Buy/sell price signals (`energy_price_signals_setup.R`)

**What it does.** Always runs (it is not conditional, unlike phase 5). Derives the 12 buy/sell price columns consumed by the rest of the pipeline (4 for energy, 8 for flexibility) from the signals already present in `Main_df` at this point: `Elec_unit_cost_buy` and `Elec_unit_cost_distribution` (real input data from `Energy_Prices_df`; `Elec_unit_cost_distribution = Elec_unit_cost_buy - Elec_unit_cost_sell` as originally loaded, see `01_Agent_Comments/20260722_Plan_Redefinicion_Señales_Energia.md`, Step 1), and `Flex_unit_cost_down/up_com/exec`, whether real data or just overwritten by the conditional phase 5. For the 2 import columns (`import_buy`/`import_sell`), they are set directly equal to `Elec_unit_cost_buy`; for the 2 export columns (`export_buy`/`export_sell`), the legacy sell price is first reconstructed as `Elec_unit_cost_buy - Elec_unit_cost_distribution` (algebraically identical to the removed `Elec_unit_cost_sell`) and that value is assigned to them. Otherwise it remains a structural *placeholder* with no behavior change: each new "buy" and "sell" column of a pair is set equal to the value of the legacy signal it replaces — see `01_Agent_Comments/20260720_Plan_Redefinicion_Precios_Energia.md`, Phase 1 ("structural refactor, no behavior change").

**Why.** It is the single point where, in a future round (Phase 3 of the previous document), the 4 energy columns will be replaced by truly asymmetric values derived from `parameters$energy_price` (`Energy_Export_discount`, `Energy_Sell_discount`, `Price_variation_in_time` per time-of-day band, already loaded since phase 2 in `load_21_energy_price_parameters.R`, but with no consumer yet). Truly differentiating the 8 flexibility columns remains out of scope for now.

---

## Phase 6 — Occupancy profiles (`generate_occupancy_profiles.R`)

**What it does.** Generates `Main_df$Occupancy` (0/1) from `parameters$use_patterns` (loaded in phase 2, sub-script 3). For each row of `Main_df`: determines the month (`MONTHxx`) and the day of the week (`Dxx`, Monday=1) to index the `month_profiles` table and obtain the usage `TYPE` for that specific day; then uses the hour of the day (`Hxx`, with hour 0 mapped to `H24`) to index the `day_types` table and obtain the 0/1 occupancy value for that specific hour of that day type. Validates that the result is always an integer 0/1 with no `NA`.

**Why.** This column is the trigger for everything that follows: `generate_scheduling_profiles.R` (phase 7) uses it to decide when to activate `Scheduling`, and `reference_temperature_profiles.R` (phase 11) uses it to choose between the service comfort band or the "setback" band.

---

## Phase 7 — Scheduling profiles (`generate_scheduling_profiles.R`)

**What it does.** Generates `Main_df$Scheduling` (0/1) from `Main_df$Occupancy` and the service anticipation parameters (`parameters$reward$Service_Anticipation_Begin/End`, in hours). For each calendar day with at least one occupied row, computes an interval `[first_occupied_hour - Anticipation_Begin, last_occupied_hour - Anticipation_End]` and marks `Scheduling = 1` in every row of `Main_df$time` within that interval (for that day).

**Why.** `Scheduling` marks the windows in which the building must start "preparing" (pre-heating/pre-cooling) before actual occupancy arrives; it is also the reference time band used by `reference_temperature_profiles.R` to relax/adjust the comfort band during Scheduling (`Scheduling_T_Low/High`).

---

## Phase 8 — Climate priority (`climate_priority.R`)

**What it does.** Generates `Main_df$Overall_Climate` (`"Heating"` / `"Cooling"` / `"Intermediate"`), a daily tag. For each calendar day, it checks the previous `HDD_period` individual 24h periods one by one: if every one of them has its own mean `Text` below `T_ref_Heating_Season`, the day is tagged `"Heating"`. Otherwise it checks the previous `CDD_period` individual 24h periods the same way: if every one of them has its own mean `Text` above `T_ref_Cooling_Season`, the day is tagged `"Cooling"`. If neither all-days condition holds, the day is `"Intermediate"`. Note this checks each 24h period on its own, not a single `HDD_period`/`CDD_period`-day trailing average.

**Why.** This tag determines, in `reference_temperature_profiles.R` (phase 11), whether a "heating" or "intermediate" day receives the `Service_AT_Low_Sched_HDD` band adjustment during Scheduling, and whether a "cooling" or "intermediate" day receives the `Service_AT_High_Sched_CDD` adjustment.

---

## Phase 9 — Future price matrices (`full_market_information_setup.R`)

**What it does.** Builds `full_market_information`, a list of 13 data frames (one per price signal: 4 for energy — `Elec_unit_cost_import_buy/import_sell/export_buy/export_sell_df` —, one for the distribution rate — `Elec_unit_cost_distribution_df`, used only by `reward_function()` via `resolve_marginal_context()` for the base energy term, never for flexibility — see `01_Agent_Comments/20260722c_Plan_Costes_Distribucion_Recompensa.md` — and 8 for flexibility — `Flex_unit_cost_down/up_com/exec_buy/sell_df` —, see `energy_price_signals_setup.R` just before this in the pipeline, sourced after `flexibility_generation.R` and before this phase, which derives the 12 buy/sell price columns in `Main_df` from `Elec_unit_cost_buy`/`Elec_unit_cost_distribution` and the 4 legacy `Flex_unit_cost_*` columns — `Elec_unit_cost_distribution` itself already exists directly in `Main_df`, with no need for derivation), each with **one row per market event** (a `MarketUTC` interval in which Scheduling or Piloting is active — not one row per interval of the full grid) and one column per "step ahead" (`"0"` to `as.character(max_steps_ahead-1)`), where column `j` is the average price of the interval `j` market-resolution steps ahead of the event itself.

1. Computes `max_steps_ahead`: for each configured market (in `parameters$market_config_scheduling`/`_piloting`), the hours between its bid time and the end of its optimization horizon are `end + end_optimization + closure`; the maximum over all of them, expressed in `market_resolution`-minute steps and **rounded up** (`ceiling()`, fixed this session — it used to truncate with `as.integer()` and could lose the last partial step), gives `max_steps_ahead`.
2. Builds `Main_df$MarketUTC` (if it does not already exist) — each `Main_df` timestamp "floored" to the `market_resolution`-minute grid. Defines `market_time_full` (all unique grid intervals, used only to compute averages and column offsets) and `market_event_time` (only the intervals where `Sched_Market_Name` or `Pilot_Market_Name` are active, via `is_market_active()`) — this second vector is what defines the actual rows of the matrices.
3. Computes, for each price signal, the average per interval of the full grid (`rowsum(...) / group_count`, via the internal function `avg_by_market()`).
4. Initializes the 13 matrices to `NA_real_` (a shared `NA` template for all 13, for efficiency).
5. Fills each column `j` with the average price of the interval located `j` steps ahead of each event (clamped to the last available interval with `pmin(...)` if the horizon runs past the end of the series).

**Why.** These matrices are the only source of "current market" prices used by `resolve_marginal_context()` and `integrate_market_process()` (phase 12) to economically value each Scheduling/Piloting decision without having to recompute averages over `Main_df` at every step of the loop.

---

## Phase 10 — Market commitment matrices (`market_commitments_setup.R`)

**What it does.** Builds `market_commitments`, a list of 10 data frames (`Elec_buy/sell/net_plan_df`, their 3 `_flex` equivalents, `Elec_flex_buy/sell_plan_df`, `Elec_Cost_plan_df`, `Elec_flex_Cost_plan_df`), with the same shape as `full_market_information` (one row per market event, columns `"0"..(max_steps_ahead-1)`), but initialized to **0** (not `NA`), because they represent accumulated commitments that the simulation loop will progressively add to. If `max_steps_ahead` does not already exist in the environment (in case this script were run in isolation), it recomputes it with the same logic as phase 9, as a safeguard.

**Why.** It is the market's "accounting ledger": every time Scheduling or Piloting modify the energy plan of a future interval, the difference (`delta_E`, `delta_C`) is accumulated here (`integrate_market_process()`, phase 12), separating energy bought, sold, net, with/without flexibility, and the associated monetary cost/revenue.

---

## Phase 11 — Reference temperature profiles (`reference_temperature_profiles.R`)

**What it does.** Generates 4 comfort-band columns in `Main_df`:
- `Service_T_Low/High`: the "service" band (`Occupancy == 1`) or "setback" band (`Occupancy == 0`), taken directly from `parameters$reward`.
- `Scheduling_T_Low/High`: same as `Service_T_Low/High`, except during Scheduling (`Scheduling == 1`), where it is relaxed: in heating-type climates (`Overall_Climate %in% c("Heating","Intermediate")`), `Service_AT_Low_Sched_HDD` is added to the lower limit; in cooling-type climates (`"Cooling","Intermediate"`), `Service_AT_High_Sched_CDD` is subtracted from the upper limit.

**Why.** `Service_T_Low/High` is the comfort band that `period_calculation()` uses in `"execution"` context (the actually executed trajectory); `Scheduling_T_Low/High` is the one used in `"plan"`/`"plan_flex"` context (what the optimizer sees while planning) — this way the optimizer can plan with a looser band during Scheduling without relaxing the comfort actually required in execution.

---

## Phase 12 — Main simulation loop (`simulation.R`)

This is, by far, the longest and most complex block. Before starting the loop:

- **`Main_df` formatting**: creates, set to 0, any column listed in `parameters$needed_cols` that does not yet exist, and converts all numeric columns (except `time`/`MarketUTC`) to `double`, to avoid type errors when `period_calculation()`/`implement_control_step()` write non-integer values into columns created as integers.
- **Model initialization**: sets the initial state values in row 1 (`Ti_exec[1]`, `Te_exec[1]`, `Ti_plan[1]`, `Te_plan[1]`, `Ti_plan_flex[1]`, `Te_plan_flex[1]`, `Q_heat_exec[1]`, `Q_cool_exec[1]`) from `parameters$model$Ti_0/Te_0/Qh_0/Qc_0`. `Ti`/`Te` are the only documented exception to the generic `initial_value = 0` in the `Simulation_Variables_Building.txt` registry (see Phase 2 above): their real row 1 always comes from here, not from `generate_system_df()`'s default value.
- **`simulation_control`**: a control object with two index sub-lists (`indexes_global`, relative to the full `Main_df`; `indexes_local`, relative to the `period_chunk` trimmed for each market process), a `parameters` sub-list (the 12 `Sched_*`/`Pilot_*` columns of the current row), `evaluation$optimization_aim`, `flexibility$flexibility_event_length/flexibility`, and `calculation_mode` (default 1 = Setpoint). `Main_df$MarketUTC` and `market_time` are recalculated (the full ordered grid of market intervals, used to resolve column offsets in the phase 9-10 matrices).

### The main loop

This is a `for (CONT_003 in 1:n_steps)` loop: it runs once for every row of `Main_df`, in order.

**0. Loading market parameters for the current row.** Copies the 12 `Sched_*`/`Pilot_*` columns of row `CONT_003` into `simulation_control$parameters`.

**1. Scheduling process (conditional).** Only runs if `is_market_active(Main_df$Sched_Market_Name[CONT_003])` (function `03_Functions/is_market_active.R`: true if the value, after `trimws`, is not `NA`, `""`, nor `"0"`). If active:

  1. **Indices**: resolves, via `resolve_market_index()` (`03_Functions/`), the position in `Main_df$time` of `Sched_Market_Bid_time` (→ `i0`), `Sched_Market_Period_Begin` (→ `i_begin_horizon`), `Sched_Optimization_Horizon` (→ `i_end_horizon`) and `Sched_Market_Period_End` (→ `i_end_control`); derives from these the `idx_period`/`idx_horizon`/`idx_ctrl` ranges (global, over `Main_df`, and local, over the `period_chunk` trimmed next).
  2. **Forecast context**: `context_forecast_step()` (`03_Functions/`) generates `Text_forec`/`SolarR_forec` for all of `idx_period`. If `parameters$forecast$forecast_type == "inaccurate"`, it delegates to `imperfect_forecast()` (`03_Functions/`), which blends the actual future value with a historical average of the same weekdays over the previous `n_days_back` days, with a weight that grows linearly across the horizon (0% history at the start, `forecast_weight_history` at the end) — this simulates a weather forecast that becomes progressively less reliable the further ahead it looks. Writes the result to `Main_df$Text_forec/SolarR_forec`.
  3. **Subset**: trims `period_chunk <- Main_df[idx_period, ]` (the full window of this market's optimization horizon).
  4. **Market execution**:
     - `resolve_marginal_context()` (`03_Functions/`) — computes, **before** this market optimizes anything, the already-existing base commitment (`E_orig_base_by_market`, sum of `Main_df$Elec_total_plan` per target interval) and the explicit flexibility commitment (`E_orig_expflex_by_market`, sum of `Main_df$Elec_flex_plan`), together with the current market prices (buy/sell, flexibility up/down) per target interval. This is the fixed "reference point" against which every candidate the GA tries will be valued marginally.
     - `run_market_process(prefix = "Sched", ...)` (`03_Functions/`) — the orchestrator of a complete market process:
       - Validates that the index ranges are coherent (if not, `stop()`).
       - Resolves this specific market's aim via `map_optimization_aim()` and sets it in `parameters$control$optimization_aim` / `simulation_control$evaluation$optimization_aim`.
       - **Initialization period** (if `i0 < i_begin_horizon`, i.e. if there is a gap between the bid time and the actual start of the control period): fills in default setpoints wherever they are missing or at 0/`NA`, and calls `implement_control_step()` (`03_Functions/`) — which in turn calls `period_calculation()` — to simulate that "bridge" segment with the default values, and injects the result into `period_chunk`.
       - **Optimization** (over `idx_horizon`, the actual control horizon), according to the resolved aim:
         - `"energy"` / `"flexibility"` → `optimize_control_step()` (`03_Functions/`), detailed below.
         - `"operation"` → calls `period_calculation()` directly with `calculation_mode = 1`, context `"plan"` (no real optimization: it simply runs with the setpoints already present).
         - `"operationflex"` → calls `evaluate_control()` directly (bypassing the GA).
         - Any other value → `stop()`.
       - Injects the resulting `_plan`/`_plan_flex` columns back into `period_chunk`, in the `idx_ctrl` rows.
     - `integrate_market_process(prefix = "Sched", ...)` (`03_Functions/`) — the "accounting" step that:
       1. Locates this event's row in the `full_market_information`/`market_commitments` matrices (`row_m`) and the target intervals covered by `idx_ctrl` (`idx_target_market`).
       2. Aggregates (SUMS) the commitment **before** (`Main_df` as it was) and **after** (the `results_df` that `run_market_process()` just returned) per market interval, for base energy, energy with flexibility, and explicit flexibility.
       3. Accumulates the difference (`delta_E`) in `market_commitments$Elec_net/buy/sell_plan_df` (and their `_flex` equivalents, and `Elec_flex_buy/sell_plan_df`).
       4. Writes the absolute value of the `_plan`/`_plan_flex` columns into `Main_df` (this is what leaves a visible trace of the Scheduling step in `Main_df` itself).
       5. For Scheduling it always computes the differential cost of the base energy (`propagate_differential_cost()` → `calc_differential_cost()`), accumulating it in `market_commitments$Elec_Cost_plan_df` and distributing it, weighted by energy, over `Main_df$Elec_market_net_cost_h` in the 5-minute rows of the affected interval. It also distributes the same differential into its pure cost/revenue components (`split_differential_cost()`) and adds its total to the event's own row, `Main_df$Elec_purchase_cost_market`/ `Elec_sell_revenue_market` — see `01_Agent_Comments/20260725_Plan_Reporte_Costes_Mercados_Main_df.md`.
  5. **Index reset**: `reset_index_list()` (`03_Functions/`) sets to 0 all index fields of `indexes_global`/`indexes_local` except `n_steps` (which must survive the whole loop).

**2. Piloting process (conditional).** Structurally identical to Scheduling (same steps 0-5, same functions), but using the `Pilot_*` columns and `prefix = "Pilot"`. The only real functional difference is inside `integrate_market_process()`: when `prefix == "Pilot"`, besides the base-energy cost, it also values the cost of the flexibility-adjusted energy (`Elec_total_plan_flex`, also writing to `Main_df$Elec_market_net_cost_h` and adding its cost/revenue component to `Main_df$Elec_purchase_cost_market`/`Elec_sell_revenue_market`, the same criterion as Scheduling) **and** the cost/revenue of the explicit flexibility (`Elec_flex_plan`, at the effective up/down prices `p_up`/`p_down`, writing to `Main_df$Elec_flex_commitment_revenue_h` and adding its cost/revenue component to `Main_df$Elec_flex_purchase_cost_market`/`Elec_flex_sell_revenue_market`) — Scheduling never trades explicit flexibility, only Piloting does.

**`optimize_control_step()`** (called from `run_market_process()` for the `"energy"`/`"flexibility"` aims, in both processes):
- Temporarily replaces `Text`/`SolarR` in `period_chunk` with their forecast versions (`Text_forec`/`SolarR_forec`) — the optimizer never sees the real weather, only its forecast.
- Depending on `parameters$control$control_type`:
  - `"setpoints"` → `optimize_setpoints()` (`03_Functions/`): a real-valued-encoding GA with `2 × horizon` genes (the first `horizon` are heating setpoints, the next `horizon` are cooling setpoints), bounded by `set_point_range_heating/cooling`. Fitness: `fitness_funct_optimize_setpoint()` → `convert_setpoints()` (applies a symmetric ±`Deadband/2` deadband) → `evaluate_control()` → scalar reward. If `parameters$debug_and_config$parallel == 1`, it sets up a `doParallel`/`parallel` cluster (`clusterExport()` of every needed function and object, including recompiling the C++ module on each worker via `clusterEvalQ(Rcpp::sourceCpp(...))`) and tears it down when finished.
  - `"modes"` (the active mode in the repo's current configuration, `12_Control_parameters.csv: control_type=modes`) → `optimize_modes()` (`03_Functions/`): the same real-valued GA but with **custom operators** (`ga_population_int`, `ga_crossover_int`, `ga_mutation_int`, defined in the same file) that force each gene to an integer mode index in `[1, n_modes]` (no one-hot encoding nor artificial clamping). Fitness: `fitness_funct_optimize_mode()` → `maxmode()` (pairs the mode vector with `target_periods`) → `convert_modes_to_setpoints()` (`merge()` against the `parameters$setpoint_modes` table to resolve each mode index to a `heating`/`cooling` pair, then applies the same deadband) → `evaluate_control()` → scalar reward. Same parallelization logic as `optimize_setpoints()`.
  - Any other value → `stop()`.
- After obtaining the optimal `set_point_actual` (from either of the two paths), it calls `evaluate_control()` once more with that setpoint already fixed, to obtain the final `period_chunk` (under forecast) that will be returned.

**`evaluate_control()`** (`03_Functions/`, the evaluation core reused both by the GA and by the final step of `optimize_control_step()`):
1. `period_calculation(..., calculation_mode = 1, calculation_context = "plan", set_point_df = ...)` — simulates the building under forecast with the candidate setpoint, writing `_plan` columns.
2. `initialize_plan_flex_columns()` (`03_Functions/`) — copies each `_plan` column to its `_plan_flex` equivalent (starting point before exploring flexibility).
3. `reward_function()` (`03_Functions/`) — computes the reward; see detail below.
4. If the aim is `"flexibility"`/`"operationflex"`: for each market slot of the horizon (skipping those with no planned energy or whose downward flexibility price is 0), it tries expanding a flexibility event by incorporating consecutive slots (`flex_evaluation()` followed by `reward_function()`), and keeps the expansion with the highest reward (early stop if it stops improving or if the flexibility price runs out).

**`flex_evaluation()`** (`03_Functions/`): reduces `Q_heat_plan_flex`/ `Q_cool_plan_flex` within the flexibility event window (`Q_*_plan · (1 - flexibility)`, with a minimum-flexibility correction), simulates that window (plus recovery and thermal stabilization) with `period_calculation(..., calculation_mode = vector 2/1, calculation_context = "plan_flex")` — mode 2 (Heat Input) during the event and the recovery, mode 1 (Setpoint) during stabilization — and reconciles the result back into the full `period_chunk`.

**`period_calculation()`** (`03_Functions/`, with no calls to other R functions except `period_simulation_cpp()` in C++): validates context and setpoints, extracts the 24 physical model parameters, builds vectors from `period_chunk` (using columns with the `_exec`, `_plan`, or `_plan_flex` suffix depending on `calculation_context`, via `col_sfx <- switch(calculation_context, "execution" = "_exec", "plan" = "_plan", "plan_flex" = "_plan_flex")` — a single line that determines every column name read/written by the rest of the function), applies the supplied `set_point_df` (one per `MarketUTC`) if there is one, and delegates **all the physical calculation** to `period_simulation_cpp()` — the C++ engine for the 2C thermal model with hysteresis, heat-pump curve, ventilation-resistance/shading selection, and electricity/comfort calculation — returning `Ti`/`Te`/`Act_heat`/`Act_cool`/`Q_heat`/`Q_cool`/`Elec_heat`/`Elec_cool`/ `Elec_total`/`Comfort`, which are written back into `period_chunk` with the corresponding suffix (e.g. `Ti_exec`, `Ti_plan`, or `Ti_plan_flex`). The physical core **computes no economic cost at all** (`Elec_Cost` is not part of its signature): that valuation is always resolved afterwards, in R, via `reward_function()` (`"plan"`/`"plan_flex"` contexts) or via `calc_differential_cost()` inside `implement_control_step()` (`"execution"` context, see below).

**`reward_function()`** (`03_Functions/`): computes `delta_t` (minutes) per row. `marginal_context` is mandatory — the function fails with `stop()` if it is `NULL` (there is no longer a context-less fallback calculation: it was removed because it could silently mask a broken `marginal_context` chain). It values the **marginal** energy cost: `compute_marginal_energy_cost()` (`03_Functions/`) aggregates the candidate energy (`Elec_total_plan`) per market interval and calls `calc_differential_cost()` (`03_Functions/`) with the 4 energy price signals (`P_import_buy`/`P_import_sell`/`P_export_buy`/`P_export_sell`, provided by `marginal_context`) to obtain the differential cost against the `E_orig_base_by_market` fixed before optimizing — the result is concentrated in the last row of `period_chunk$Elec_Cost_plan` (an internal/transient column of `reward_function()`, unrelated to any persistent `Main_df` column — the equivalent persisted cost, `Main_df$Elec_market_net_cost_h`, is resolved later, independently, in `integrate_market_process()`; so that the overall total remains correct). In `"flexibility"`/`"operationflex"` mode, it also computes `Elec_flex_plan = Elec_total_plan - Elec_total_plan_flex` and values its marginal revenue the same way (with the 4 flexibility signals `p_up_buy`/`p_up_sell`/`p_down_buy`/`p_down_sell`), writing to `Elec_flex_revenue_plan`. In addition, always (in both modes, only for the base energy term, never for flexibility — see `01_Agent_Comments/20260722c_Plan_Costes_Distribucion_Recompensa.md`), `compute_marginal_distribution_cost()` (`03_Functions/`) values the marginal distribution cost: unlike `compute_marginal_energy_cost()`, it does not use `calc_differential_cost()` — the buy/sell/unbuy/unsell casuistry collapses into a single formula, `distribution_rate · (|E_new| − |E_orig|)` (growing the commitment, buying or selling more, always adds cost; shrinking it, unbuying or unselling, always reduces it; crossing sign resolves itself, with no explicit branches) — result concentrated in the last row of `period_chunk$Elec_Cost_distribution_plan` (also transient, not persisted in `Main_df` or in `market_commitments`). The final reward is `Alpha_Service_Min × Performance − Elec_Cost_plan − Elec_Cost_distribution_plan [+ Elec_flex_revenue_plan]`, where `Performance` penalizes with `-1` every `delta_t` in which, while occupied, comfort is not met.

**`calc_differential_cost()`** (`03_Functions/`): given a net commitment `E_orig → E_new` and four asymmetric prices (`P_import_buy`/`P_import_sell`/`P_export_buy`/`P_export_sell` — "buy" is a new commitment, "sell" undoes part or all of a previous commitment, within each import/export regime), computes the cost (positive = payment, negative = revenue) of that transition: within the same sign, the growing segment is valued at the "new" price and the shrinking one at the "undo" price; when crossing zero, the previous commitment is fully undone at its "undo" price and the new one is valued in full at its "new" price. With the 4 prices collapsed into pairs (buy = sell within each regime), this reproduces exactly the previous 2-price criterion; a flexibility call maps its own up/down prices onto these same 4 arguments.

**3. Execution process (always).** Unlike Scheduling/Piloting, this block runs at **every** step of the loop, unconditionally. It sets `i0 = CONT_003`, `i1 = min(CONT_003+1, n_steps)` (only the immediate next step — execution never looks more than one step ahead). If `i0 != i1` (i.e. except at the last row of `Main_df`, where there is no "next step" to pair with):
1. Trims `period_chunk` to `idx_period` (2 rows: the current one and the next one).
2. `implement_control_step(..., calculation_context = "execution")` (`03_Functions/`) → `period_calculation()` — simulates the building with the **real** weather (not forecast) and the setpoints already decided (`STP_*_plan`, copied to the execution columns `STP_*_exec` inside `period_calculation()` when `calculation_context == "execution"`), advancing the real physical state (`Ti_exec`, `Te_exec`, ...) by one step. Since `period_calculation()` computes no cost (see above), `implement_control_step()` then resolves `Main_df$Elec_deviations_net_cost_h` for the new rows by calling `calc_differential_cost()` with `E_orig = Elec_total_plan` (the last plan in force for that row) and `E_new = Elec_total_exec`, thereby valuing the **deviation** from the schedule (not the fully executed energy from scratch) at the row's own 4 energy price signals. In the same block, it also resolves `Main_df$Elec_cost_distr_h` for the new rows, as `Elec_unit_cost_distribution × |Elec_total_exec|` — the net of all electricity bought/sold in that hour (market and deviation combined, since `Elec_total_exec` is that net by construction, with no decomposition into two separate pieces the way energy has) — and finally `Main_df$Elec_net_cost_h = Elec_market_net_cost_h + Elec_deviations_net_cost_h` (the first term already accumulated in `Main_df` by any previous market decision for that row). See `01_Agent_Comments/20260725_Plan_Reporte_Costes_Mercados_Main_df.md`.
3. Copies back into `Main_df`, in the `idx_ctrl` rows, **only** the execution columns (explicitly excluding any `_plan`/`_plan_flex` column, which were already written in the corresponding market integration step).

**4. Progress tracking.** Computes elapsed/estimated remaining time and, if `verbose`, prints progress to the console.

**After the loop**: cleans up working variables (`simulation_control`, `timestamps`, `market_time`, etc.) and computes `execution_time$t_process` (total duration, used afterwards in `data_outputs.R`).

**Why (summary of phase 12).** This is the heart of the MPC: at every timestep it independently decides whether to **plan** (Scheduling/ Piloting, under forecast, with GA-optimized reward) and it always **executes** a real physical step with the real weather and the setpoints already decided. The strict separation between execution columns and `_plan`/`_plan_flex` columns is what allows comparing "what was planned" against "what was actually executed" in the same `Main_df`.

---

## Phase 13 — Results export (`data_outputs.R`)

**What it does.** Creates `paths$output_path` if it does not exist. Exports the complete `Main_df` to `Main_df_computed.csv` and `Main_df_computed.rds`. Builds `Sinthetized_df` (a summary row with the optimization parameters used, plus `Elec_total_exec`, `Elec_net_cost_h`, `Comfort_exec`, `Reward` — all summed over the whole `Main_df` — and `execution_time$t_process`) and exports it to `Sinthetized_df_computed.csv`/`.rds`.

**Why.** It is the pipeline's single output point; all subsequent analysis (`20_GUI/` GUIs, analysis notebooks) starts from these files.

---

## Scope notes

- This document describes the **normal** execution path of `Main.R` with the repository's current configuration (`Complex_Market_Config = "yes"`, `control_type = "modes"`, `Price_emulation = 1`, `parallel = 1`). The alternative branches (basic market mode, `control_type = "setpoints"`, `"inaccurate"` forecast, `parallel = 0`) are likewise described in each section, but flagged as such.
- `Main_SCC.R` / `31_SCC_Simulation/` **do not exist** in this repository. The residual references to "Main_SCC.R" in script headers (`simulation.R`, `climate_priority.R`, `generate_occupancy_profiles.R`, `generate_scheduling_profiles.R`, `reference_temperature_profiles.R`, `load_all_parameters.R`, `initialization.R`) were cleaned up during the 2026-07-25 header audit (see `01_Agent_Comments/20260725_Revision_Completa_Codigo.md`).
- Per the user's explicit instruction, this document neither proposes nor applies any change to `reward_function.R` or to the known gap in `Main_df$Reward` (it is never populated for the actual execution trajectory, only for the `_plan`/`_plan_flex` columns via `evaluate_control()`); it is described here exactly as it behaves today.
