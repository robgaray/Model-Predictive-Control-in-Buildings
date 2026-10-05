# Code structure

This page explains how the simulation code is laid out, how one piece of code calls the next, and where to read the detail of each piece.

Every piece of code that `Main.R` reaches, directly or through another piece, has its own page under [99_Readme/code](code/). There are 125 of them.

## How the code is organised

The simulation lives under `30_Simulation/`. Three folders hold code:

- `30_Simulation/Main.R` is the entry point. It is the only file meant to be run directly.
- `30_Simulation/04_Scripts/` holds the scripts. A script is sourced, runs top to bottom and leaves its results in the calling environment. There are 37 of them.
- `30_Simulation/03_Functions/` holds the functions. A function is called with arguments and returns a value. There are 86 of them.
- `30_Simulation/03_1_Functions_Cpp/` holds the C++ module that carries the inner simulation loop.

The other folders under `30_Simulation/` hold data (`01_Data/`), configuration (`02_Config/`) and results (`90_Output/`); they hold no code.

## The general flow

`Main.R` sources 16 scripts, numbered in the order it runs them, one after another, and does almost nothing else itself. Read top to bottom, it is the whole simulation. Its code is split into four blocks of numbered steps:

- **[A. Initialization & parameter loading](code/Main__A.md)**
    - **1.** Initialization &mdash; [01_initialization.R](code/01_initialization.md)
    - **2.** Load data and model parameters &mdash; [02_load_all_parameters.R](code/02_load_all_parameters.md)
- **[B. Pre-processing](code/Main__B.md)**
    - [B.1. Random seed](code/Main__B_1.md)
        - **3.** Fix the random seed (reproducibility of the whole run) &mdash; inline code in Main.R
    - [B.2. Climate and period](code/Main__B_2.md)
        - **4.** Climate priority (before subsetting, needs full-year trailing averages) &mdash; [03_climate_priority.R](code/03_climate_priority.md)
        - **5.** Subset Main_df by month / period &mdash; [04_subset_main_df.R](code/04_subset_main_df.md)
    - [B.3. Profiles](code/Main__B_3.md)
        - **6.** Generate occupancy profiles &mdash; [05_generate_occupancy_profiles.R](code/05_generate_occupancy_profiles.md)
        - **7.** Generate scheduling profiles &mdash; [06_generate_scheduling_profiles.R](code/06_generate_scheduling_profiles.md)
        - **8.** Reference temperature profiles &mdash; [07_reference_temperature_profiles.R](code/07_reference_temperature_profiles.md)
    - [B.4. Markets and prices](code/Main__B_4.md)
        - **9.** Initialise market columns in Main_df &mdash; [08_market_columns_setup.R](code/08_market_columns_setup.md)
        - **10.** Flexibility generation (conditional) &mdash; [09_flexibility_price_emulation.R](code/09_flexibility_price_emulation.md)
        - **11.** Energy/flexibility price signals (buy/sell derivation) &mdash; [10_energy_price_signals_setup.R](code/10_energy_price_signals_setup.md)
        - **12.** Build future-horizon price matrices &mdash; [11_full_market_information_setup.R](code/11_full_market_information_setup.md)
        - **13.** Initialise market output matrices (market commitments) &mdash; [12_market_commitments_setup.R](code/12_market_commitments_setup.md)
        - **14.** Initialise the economic analysis accumulators &mdash; [13_economic_analysis_setup.R](code/13_economic_analysis_setup.md)
- **[C. Simulation](code/Main__C.md)**
    - **15.** Perform simulation (calls to external script) &mdash; [14_simulation.R](code/14_simulation.md)
- **[D. Post-process & Export](code/Main__D.md)**
    - **16.** Complete the economic analysis (execution phase and fractions) &mdash; [15_economic_analysis_finalize.R](code/15_economic_analysis_finalize.md)
    - **17.** Export results to files &mdash; [16_data_outputs.R](code/16_data_outputs.md)

The detail of the entry point itself is in [Main.R](code/Main.md).

![General flow of Main.R](code/Main.jpg)

## How these pages are made

These pages are generated from the code, not written by hand. The call lists are read from the code itself, and the rest is taken from each file's own header, so a page cannot drift from what its code does.

That also means an edit made here is lost the next time they are generated. To change a page, change the header of the code it documents, and generate the pages again.

## How to read a page

Every page follows the same shape:

- **Function** — what the piece does, as the file describes it in its own header.
- **Called by** — the pieces that call this one. The entry point is the only page with nothing here.
- **What it calls, in order of appearance** — the pieces this one calls, in the order they appear in the code. When a piece is called from several places, the number of call sites is given.
- **Input data** and **Output data** — the inputs and outputs declared in the file header.
- **Other notes** — anything else the header carries: the code outline, usage, exceptions, sign conventions.
- **Diagram** — a block diagram, described below.

A piece that calls more than six others is split into blocks, so that no single page has to be read against a long list. `14_simulation.R` is the exception: its loop is documented on one page and one diagram. The blocks are listed on the piece's own page.

