# Main_relations

Hierarchical relation graph of everything Main.R reaches, at full depth.

This page is generated from the code, not written by hand. Do not edit it: an edit made here is lost the next time it is generated.

Pieces reached from Main.R: 244 of 246.

A piece written in lettered blocks, such as run_simulation(), is drawn by its own blocks (A to D), the groups of steps a block has in its code, and the numbered steps inside them, as its code is split; a step carried out by inline code is a leaf. Below each step, a piece is expanded the first time it is reached, in the order its call sites appear. Later appearances are marked `[expanded under ...]`, naming where its subtree was written, and a call that would re-enter a branch already open is marked `[cycle]`. Every relation is drawn; only the repetition of a subtree already written is not.

```
Main.R
├── initialize_simulator.R (03_Functions)
│   ├── read_file_paths_table.R (03_Functions)
│   ├── build_config_paths.R (03_Functions)
│   │   └── read_file_paths_table.R (03_Functions)  [expanded under initialize_simulator.R (03_Functions)]
│   ├── initialization.R (03_Functions)
│   │   └── console_message.R (03_Functions)
│   │       └── console_time.R (03_Functions)
│   └── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
└── run_simulation.R (03_Functions)
    ├── A. Configuration and parameter loading
    │   ├── 1. Check the arguments and set the paths
    │   │   ├── apply_config_overrides.R (03_Functions)
    │   │   │   ├── resolve_config_key.R (03_Functions)
    │   │   │   │   └── read_file_paths_table.R (03_Functions)  [expanded under initialize_simulator.R (03_Functions)]
    │   │   │   ├── write_asset_template.R (03_Functions)
    │   │   │   │   ├── read_file_paths_table.R (03_Functions)  [expanded under initialize_simulator.R (03_Functions)]
    │   │   │   │   └── load_parameter_catalogue.R (03_Functions)
    │   │   │   │       ├── drop_unit_row.R (03_Functions)
    │   │   │   │       └── read_and_validate_parameter_csv.R (03_Functions)
    │   │   │   │           └── validate_parameter_config.R (03_Functions)
    │   │   │   └── split_config_sections.R (03_Functions)
    │   │   └── build_config_paths.R (03_Functions)  [expanded under initialize_simulator.R (03_Functions)]
    │   └── 2. Load data and model parameters
    │       └── load_all_parameters.R (03_Functions)
    │           ├── A. Internal parameters
    │           │   ├── 1. Validation configuration files
    │           │   │   └── load_parameter_catalogue.R (03_Functions)  [expanded under write_asset_template.R (03_Functions)]
    │           │   └── 2. Internal parameters
    │           │       └── load_internal_parameters.R (04_Scripts)
    │           │           ├── load_parameter_file.R (03_Functions)
    │           │           │   ├── read_and_validate_parameter_csv.R (03_Functions)  [expanded under load_parameter_catalogue.R (03_Functions)]
    │           │           │   └── type_parameter_values.R (03_Functions)
    │           │           ├── load_03_physical_properties.R (04_Scripts)
    │           │           │   ├── load_parameter_file.R (03_Functions)  [expanded under load_internal_parameters.R (04_Scripts)]
    │           │           │   └── validate_physical_properties.R (03_Functions)
    │           │           ├── load_16_debug_and_config.R (04_Scripts)
    │           │           │   └── load_parameter_file.R (03_Functions)  [expanded under load_internal_parameters.R (04_Scripts)]
    │           │           ├── load_needed_columns.R (03_Functions)
    │           │           │   ├── drop_unit_row.R (03_Functions)  [expanded under load_parameter_catalogue.R (03_Functions)]
    │           │           │   ├── variable_registry_columns.R (03_Functions)
    │           │           │   ├── model_type_contract.R (03_Functions)
    │           │           │   │   ├── building_model_contract.R (03_Functions)
    │           │           │   │   │   ├── load_building_parameters.R (03_Functions)
    │           │           │   │   │   │   ├── load_parameter_file.R (03_Functions)  [expanded under load_internal_parameters.R (04_Scripts)]
    │           │           │   │   │   │   ├── load_11_model_parameters.R (04_Scripts)
    │           │           │   │   │   │   │   ├── load_parameter_file.R (03_Functions)  [expanded under load_internal_parameters.R (04_Scripts)]
    │           │           │   │   │   │   │   ├── validate_model_parameters.R (03_Functions)
    │           │           │   │   │   │   │   │   └── get_validation_bounds.R (03_Functions)
    │           │           │   │   │   │   │   └── compute_Rvent.R (03_Functions)
    │           │           │   │   │   │   ├── load_13_modes_setpoints.R (04_Scripts)
    │           │           │   │   │   │   │   ├── split_config_sections.R (03_Functions)  [expanded under apply_config_overrides.R (03_Functions)]
    │           │           │   │   │   │   │   └── drop_unit_row.R (03_Functions)  [expanded under load_parameter_catalogue.R (03_Functions)]
    │           │           │   │   │   │   ├── load_14_use_patterns.R (04_Scripts)
    │           │           │   │   │   │   │   └── drop_unit_row.R (03_Functions)  [expanded under load_parameter_catalogue.R (03_Functions)]
    │           │           │   │   │   │   └── load_parameter_block.R (03_Functions)
    │           │           │   │   │   │       ├── split_config_sections.R (03_Functions)  [expanded under apply_config_overrides.R (03_Functions)]
    │           │           │   │   │   │       ├── validate_parameter_config.R (03_Functions)  [expanded under read_and_validate_parameter_csv.R (03_Functions)]
    │           │           │   │   │   │       └── type_parameter_values.R (03_Functions)  [expanded under load_parameter_file.R (03_Functions)]
    │           │           │   │   │   ├── building_variable_registry.R (03_Functions)
    │           │           │   │   │   ├── building_new_table.R (03_Functions)
    │           │           │   │   │   │   └── generate_variables_df.R (03_Functions)
    │           │           │   │   │   │       └── variable_registry_columns.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │           │   │   │   ├── prepare_climate.R (03_Functions)
    │           │           │   │   │   ├── building_initial_state.R (03_Functions)
    │           │           │   │   │   ├── building_prepare_period.R (03_Functions)
    │           │           │   │   │   │   ├── prepare_occupancy.R (03_Functions)
    │           │           │   │   │   │   ├── prepare_scheduling.R (03_Functions)
    │           │           │   │   │   │   └── prepare_comfort_bands.R (03_Functions)
    │           │           │   │   │   ├── building_gene_options.R (03_Functions)
    │           │           │   │   │   ├── decode_building_genes.R (03_Functions)
    │           │           │   │   │   │   ├── maxmode.R (03_Functions)
    │           │           │   │   │   │   └── convert_modes_to_setpoints.R (03_Functions)
    │           │           │   │   │   ├── lowest_mode_setpoints.R (03_Functions)
    │           │           │   │   │   ├── building_can_hold.R (03_Functions)
    │           │           │   │   │   ├── building_plan_start_state.R (03_Functions)
    │           │           │   │   │   ├── period_calculation.R (03_Functions)
    │           │           │   │   │   │   └── period_simulation_cpp.cpp (03_1_Functions_Cpp)
    │           │           │   │   │   │       ├── heat_pump_cop_cpp.h (03_1_Functions_Cpp)
    │           │           │   │   │   │       └── heat_pump_electricity_step.h (03_1_Functions_Cpp)
    │           │           │   │   │   ├── comfort_term.R (03_Functions)
    │           │           │   │   │   ├── flex_window_is_feasible.R (03_Functions)
    │           │           │   │   │   ├── building_slot_offer.R (03_Functions)
    │           │           │   │   │   │   └── resolve_flex_up_hvac.R (03_Functions)
    │           │           │   │   │   ├── flex_window_draft.R (03_Functions)
    │           │           │   │   │   │   ├── resolve_flex_up_hvac.R (03_Functions)  [expanded under building_slot_offer.R (03_Functions)]
    │           │           │   │   │   │   └── flex_commitment_profile.R (03_Functions)
    │           │           │   │   │   │       ├── building_margin_data.R (03_Functions)
    │           │           │   │   │   │       │   ├── heat_pump_cop.R (03_Functions)
    │           │           │   │   │   │       │   │   └── heat_pump_cop_cpp.h (03_1_Functions_Cpp)  [expanded under period_simulation_cpp.cpp (03_1_Functions_Cpp)]
    │           │           │   │   │   │       │   └── heat_pump_electricity.R (03_Functions)
    │           │           │   │   │   │       │       └── heat_pump_electricity_cpp.h (03_1_Functions_Cpp)
    │           │           │   │   │   │       │           └── heat_pump_electricity_step.h (03_1_Functions_Cpp)  [expanded under period_simulation_cpp.cpp (03_1_Functions_Cpp)]
    │           │           │   │   │   │       └── flex_up_power_limit.R (03_Functions)
    │           │           │   │   │   ├── apply_commitment_margin.R (03_Functions)
    │           │           │   │   │   │   └── apply_commitment_margin_cpp.h (03_1_Functions_Cpp)
    │           │           │   │   │   │       ├── heat_pump_cop_cpp.h (03_1_Functions_Cpp)  [expanded under period_simulation_cpp.cpp (03_1_Functions_Cpp)]
    │           │           │   │   │   │       └── heat_pump_electricity_step.h (03_1_Functions_Cpp)  [expanded under period_simulation_cpp.cpp (03_1_Functions_Cpp)]
    │           │           │   │   │   ├── building_margin_energy.R (03_Functions)
    │           │           │   │   │   │   └── heat_pump_electricity.R (03_Functions)  [expanded under building_margin_data.R (03_Functions)]
    │           │           │   │   │   ├── flex_evaluation.R (03_Functions)
    │           │           │   │   │   │   ├── flex_margined_profile.R (03_Functions)
    │           │           │   │   │   │   ├── resolve_flex_down_hvac.R (03_Functions)
    │           │           │   │   │   │   ├── build_hvac_lock_caps.R (03_Functions)
    │           │           │   │   │   │   ├── period_calculation.R (03_Functions)  [expanded under building_model_contract.R (03_Functions)]
    │           │           │   │   │   │   ├── flex_refused.R (03_Functions)
    │           │           │   │   │   │   ├── check_recovery_convergence.R (03_Functions)
    │           │           │   │   │   │   └── flex_window_is_feasible.R (03_Functions)  [expanded under building_model_contract.R (03_Functions)]
    │           │           │   │   │   ├── building_restate_systems.R (03_Functions)
    │           │           │   │   │   │   └── resolve_flex_up_hvac.R (03_Functions)  [expanded under building_slot_offer.R (03_Functions)]
    │           │           │   │   │   ├── building_hold_room.R (03_Functions)
    │           │           │   │   │   │   ├── heat_pump_cop.R (03_Functions)  [expanded under building_margin_data.R (03_Functions)]
    │           │           │   │   │   │   ├── resolve_flex_up_hvac.R (03_Functions)  [expanded under building_slot_offer.R (03_Functions)]
    │           │           │   │   │   │   ├── flex_up_power_limit.R (03_Functions)  [expanded under flex_commitment_profile.R (03_Functions)]
    │           │           │   │   │   │   └── heat_pump_electricity.R (03_Functions)  [expanded under building_margin_data.R (03_Functions)]
    │           │           │   │   │   ├── continue_standing_tail.R (03_Functions)
    │           │           │   │   │   │   ├── build_hvac_lock_caps.R (03_Functions)  [expanded under flex_evaluation.R (03_Functions)]
    │           │           │   │   │   │   └── period_calculation.R (03_Functions)  [expanded under building_model_contract.R (03_Functions)]
    │           │           │   │   │   ├── building_tail_state.R (03_Functions)
    │           │           │   │   │   ├── implement_control_step.R (03_Functions)
    │           │           │   │   │   │   ├── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
    │           │           │   │   │   │   └── period_calculation.R (03_Functions)  [expanded under building_model_contract.R (03_Functions)]
    │           │           │   │   │   └── hold_standing_window.R (03_Functions)
    │           │           │   │   │       └── building_hold_room.R (03_Functions)  [expanded under building_model_contract.R (03_Functions)]
    │           │           │   │   ├── photovoltaic_model_contract.R (03_Functions)
    │           │           │   │   │   ├── load_photovoltaic_parameters.R (03_Functions)
    │           │           │   │   │   │   └── load_parameter_file.R (03_Functions)  [expanded under load_internal_parameters.R (04_Scripts)]
    │           │           │   │   │   ├── photovoltaic_variable_registry.R (03_Functions)
    │           │           │   │   │   ├── photovoltaic_new_table.R (03_Functions)
    │           │           │   │   │   │   └── generate_variables_df.R (03_Functions)  [expanded under building_new_table.R (03_Functions)]
    │           │           │   │   │   ├── photovoltaic_generation.R (03_Functions)
    │           │           │   │   │   │   └── plane_of_array_irradiance.R (03_Functions)
    │           │           │   │   │   ├── photovoltaic_execute_step.R (03_Functions)
    │           │           │   │   │   │   └── photovoltaic_generation.R (03_Functions)  [expanded under photovoltaic_model_contract.R (03_Functions)]
    │           │           │   │   │   └── photovoltaic_solar_geometry.R (03_Functions)
    │           │           │   │   │       └── solar_position.R (03_Functions)
    │           │           │   │   └── battery_model_contract.R (03_Functions)
    │           │           │   │       ├── load_battery_parameters.R (03_Functions)
    │           │           │   │       │   └── load_parameter_file.R (03_Functions)  [expanded under load_internal_parameters.R (04_Scripts)]
    │           │           │   │       ├── battery_variable_registry.R (03_Functions)
    │           │           │   │       ├── battery_new_table.R (03_Functions)
    │           │           │   │       │   └── generate_variables_df.R (03_Functions)  [expanded under building_new_table.R (03_Functions)]
    │           │           │   │       ├── battery_initial_state.R (03_Functions)
    │           │           │   │       ├── battery_plan_start_state.R (03_Functions)
    │           │           │   │       ├── battery_simulate_itinerary.R (03_Functions)
    │           │           │   │       │   ├── battery_modes.R (03_Functions)
    │           │           │   │       │   ├── battery_mode_request.R (03_Functions)
    │           │           │   │       │   │   └── battery_modes.R (03_Functions)  [expanded under battery_simulate_itinerary.R (03_Functions)]
    │           │           │   │       │   └── battery_trajectory.R (03_Functions)
    │           │           │   │       │       └── battery_trajectory_cpp.cpp (03_1_Functions_Cpp)
    │           │           │   │       │           ├── battery_limits.h (03_1_Functions_Cpp)
    │           │           │   │       │           └── battery_step_terms.h (03_1_Functions_Cpp)
    │           │           │   │       ├── battery_execute_step.R (03_Functions)
    │           │           │   │       │   └── battery_simulate_itinerary.R (03_Functions)  [expanded under battery_model_contract.R (03_Functions)]
    │           │           │   │       ├── battery_stored_energy_change.R (03_Functions)
    │           │           │   │       ├── battery_window_feasible.R (03_Functions)
    │           │           │   │       ├── battery_slot_offer.R (03_Functions)
    │           │           │   │       ├── battery_window_draft.R (03_Functions)
    │           │           │   │       │   └── battery_factor_search.R (03_Functions)
    │           │           │   │       │       └── battery_factor_search_cpp.h (03_1_Functions_Cpp)
    │           │           │   │       │           ├── battery_limits.h (03_1_Functions_Cpp)  [expanded under battery_trajectory_cpp.cpp (03_1_Functions_Cpp)]
    │           │           │   │       │           ├── battery_step_terms.h (03_1_Functions_Cpp)  [expanded under battery_trajectory_cpp.cpp (03_1_Functions_Cpp)]
    │           │           │   │       │           ├── battery_recovery_correction_core.h (03_1_Functions_Cpp)
    │           │           │   │       │           │   └── battery_free_run.h (03_1_Functions_Cpp)
    │           │           │   │       │           └── battery_free_run.h (03_1_Functions_Cpp)  [expanded under battery_recovery_correction_core.h (03_1_Functions_Cpp)]
    │           │           │   │       ├── battery_margin_fit.R (03_Functions)
    │           │           │   │       ├── battery_window_contribution.R (03_Functions)
    │           │           │   │       │   ├── battery_recovery_correction.R (03_Functions)
    │           │           │   │       │   │   └── battery_recovery_correction_cpp.h (03_1_Functions_Cpp)
    │           │           │   │       │   │       ├── battery_limits.h (03_1_Functions_Cpp)  [expanded under battery_trajectory_cpp.cpp (03_1_Functions_Cpp)]
    │           │           │   │       │   │       ├── battery_step_terms.h (03_1_Functions_Cpp)  [expanded under battery_trajectory_cpp.cpp (03_1_Functions_Cpp)]
    │           │           │   │       │   │       └── battery_recovery_correction_core.h (03_1_Functions_Cpp)  [expanded under battery_factor_search_cpp.h (03_1_Functions_Cpp)]
    │           │           │   │       │   ├── flex_refused.R (03_Functions)  [expanded under flex_evaluation.R (03_Functions)]
    │           │           │   │       │   └── battery_draw_leg.R (03_Functions)
    │           │           │   │       │       └── battery_trajectory.R (03_Functions)  [expanded under battery_simulate_itinerary.R (03_Functions)]
    │           │           │   │       ├── battery_hold_room.R (03_Functions)
    │           │           │   │       ├── battery_window_hold.R (03_Functions)
    │           │           │   │       │   ├── battery_trajectory.R (03_Functions)  [expanded under battery_simulate_itinerary.R (03_Functions)]
    │           │           │   │       │   ├── battery_recovery_correction.R (03_Functions)  [expanded under battery_window_contribution.R (03_Functions)]
    │           │           │   │       │   ├── battery_factor_search.R (03_Functions)  [expanded under battery_window_draft.R (03_Functions)]
    │           │           │   │       │   └── battery_draw_leg.R (03_Functions)  [expanded under battery_window_contribution.R (03_Functions)]
    │           │           │   │       ├── battery_continue_window_tail.R (03_Functions)
    │           │           │   │       │   ├── battery_recovery_correction.R (03_Functions)  [expanded under battery_window_contribution.R (03_Functions)]
    │           │           │   │       │   └── battery_draw_leg.R (03_Functions)  [expanded under battery_window_contribution.R (03_Functions)]
    │           │           │   │       ├── battery_tail_state.R (03_Functions)
    │           │           │   │       ├── decode_battery_genes.R (03_Functions)
    │           │           │   │       └── battery_modes.R (03_Functions)  [expanded under battery_simulate_itinerary.R (03_Functions)]
    │           │           │   └── system_net_energy_columns.R (03_Functions)
    │           │           │       └── system_net_energy_column.R (03_Functions)
    │           │           └── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
    │           ├── B. Main_df
    │           │   ├── 3. Assemble Main_df
    │           │   │   └── assemble_main_df.R (04_Scripts)
    │           │   │       ├── load_meteo_df.R (04_Scripts)
    │           │   │       │   ├── validate_time_grid.R (03_Functions)
    │           │   │       │   └── validate_dataframe_config.R (03_Functions)
    │           │   │       ├── load_energy_prices_df.R (04_Scripts)
    │           │   │       │   ├── validate_time_grid.R (03_Functions)  [expanded under load_meteo_df.R (04_Scripts)]
    │           │   │       │   └── validate_dataframe_config.R (03_Functions)  [expanded under load_meteo_df.R (04_Scripts)]
    │           │   │       ├── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
    │           │   │       ├── console_time.R (03_Functions)  [expanded under console_message.R (03_Functions)]
    │           │   │       ├── generate_variables_df.R (03_Functions)  [expanded under building_new_table.R (03_Functions)]
    │           │   │       ├── generate_flexibility_actions_df.R (03_Functions)
    │           │   │       └── generate_meteo_transformations_df.R (03_Functions)
    │           │   └── 4. Validate Main_df
    │           │       └── validate_Main_df.R (03_Functions)
    │           │           └── get_validation_bounds.R (03_Functions)  [expanded under validate_model_parameters.R (03_Functions)]
    │           ├── C. Parameters
    │           │   ├── 5. Configuration files
    │           │   │   └── load_configuration_files.R (04_Scripts)
    │           │   │       ├── load_parameter_file.R (03_Functions)  [expanded under load_internal_parameters.R (04_Scripts)]
    │           │   │       ├── load_03_market_config.R (04_Scripts)
    │           │   │       │   ├── load_parameter_file.R (03_Functions)  [expanded under load_internal_parameters.R (04_Scripts)]
    │           │   │       │   └── map_optimization_aim.R (03_Functions)
    │           │   │       ├── load_04_market_config_scheduling.R (04_Scripts)
    │           │   │       │   └── load_market_config_table.R (03_Functions)
    │           │   │       │       ├── drop_unit_row.R (03_Functions)  [expanded under load_parameter_catalogue.R (03_Functions)]
    │           │   │       │       └── map_optimization_aim.R (03_Functions)  [expanded under load_03_market_config.R (04_Scripts)]
    │           │   │       ├── load_05_market_config_piloting.R (04_Scripts)
    │           │   │       │   └── load_market_config_table.R (03_Functions)  [expanded under load_04_market_config_scheduling.R (04_Scripts)]
    │           │   │       ├── load_12_asset_registry.R (04_Scripts)
    │           │   │       │   ├── drop_unit_row.R (03_Functions)  [expanded under load_parameter_catalogue.R (03_Functions)]
    │           │   │       │   ├── validate_parameter_config.R (03_Functions)  [expanded under read_and_validate_parameter_csv.R (03_Functions)]
    │           │   │       │   ├── read_file_paths_table.R (03_Functions)  [expanded under initialize_simulator.R (03_Functions)]
    │           │   │       │   ├── build_asset_paths.R (03_Functions)
    │           │   │       │   │   └── read_file_paths_table.R (03_Functions)  [expanded under initialize_simulator.R (03_Functions)]
    │           │   │       │   ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │       │   └── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
    │           │   │       └── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
    │           │   ├── 6. Relations between parameters
    │           │   │   ├── drop_unit_row.R (03_Functions)  [expanded under load_parameter_catalogue.R (03_Functions)]
    │           │   │   ├── read_file_paths_table.R (03_Functions)  [expanded under initialize_simulator.R (03_Functions)]
    │           │   │   └── validate_parameter_relations.R (03_Functions)
    │           │   └── 7. Recalculate T_ext_24h  [inline code in load_all_parameters.R]
    │           └── D. The tables of the assets
    │               └── 8. Build and validate the table of each asset
    │                   ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │                   ├── validate_asset_df.R (03_Functions)
    │                   ├── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
    │                   └── copy_asset_inputs.R (03_Functions)
    ├── B. Pre-processing
    │   ├── B.1. Random seed
    │   │   └── 3. Fix the random seed (reproducibility of the whole run)  [inline code in run_simulation.R]
    │   ├── B.2. Climate and period
    │   │   ├── 4. Climate priority (before subsetting, needs full-year trailing averages)
    │   │   │   └── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │   │   └── 5. Subset Main_df and the table of each asset by month / period
    │   │       ├── subset_period.R (03_Functions)
    │   │       └── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
    │   ├── B.3. Profiles
    │   │   └── 6. Profiles of each asset
    │   │       ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │   │       └── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
    │   └── B.4. Markets and prices
    │       ├── 7. Initialise market columns in Main_df, and the table of the
    │       │   ├── prepare_market_calendar.R (03_Functions)
    │       │   │   ├── build_market_timeline.R (03_Functions)
    │       │   │   └── validate_market_coverage.R (03_Functions)
    │       │   │       └── is_market_active.R (03_Functions)
    │       │   └── build_market_events.R (03_Functions)
    │       │       ├── is_market_active.R (03_Functions)  [expanded under validate_market_coverage.R (03_Functions)]
    │       │       └── instant_market_slot.R (03_Functions)
    │       ├── 8. Flexibility generation (conditional)
    │       │   └── prepare_flexibility_prices.R (03_Functions)
    │       │       ├── generate_flexibility_events.R (03_Functions)
    │       │       │   ├── is_market_active.R (03_Functions)  [expanded under validate_market_coverage.R (03_Functions)]
    │       │       │   ├── allocate_flex_events_per_day.R (03_Functions)
    │       │       │   ├── try_flex_echo.R (03_Functions)
    │       │       │   │   └── compute_available_segments.R (03_Functions)
    │       │       │   ├── compute_available_segments.R (03_Functions)  [expanded under try_flex_echo.R (03_Functions)]
    │       │       │   └── place_flex_candidate.R (03_Functions)
    │       │       └── place_flex_candidate.R (03_Functions)  [expanded under generate_flexibility_events.R (03_Functions)]
    │       ├── 9. Energy/flexibility price signals (buy/sell derivation)
    │       │   ├── prepare_energy_prices.R (03_Functions)
    │       │   └── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
    │       ├── 10. Build future-horizon price matrices
    │       │   └── prepare_market_information.R (03_Functions)
    │       │       ├── compute_max_steps_ahead.R (03_Functions)
    │       │       └── price_variation_at_lead.R (03_Functions)
    │       ├── 11. Initialise market output matrices (market commitments)
    │       │   └── prepare_commitments.R (03_Functions)
    │       │       └── compute_max_steps_ahead.R (03_Functions)  [expanded under prepare_market_information.R (03_Functions)]
    │       └── 12. Initialise the economic analysis accumulators
    │           └── prepare_economic_analysis.R (03_Functions)
    │               └── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
    ├── C. Simulation
    │   └── 13. Perform simulation
    │       └── simulate.R (03_Functions)
    │           ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           ├── market_event_index.R (03_Functions)
    │           │   └── instant_market_slot.R (03_Functions)  [expanded under build_market_events.R (03_Functions)]
    │           ├── start_worker_cluster.R (03_Functions)
    │           ├── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
    │           ├── console_time.R (03_Functions)  [expanded under console_message.R (03_Functions)]
    │           ├── run_market_role.R (03_Functions)
    │           │   ├── is_market_active.R (03_Functions)  [expanded under validate_market_coverage.R (03_Functions)]
    │           │   ├── resolve_market_index.R (03_Functions)
    │           │   ├── to_local_indexes.R (03_Functions)
    │           │   ├── context_forecast_step.R (03_Functions)
    │           │   │   └── imperfect_forecast.R (03_Functions)
    │           │   ├── copy_asset_inputs.R (03_Functions)  [expanded under load_all_parameters.R (03_Functions)]
    │           │   ├── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
    │           │   ├── build_market_piece.R (03_Functions)
    │           │   │   └── system_net_energy_columns.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   ├── resolve_marginal_context.R (03_Functions)
    │           │   │   ├── instant_market_slot.R (03_Functions)  [expanded under build_market_events.R (03_Functions)]
    │           │   │   ├── system_net_energy.R (03_Functions)
    │           │   │   │   └── system_net_energy_column.R (03_Functions)  [expanded under system_net_energy_columns.R (03_Functions)]
    │           │   │   ├── price_estimate_sources.R (03_Functions)
    │           │   │   ├── estimate_price_signal.R (03_Functions)
    │           │   │   └── revenue_discount_factor.R (03_Functions)
    │           │   ├── run_market_process.R (03_Functions)
    │           │   │   ├── map_optimization_aim.R (03_Functions)  [expanded under load_03_market_config.R (04_Scripts)]
    │           │   │   ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   ├── piece_asset_view.R (03_Functions)
    │           │   │   │   └── piece_asset_layout.R (03_Functions)
    │           │   │   │       ├── joined_column_order.R (03_Functions)
    │           │   │   │       └── system_net_energy_columns.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   ├── piece_absorb_asset.R (03_Functions)
    │           │   │   │   ├── system_net_energy_columns.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   └── sum_asset_energy.R (03_Functions)
    │           │   │   ├── pre_horizon_window_tails.R (03_Functions)
    │           │   │   │   └── reconstruct_flex_phases.R (03_Functions)
    │           │   │   ├── piece_rows.R (03_Functions)
    │           │   │   ├── asset_simulation_order.R (03_Functions)
    │           │   │   │   └── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   ├── write_rest_net.R (03_Functions)
    │           │   │   │   ├── system_net_energy_column.R (03_Functions)  [expanded under system_net_energy_columns.R (03_Functions)]
    │           │   │   │   └── sum_asset_energy.R (03_Functions)  [expanded under piece_absorb_asset.R (03_Functions)]
    │           │   │   ├── itinerary_columns.R (03_Functions)
    │           │   │   ├── piece_write_rows.R (03_Functions)
    │           │   │   │   ├── system_net_energy_columns.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   └── sum_asset_energy.R (03_Functions)  [expanded under piece_absorb_asset.R (03_Functions)]
    │           │   │   ├── derive_flex_itineraries.R (03_Functions)
    │           │   │   │   ├── itinerary_columns.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   ├── sum_asset_energy.R (03_Functions)  [expanded under piece_absorb_asset.R (03_Functions)]
    │           │   │   │   ├── piece_asset_view.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   ├── piece_absorb_asset.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   ├── piece_layout.R (03_Functions)
    │           │   │   │   │   └── piece_asset_layout.R (03_Functions)  [expanded under piece_asset_view.R (03_Functions)]
    │           │   │   │   ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   ├── system_flex_frame.R (03_Functions)
    │           │   │   │   │   ├── flex_refused.R (03_Functions)  [expanded under flex_evaluation.R (03_Functions)]
    │           │   │   │   │   ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   │   └── piece_asset_view.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   ├── system_flex_window.R (03_Functions)
    │           │   │   │   │   ├── system_flex_frame.R (03_Functions)  [expanded under derive_flex_itineraries.R (03_Functions)]
    │           │   │   │   │   ├── system_commitment_margin.R (03_Functions)
    │           │   │   │   │   │   ├── commitment_margin_bound.R (03_Functions)
    │           │   │   │   │   │   └── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   │   ├── piece_absorb_asset.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   │   ├── system_net_energy.R (03_Functions)  [expanded under resolve_marginal_context.R (03_Functions)]
    │           │   │   │   │   ├── system_flex_commitment.R (03_Functions)
    │           │   │   │   │   │   └── system_net_energy.R (03_Functions)  [expanded under resolve_marginal_context.R (03_Functions)]
    │           │   │   │   │   ├── commitment_margin_bound.R (03_Functions)  [expanded under system_commitment_margin.R (03_Functions)]
    │           │   │   │   │   ├── flex_refused.R (03_Functions)  [expanded under flex_evaluation.R (03_Functions)]
    │           │   │   │   │   └── choose_recovery.R (03_Functions)
    │           │   │   │   │       ├── system_stored_energy.R (03_Functions)
    │           │   │   │   │       │   └── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   │       ├── system_energy_rows.R (03_Functions)
    │           │   │   │   │       │   └── system_net_energy.R (03_Functions)  [expanded under resolve_marginal_context.R (03_Functions)]
    │           │   │   │   │       ├── flex_leg_reward_terms.R (03_Functions)
    │           │   │   │   │       │   ├── compute_marginal_flex_revenue.R (03_Functions)
    │           │   │   │   │       │   │   ├── aggregate_by_market_slot.R (03_Functions)
    │           │   │   │   │       │   │   ├── value_flex_operation.R (03_Functions)
    │           │   │   │   │       │   │   └── apply_revenue_discount.R (03_Functions)
    │           │   │   │   │       │   ├── compute_recovery_energy_cost.R (03_Functions)
    │           │   │   │   │       │   │   ├── market_slot_index.R (03_Functions)
    │           │   │   │   │       │   │   ├── aggregate_by_market_slot.R (03_Functions)  [expanded under compute_marginal_flex_revenue.R (03_Functions)]
    │           │   │   │   │       │   │   ├── calc_differential_cost.R (03_Functions)
    │           │   │   │   │       │   │   │   └── split_market_operation.R (03_Functions)
    │           │   │   │   │       │   │   └── apply_revenue_discount.R (03_Functions)  [expanded under compute_marginal_flex_revenue.R (03_Functions)]
    │           │   │   │   │       │   └── compute_stored_energy_value.R (03_Functions)
    │           │   │   │   │       └── apply_revenue_discount.R (03_Functions)  [expanded under compute_marginal_flex_revenue.R (03_Functions)]
    │           │   │   │   ├── system_flex_commitment.R (03_Functions)  [expanded under system_flex_window.R (03_Functions)]
    │           │   │   │   ├── choose_recovery.R (03_Functions)  [expanded under system_flex_window.R (03_Functions)]
    │           │   │   │   ├── reconstruct_flex_phases.R (03_Functions)  [expanded under pre_horizon_window_tails.R (03_Functions)]
    │           │   │   │   └── system_hold_window.R (03_Functions)
    │           │   │   │       ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │       ├── piece_asset_view.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │       ├── piece_absorb_asset.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │       └── choose_recovery.R (03_Functions)  [expanded under system_flex_window.R (03_Functions)]
    │           │   │   ├── hand_over_window_tail.R (03_Functions)
    │           │   │   │   ├── reconstruct_flex_phases.R (03_Functions)  [expanded under pre_horizon_window_tails.R (03_Functions)]
    │           │   │   │   ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   └── piece_asset_view.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   ├── committed_recovery_cost.R (03_Functions)
    │           │   │   │   ├── asset_simulation_order.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   ├── piece_asset_view.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   ├── write_rest_net.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   ├── piece_absorb_asset.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   ├── build_recovery_valuation.R (03_Functions)
    │           │   │   │   │   ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   │   └── build_reward_cache.R (03_Functions)
    │           │   │   │   │       ├── system_stored_energy.R (03_Functions)  [expanded under choose_recovery.R (03_Functions)]
    │           │   │   │   │       ├── system_energy_rows.R (03_Functions)  [expanded under choose_recovery.R (03_Functions)]
    │           │   │   │   │       ├── revenue_discount_factor.R (03_Functions)  [expanded under resolve_marginal_context.R (03_Functions)]
    │           │   │   │   │       ├── market_slot_index.R (03_Functions)  [expanded under compute_recovery_energy_cost.R (03_Functions)]
    │           │   │   │   │       ├── compute_marginal_energy_cost.R (03_Functions)
    │           │   │   │   │       │   ├── aggregate_by_market_slot.R (03_Functions)  [expanded under compute_marginal_flex_revenue.R (03_Functions)]
    │           │   │   │   │       │   ├── calc_differential_cost.R (03_Functions)  [expanded under compute_recovery_energy_cost.R (03_Functions)]
    │           │   │   │   │       │   └── apply_revenue_discount.R (03_Functions)  [expanded under compute_marginal_flex_revenue.R (03_Functions)]
    │           │   │   │   │       ├── compute_marginal_distribution_cost.R (03_Functions)
    │           │   │   │   │       │   ├── aggregate_by_market_slot.R (03_Functions)  [expanded under compute_marginal_flex_revenue.R (03_Functions)]
    │           │   │   │   │       │   └── apply_revenue_discount.R (03_Functions)  [expanded under compute_marginal_flex_revenue.R (03_Functions)]
    │           │   │   │   │       ├── compute_stored_energy_value.R (03_Functions)  [expanded under flex_leg_reward_terms.R (03_Functions)]
    │           │   │   │   │       ├── flex_leg_reward_terms.R (03_Functions)  [expanded under choose_recovery.R (03_Functions)]
    │           │   │   │   │       ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   │       └── piece_asset_view.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   ├── derive_flex_itineraries.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   ├── system_stored_energy.R (03_Functions)  [expanded under choose_recovery.R (03_Functions)]
    │           │   │   │   ├── build_reward_cache.R (03_Functions)  [expanded under build_recovery_valuation.R (03_Functions)]
    │           │   │   │   ├── system_energy_rows.R (03_Functions)  [expanded under choose_recovery.R (03_Functions)]
    │           │   │   │   └── flex_leg_reward_terms.R (03_Functions)  [expanded under choose_recovery.R (03_Functions)]
    │           │   │   ├── optimize_control_step.R (03_Functions)
    │           │   │   │   ├── optimize_modes.R (03_Functions)
    │           │   │   │   │   ├── chromosome_layout.R (03_Functions)
    │           │   │   │   │   │   └── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   │   ├── piece_working_columns.R (03_Functions)
    │           │   │   │   │   ├── piece_layout.R (03_Functions)  [expanded under derive_flex_itineraries.R (03_Functions)]
    │           │   │   │   │   ├── fitness_funct_optimize_mode.R (03_Functions)
    │           │   │   │   │   │   ├── decode_chromosome.R (03_Functions)
    │           │   │   │   │   │   │   └── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   │   │   └── evaluate_control.R (03_Functions)
    │           │   │   │   │   │       ├── asset_simulation_order.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   │   │       ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   │   │       ├── piece_asset_view.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   │   │       ├── write_rest_net.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   │   │       ├── piece_absorb_asset.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   │   │       ├── build_recovery_valuation.R (03_Functions)  [expanded under committed_recovery_cost.R (03_Functions)]
    │           │   │   │   │   │       ├── derive_flex_itineraries.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   │   │       ├── reconstruct_flex_phases.R (03_Functions)  [expanded under pre_horizon_window_tails.R (03_Functions)]
    │           │   │   │   │   │       ├── reward_function.R (03_Functions)
    │           │   │   │   │   │       │   ├── system_stored_energy.R (03_Functions)  [expanded under choose_recovery.R (03_Functions)]
    │           │   │   │   │   │       │   ├── build_reward_cache.R (03_Functions)  [expanded under build_recovery_valuation.R (03_Functions)]
    │           │   │   │   │   │       │   ├── piece_asset_view.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   │   │   │   │       │   ├── model_type_contract.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   │   │   │       │   ├── system_energy_rows.R (03_Functions)  [expanded under choose_recovery.R (03_Functions)]
    │           │   │   │   │   │       │   └── economic_terms.R (03_Functions)
    │           │   │   │   │   │       │       ├── apply_revenue_discount.R (03_Functions)  [expanded under compute_marginal_flex_revenue.R (03_Functions)]
    │           │   │   │   │   │       │       └── flex_leg_reward_terms.R (03_Functions)  [expanded under choose_recovery.R (03_Functions)]
    │           │   │   │   │   │       ├── piece_layout.R (03_Functions)  [expanded under derive_flex_itineraries.R (03_Functions)]
    │           │   │   │   │   │       ├── build_reward_cache.R (03_Functions)  [expanded under build_recovery_valuation.R (03_Functions)]
    │           │   │   │   │   │       └── system_flex_window.R (03_Functions)  [expanded under derive_flex_itineraries.R (03_Functions)]
    │           │   │   │   │   ├── ga_population_int.R (03_Functions)
    │           │   │   │   │   ├── ga_crossover_int.R (03_Functions)
    │           │   │   │   │   ├── ga_mutation_int.R (03_Functions)
    │           │   │   │   │   └── decode_chromosome.R (03_Functions)  [expanded under fitness_funct_optimize_mode.R (03_Functions)]
    │           │   │   │   └── evaluate_control.R (03_Functions)  [expanded under fitness_funct_optimize_mode.R (03_Functions)]
    │           │   │   ├── build_recovery_valuation.R (03_Functions)  [expanded under committed_recovery_cost.R (03_Functions)]
    │           │   │   ├── reward_function.R (03_Functions)  [expanded under evaluate_control.R (03_Functions)]
    │           │   │   ├── evaluate_control.R (03_Functions)  [expanded under fitness_funct_optimize_mode.R (03_Functions)]
    │           │   │   ├── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
    │           │   │   └── console_time.R (03_Functions)  [expanded under console_message.R (03_Functions)]
    │           │   ├── write_itineraries.R (03_Functions)
    │           │   │   └── itinerary_columns.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           │   ├── system_net_energy_column.R (03_Functions)  [expanded under system_net_energy_columns.R (03_Functions)]
    │           │   ├── apply_table_writes.R (03_Functions)
    │           │   │   ├── system_net_energy_columns.R (03_Functions)  [expanded under load_needed_columns.R (03_Functions)]
    │           │   │   └── sum_asset_energy.R (03_Functions)  [expanded under piece_absorb_asset.R (03_Functions)]
    │           │   ├── settle_market.R (03_Functions)
    │           │   │   ├── instant_market_slot.R (03_Functions)  [expanded under build_market_events.R (03_Functions)]
    │           │   │   ├── system_net_energy.R (03_Functions)  [expanded under resolve_marginal_context.R (03_Functions)]
    │           │   │   ├── value_flex_operation.R (03_Functions)  [expanded under compute_marginal_flex_revenue.R (03_Functions)]
    │           │   │   ├── add_to_table_cells.R (03_Functions)
    │           │   │   ├── propagate_unit_value.R (03_Functions)
    │           │   │   │   └── add_to_table_cells.R (03_Functions)  [expanded under settle_market.R (03_Functions)]
    │           │   │   ├── split_market_operation.R (03_Functions)  [expanded under calc_differential_cost.R (03_Functions)]
    │           │   │   ├── propagate_differential_cost.R (03_Functions)
    │           │   │   │   ├── calc_differential_cost.R (03_Functions)  [expanded under compute_recovery_energy_cost.R (03_Functions)]
    │           │   │   │   └── propagate_unit_value.R (03_Functions)  [expanded under settle_market.R (03_Functions)]
    │           │   │   └── accumulate_market_operation.R (03_Functions)
    │           │   │       └── add_to_table_cells.R (03_Functions)  [expanded under settle_market.R (03_Functions)]
    │           │   └── reset_index_list.R (03_Functions)
    │           ├── to_local_indexes.R (03_Functions)  [expanded under run_market_role.R (03_Functions)]
    │           ├── asset_simulation_order.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           ├── join_asset_tables.R (03_Functions)
    │           │   └── joined_column_order.R (03_Functions)  [expanded under piece_asset_layout.R (03_Functions)]
    │           ├── write_rest_net.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           ├── itinerary_columns.R (03_Functions)  [expanded under run_market_process.R (03_Functions)]
    │           ├── apply_table_writes.R (03_Functions)  [expanded under run_market_role.R (03_Functions)]
    │           ├── system_net_energy.R (03_Functions)  [expanded under resolve_marginal_context.R (03_Functions)]
    │           ├── settle_execution.R (03_Functions)
    │           │   └── calc_differential_cost.R (03_Functions)  [expanded under compute_recovery_energy_cost.R (03_Functions)]
    │           ├── reset_index_list.R (03_Functions)  [expanded under run_market_role.R (03_Functions)]
    │           └── console_duration.R (03_Functions)
    └── D. Post-process & Export
        ├── 14. Complete the economic analysis (execution phase and fractions)
        │   └── finalize.R (03_Functions)
        │       ├── split_market_operation.R (03_Functions)  [expanded under calc_differential_cost.R (03_Functions)]
        │       ├── sum_by_slot.R (03_Functions)
        │       ├── system_net_energy.R (03_Functions)  [expanded under resolve_marginal_context.R (03_Functions)]
        │       ├── first_by_slot.R (03_Functions)
        │       ├── safe_fraction.R (03_Functions)
        │       └── console_message.R (03_Functions)  [expanded under initialization.R (03_Functions)]
        ├── 15. Export results to files
        │   └── write_outputs.R (03_Functions)
        │       └── system_net_energy.R (03_Functions)  [expanded under resolve_marginal_context.R (03_Functions)]
        └── 16. Return the results  [inline code in run_simulation.R]
```
