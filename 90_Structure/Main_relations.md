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
│           ├── load_control_parameters.R
│           ├── load_optimization_parameters.R
│           ├── load_debug_and_config_parameters.R
│           ├── context_forecast_step.R
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
├── data_model_parameters.R
│   ├── validate_Main_df()
│   └── load_parameters() (×3: model, reward, forecast)
│
├── control_optimization_parameters.R
│   ├── load_control_parameters()
│   ├── load_optimization_parameters()
│   └── load_debug_and_config_parameters()
│
├── price_emulation.R [conditional: Price_emulation == 1]
│
├── simulation.R ── MAIN LOOP (per optimization timestep)
│   ├── context_forecast_step()
│   │   └── imperfect_forecast() [if forecast_type == "inaccurate"]
│   │
│   ├── implement_control_step() [INITIALIZE phase]
│   │   └── period_calculation()
│   │
│   ├── optimize_control_step()
│   │   ├── optimize_setpoints() [if control_type == "setpoint"]
│   │   │   ├── GA::ga()
│   │   │   │   └── fitness_funct_optimize_setpoint()
│   │   │   │       ├── convert_setpoints()
│   │   │   │       └── evaluate_control()
│   │   │   │           ├── period_calculation()
│   │   │   │           ├── flex_evaluation() [if flexibility]
│   │   │   │           │   └── period_calculation()
│   │   │   │           └── reward_function()
│   │   │   └── convert_setpoints() [final]
│   │   │
│   │   ├── optimize_modes() [if control_type == "modes"]
│   │   │   ├── GA::ga()
│   │   │   │   └── fitness_funct_optimize_mode()
│   │   │   │       ├── maxmode()
│   │   │   │       ├── convert_modes_to_setpoints()
│   │   │   │       └── evaluate_control()
│   │   │   │           ├── period_calculation()
│   │   │   │           ├── flex_evaluation() [if flexibility]
│   │   │   │           │   └── period_calculation()
│   │   │   │           └── reward_function()
│   │   │   ├── maxmode() [final]
│   │   │   └── convert_modes_to_setpoints() [final]
│   │   │
│   │   └── evaluate_control() [final evaluation]
│   │       ├── period_calculation()
│   │       ├── flex_evaluation() [if flexibility]
│   │       │   └── period_calculation()
│   │       └── reward_function()
│   │
│   └── implement_control_step() [IMPLEMENT phase]
│       └── period_calculation()
│
└── data_outputs.R
```

------------------------------------------------------------------------

[Back to README](../README.md)