## How to read a diagram

Each page carries a block diagram in black and white:

- The **centre** block is the piece the page documents.
- On the **right** are the pieces it calls, top to bottom in the order they are called. Each call leaves the centre block at its own height, so a piece called several times is reached by several lines while its block is drawn once. Inside a loop (`for`, `while`, `repeat`) a piece is drawn with one line only, however many times the loop body calls it.
- On the **left** are the pieces that call it.

A piece that is split into blocks is drawn against its blocks, not against every item it calls; each block has its own page and diagram. The same holds for the pieces whose code is written in lettered blocks, such as `Main.R` and `02_load_all_parameters.R`: their diagram shows their blocks, and a block that is split again shows its parts.

The labels leave out the folder of each piece: every script sits in `30_Simulation/04_Scripts/` and every function in `30_Simulation/03_Functions/`.

Each diagram is stored twice, as a `.jpg` that the page embeds and as a `.svg` for printing or editing. Both are A4 width.

## Index

### Entry point

- [Main.R](code/Main.md)

### Scripts

- [01_initialization.R](code/01_initialization.md)
- [02_load_all_parameters.R](code/02_load_all_parameters.md)
- [03_climate_priority.R](code/03_climate_priority.md)
- [04_subset_main_df.R](code/04_subset_main_df.md)
- [05_generate_occupancy_profiles.R](code/05_generate_occupancy_profiles.md)
- [06_generate_scheduling_profiles.R](code/06_generate_scheduling_profiles.md)
- [07_reference_temperature_profiles.R](code/07_reference_temperature_profiles.md)
- [08_market_columns_setup.R](code/08_market_columns_setup.md)
- [09_flexibility_price_emulation.R](code/09_flexibility_price_emulation.md)
- [10_energy_price_signals_setup.R](code/10_energy_price_signals_setup.md)
- [11_full_market_information_setup.R](code/11_full_market_information_setup.md)
- [12_market_commitments_setup.R](code/12_market_commitments_setup.md)
- [13_economic_analysis_setup.R](code/13_economic_analysis_setup.md)
- [14_simulation.R](code/14_simulation.md)
- [15_economic_analysis_finalize.R](code/15_economic_analysis_finalize.md)
- [16_data_outputs.R](code/16_data_outputs.md)
- [assemble_main_df.R](code/assemble_main_df.md)
- [load_01_computing_parameters.R](code/load_01_computing_parameters.md)
- [load_01_optimization_parameters.R](code/load_01_optimization_parameters.md)
- [load_02_control.R](code/load_02_control.md)
- [load_03_market_config.R](code/load_03_market_config.md)
- [load_03_physical_properties.R](code/load_03_physical_properties.md)
- [load_04_market_config_scheduling.R](code/load_04_market_config_scheduling.md)
- [load_05_market_config_piloting.R](code/load_05_market_config_piloting.md)
- [load_06_energy_price_parameters.R](code/load_06_energy_price_parameters.md)
- [load_07_flexibility_price_emulation.R](code/load_07_flexibility_price_emulation.md)
- [load_08_flexibility_event_configuration.R](code/load_08_flexibility_event_configuration.md)
- [load_09_reward_parameters.R](code/load_09_reward_parameters.md)
- [load_10_operational_temperature_corrections.R](code/load_10_operational_temperature_corrections.md)
- [load_11_model_parameters.R](code/load_11_model_parameters.md)
- [load_12_temperature_setpoints.R](code/load_12_temperature_setpoints.md)
- [load_13_modes_setpoints.R](code/load_13_modes_setpoints.md)
- [load_14_use_patterns.R](code/load_14_use_patterns.md)
- [load_15_forecast_parameters.R](code/load_15_forecast_parameters.md)
- [load_16_debug_and_config.R](code/load_16_debug_and_config.md)
- [load_energy_prices_df.R](code/load_energy_prices_df.md)
- [load_meteo_df.R](code/load_meteo_df.md)

### Functions

