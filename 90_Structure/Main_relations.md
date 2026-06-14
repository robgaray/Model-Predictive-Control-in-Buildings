# Main_relations

Hierarchical relation graph for scripts and functions initiated by Main.R.

## Main.R (depth 0)

```         
Main.R
├── initialization.R (04_Scripts)
│   ├── initialization.R (03_Functions)
│   └── initialization()
│       └── Sources all 03_Functions/*.R
│           ├── load_parameters.R
│           ├── validate_Main_df.R
│           ├── validate_parameter_config.R
│           ├── load_control_parameters.R
│           ├── load_optimization_parameters.R
│           ├── load_market_parameters.R
│           ├── load_debug_and_config_parameters.R
│           ├── context_forecast_step.R
│           ├── is_market_active.R
│           ├── resolve_market_index.R
│           ├── map_optimization_aim.R
│           ├── run_market_process.R
│           ├── implement_control_step.R
│           ├── optimize_control_step.R
│           ├── optimize_setpoints.R
│           ├── optimize_modes.R
│           ├── fitness_funct_optimize_setpoint.R
│           ├── fitness_funct_optimize_mode.R
│           ├── convert_setpoints.R
│           ├── convert_modes_to_setpoints.R
│           ├── maxmode.R
│           ├── evaluate_control.R
│           ├── period_calculation.R
│           ├── reward_function.R
│           ├── flex_evaluation.R
│           └── imperfect_forecast.R
│
├── load_all_parameters.R
│   ├── load_03_physical_properties.R
│   │   ├── validate_parameter_config()
│   │   └── validate_physical_properties()
│   ├── load_04_use_patterns.R
│   ├── load_11_model_parameters.R
│   │   ├── validate_parameter_config()
│   │   ├── validate_model_parameters()
│   │   └── compute_Rvent()
│   ├── load_18_reward_parameters.R
│   │   └── validate_parameter_config()
│   ├── load_19_forecast_parameters.R
│   │   └── validate_parameter_config()
│   ├── load_12_control_parameters.R
│   │   ├── validate_parameter_config()
│   │   └── load_control_parameters()
│   ├── load_13_modes_setpoints.R
│   ├── load_14_optimization_parameters.R
│   │   ├── validate_parameter_config()
│   │   └── load_optimization_parameters()
│   ├── load_15_market_config.R
│   │   ├── validate_parameter_config()
│   │   ├── load_market_parameters()
│   │   └── map_optimization_aim()
│   ├── load_16_market_config_scheduling.R
│   ├── load_17_market_config_piloting.R
│   └── load_30_debug_and_config.R
│       ├── validate_parameter_config()
│       └── load_debug_and_config_parameters()
│
├── market_columns_setup.R
│
├── price_emulation.R [conditional: Price_emulation == 1]
│
├── generate_occupancy_profiles.R
│
├── generate_scheduling_profiles.R
│
├── climate_priority.R
│
├── reference_temperature_profiles.R
│
├── simulation.R ── MAIN LOOP (per MarketUTC row; uses simulation_control object)
│   │               simulation_control$flexibility holds flexibility_event_length and flexibility
│   │               simulation_control$calculation_mode holds the computation mode (default: 1)
│   │               each row runs: Scheduling (if active), Piloting (if active), Execution (always)
│   │               inspection_step.R sourced at begin/end of each process when CONT_003 in inspection_range
│   ├── inspection_step.R [conditional: CONT_003 in inspection_range]
│   │       Dumps Main_df snapshot and generates two-panel diagnostic plot
│   ├── is_market_active()
│   ├── resolve_market_index()
│   ├── run_market_process()
│   │   ├── is_market_active()
│   │   ├── resolve_market_index()
│   │   ├── map_optimization_aim()
│   │   ├── context_forecast_step()
│   │   │   └── imperfect_forecast() [if forecast_type == "inaccurate"]
│   │   ├── implement_control_step() [INITIALIZE phase]
│   │   │   │   reads calculation_mode from simulation_control$calculation_mode
│   │   │   └── period_calculation()
│   │   └── optimize_control_step()
│   │       ├── optimize_setpoints() [if control_type == "setpoints"]
│   │       │   ├── GA::ga()
│   │       │   │   └── fitness_funct_optimize_setpoint()
│   │       │   │       ├── convert_setpoints()
│   │       │   │       └── evaluate_control()
│   │       │   │           ├── period_calculation()
│   │       │   │           ├── initialize_plan_flex_columns()
│   │       │   │           ├── flex_evaluation() [if flexibility]
│   │       │   │           │   │   reads flexibility_event_length and flexibility
│   │       │   │           │   │   from simulation_control$flexibility
│   │       │   │           │   └── period_calculation()
│   │       │   │           └── reward_function()
│   │       ├── optimize_modes() [if control_type == "modes"]
│   │       │   ├── GA::ga()
│   │       │   │   └── fitness_funct_optimize_mode()
│   │       │   │       ├── maxmode()
│   │       │   │       ├── convert_modes_to_setpoints()
│   │       │   │       └── evaluate_control()
│   │       │   │           ├── period_calculation()
│   │       │   │           ├── initialize_plan_flex_columns()
│   │       │   │           ├── flex_evaluation() [if flexibility]
│   │       │   │           │   │   reads flexibility_event_length and flexibility
│   │       │   │           │   │   from simulation_control$flexibility
│   │       │   │           │   └── period_calculation()
│   │       │   │           └── reward_function()
│   │       │   ├── maxmode() [final]
│   │       │   └── convert_modes_to_setpoints() [final]
│   │       └── evaluate_control() [final evaluation]
│   │           ├── period_calculation()
│   │           ├── initialize_plan_flex_columns()
│   │           ├── flex_evaluation() [if flexibility]
│   │           │   └── period_calculation()
│   │           └── reward_function()
│   │
│   ├── implement_control_step() [IMPLEMENT phase]
│   │   │   reads calculation_mode from simulation_control$calculation_mode
│   │   └── period_calculation()
│
└── data_outputs.R
```

------------------------------------------------------------------------

[Back to README](../README.md)