- [accumulate_market_operation.R](code/accumulate_market_operation.md)
- [aggregate_by_market_slot.R](code/aggregate_by_market_slot.md)
- [allocate_flex_events_per_day.R](code/allocate_flex_events_per_day.md)
- [apply_commitment_margin.R](code/apply_commitment_margin.md)
- [apply_revenue_discount.R](code/apply_revenue_discount.md)
- [build_market_timeline.R](code/build_market_timeline.md)
- [build_system_lock_caps.R](code/build_system_lock_caps.md)
- [calc_differential_cost.R](code/calc_differential_cost.md)
- [check_recovery_convergence.R](code/check_recovery_convergence.md)
- [compute_Rvent.R](code/compute_Rvent.md)
- [compute_available_segments.R](code/compute_available_segments.md)
- [compute_marginal_distribution_cost.R](code/compute_marginal_distribution_cost.md)
- [compute_marginal_energy_cost.R](code/compute_marginal_energy_cost.md)
- [compute_marginal_flex_revenue.R](code/compute_marginal_flex_revenue.md)
- [compute_max_steps_ahead.R](code/compute_max_steps_ahead.md)
- [compute_recovery_energy_cost.R](code/compute_recovery_energy_cost.md)
- [context_forecast_step.R](code/context_forecast_step.md)
- [continue_standing_tail.R](code/continue_standing_tail.md)
- [convert_modes_to_setpoints.R](code/convert_modes_to_setpoints.md)
- [convert_setpoints.R](code/convert_setpoints.md)
- [derive_flex_itineraries.R](code/derive_flex_itineraries.md)
- [evaluate_control.R](code/evaluate_control.md)
- [first_by_slot.R](code/first_by_slot.md)
- [fitness_funct_optimize_mode.R](code/fitness_funct_optimize_mode.md)
- [fitness_funct_optimize_setpoint.R](code/fitness_funct_optimize_setpoint.md)
- [flex_evaluation_down.R](code/flex_evaluation_down.md)
- [flex_evaluation_up.R](code/flex_evaluation_up.md)
- [flex_refused.R](code/flex_refused.md)
- [flex_window_is_feasible.R](code/flex_window_is_feasible.md)
- [ga_crossover_int.R](code/ga_crossover_int.md)
- [ga_mutation_int.R](code/ga_mutation_int.md)
- [ga_population_int.R](code/ga_population_int.md)
- [generate_flexibility_actions_df.R](code/generate_flexibility_actions_df.md)
- [generate_flexibility_events.R](code/generate_flexibility_events.md)
- [generate_meteo_transformations_df.R](code/generate_meteo_transformations_df.md)
- [generate_system_df.R](code/generate_system_df.md)
- [get_validation_bounds.R](code/get_validation_bounds.md)
- [hand_over_window_tail.R](code/hand_over_window_tail.md)
- [hold_standing_window.R](code/hold_standing_window.md)
- [imperfect_forecast.R](code/imperfect_forecast.md)
- [imperfect_price_forecast.R](code/imperfect_price_forecast.md)
- [implement_control_step.R](code/implement_control_step.md)
- [initialization.R](code/initialization.md)
- [integrate_market_process.R](code/integrate_market_process.md)
- [is_market_active.R](code/is_market_active.md)
- [load_control_parameters.R](code/load_control_parameters.md)
- [load_debug_and_config_parameters.R](code/load_debug_and_config_parameters.md)
- [load_flexibility_event_parameters.R](code/load_flexibility_event_parameters.md)
- [load_market_config_table.R](code/load_market_config_table.md)
- [load_market_parameters.R](code/load_market_parameters.md)
- [load_optimization_parameters.R](code/load_optimization_parameters.md)
- [load_temperature_setpoint_parameters.R](code/load_temperature_setpoint_parameters.md)
- [map_optimization_aim.R](code/map_optimization_aim.md)
- [market_event_index.R](code/market_event_index.md)
- [market_price_history.R](code/market_price_history.md)
- [market_slot_index.R](code/market_slot_index.md)
- [maxmode.R](code/maxmode.md)
- [optimize_control_step.R](code/optimize_control_step.md)
- [optimize_modes.R](code/optimize_modes.md)
- [optimize_setpoints.R](code/optimize_setpoints.md)
- [period_calculation.R](code/period_calculation.md)
- [place_flex_candidate.R](code/place_flex_candidate.md)
- [pre_horizon_window_tails.R](code/pre_horizon_window_tails.md)
- [price_variation_at_lead.R](code/price_variation_at_lead.md)
- [propagate_differential_cost.R](code/propagate_differential_cost.md)
- [propagate_unit_value.R](code/propagate_unit_value.md)
- [read_and_validate_parameter_csv.R](code/read_and_validate_parameter_csv.md)
- [reconstruct_flex_phases.R](code/reconstruct_flex_phases.md)
- [reset_index_list.R](code/reset_index_list.md)
- [resolve_flex_up_system.R](code/resolve_flex_up_system.md)
- [resolve_marginal_context.R](code/resolve_marginal_context.md)
- [resolve_market_index.R](code/resolve_market_index.md)
- [revenue_discount_factor.R](code/revenue_discount_factor.md)
- [reward_function.R](code/reward_function.md)
- [run_market_process.R](code/run_market_process.md)
- [safe_fraction.R](code/safe_fraction.md)
- [split_market_operation.R](code/split_market_operation.md)
- [sum_by_slot.R](code/sum_by_slot.md)
- [try_flex_echo.R](code/try_flex_echo.md)
- [validate_Main_df.R](code/validate_Main_df.md)
- [validate_dataframe_config.R](code/validate_dataframe_config.md)
- [validate_model_parameters.R](code/validate_model_parameters.md)
- [validate_parameter_config.R](code/validate_parameter_config.md)
- [validate_physical_properties.R](code/validate_physical_properties.md)
- [validate_time_grid.R](code/validate_time_grid.md)
- [value_flex_operation.R](code/value_flex_operation.md)

### C++ module

- [period_simulation_cpp.cpp](code/period_simulation_cpp.md)

---

[Back to the main README](../README.md)
