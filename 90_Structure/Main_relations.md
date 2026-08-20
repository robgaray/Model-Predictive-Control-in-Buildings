# Main_relations

Hierarchical relation graph for scripts and functions initiated by Main.R.

## Main.R (depth 0)

```         
Main.R
├── initialization.R (04_Scripts)
│   ├── initialization.R (03_Functions)
│   └── initialization()
│       └── Sources all 03_Functions/*.R
│           ├── validate_Main_df.R
│           ├── validate_parameter_config.R
│           ├── validate_model_parameters.R
│           ├── validate_physical_properties.R
│           ├── compute_Rvent.R
│           ├── initialize_plan_flex_columns.R
│           ├── read_and_validate_parameter_csv.R
│           ├── load_market_config_table.R
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
│           │   └── period_simulation_cpp() (C++)
│           ├── reward_function.R
│           ├── flex_evaluation.R
│           ├── imperfect_forecast.R
│           ├── calc_differential_cost.R
│           ├── propagate_differential_cost.R
│           ├── integrate_market_process.R
│           ├── reset_index_list.R
│           ├── build_market_timeline.R
│           ├── resolve_marginal_context.R
│           ├── compute_marginal_energy_cost.R
│           ├── compute_marginal_distribution_cost.R
│           ├── validate_time_grid.R
│           ├── validate_dataframe_config.R
│           ├── generate_system_df.R
│           ├── generate_flexibility_actions_df.R
│           └── generate_meteo_transformations_df.R
│
├── load_all_parameters.R
│   ├── assemble_main_df.R (04_Scripts)
│   │   ├── load_meteo_df.R (04_Scripts)
│   │   │   ├── validate_time_grid()
│   │   │   └── validate_dataframe_config()
│   │   ├── load_energy_prices_df.R (04_Scripts)
│   │   │   ├── validate_time_grid()
│   │   │   └── validate_dataframe_config()
│   │   ├── generate_system_df()
│   │   │       reads Simulation_Variables_Building.txt, expands
│   │   │       scenario=yes variables into _exec/_plan/_plan_flex
│   │   ├── generate_flexibility_actions_df()
│   │   └── generate_meteo_transformations_df()
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
│   ├── load_21_energy_price_parameters.R
│   │   └── validate_parameter_config()
│   ├── load_22_flexibility_generation.R
│   │   └── validate_parameter_config()
│   └── load_30_debug_and_config.R
│       ├── validate_parameter_config()
│       └── load_debug_and_config_parameters()
│
├── market_columns_setup.R
│   └── build_market_timeline() [once for Scheduling, once for Piloting]
│           builds the role's market timeline (basic or complex mode) and
│           writes it into Main_df's Sched_*/Pilot_* columns
│
├── flexibility_generation.R [conditional: Price_emulation == 1]
│       Overwrites Flex_unit_cost_down_com/_down_exec/_up_com/_up_exec,
│       Flex_Probab, Flex_Act. Basic mode (Complex_Market_Config == "no"):
│       one independent candidate per period per calendar day, discretized
│       to market_resolution slots. Complex mode ("yes"):
│         └── generate_flexibility_events() [Scheduling markets in Bid_time
│               order (echo pass via try_flex_echo(), then new candidates
│               via compute_available_segments()/place_flex_candidate()),
│               then Piloting markets (candidates via place_flex_candidate(),
│               gated by an exponentially decreasing acceptance probability,
│               no overlap checking)] - see
│               01_Agent_Comments/20260723_Plan_Generacion_Flexibilidad.md
│
├── energy_price_signals_setup.R
│       Derives 12 buy/sell price signals in Main_df (4 energy, 8
│       flexibility) from Elec_unit_cost_buy/Elec_unit_cost_distribution
│       and the 4 legacy Flex_unit_cost_* signals (interim buy/sell
│       duplicates, no numeric change yet - see
│       01_Agent_Comments/20260720_Plan_Redefinicion_Precios_Energia.md
│       and 01_Agent_Comments/20260722b_Plan_Señales_por_Procedencia.md).
│       Elec_unit_cost_export_buy/_sell are reconstructed as
│       Elec_unit_cost_buy - Elec_unit_cost_distribution (algebraically
│       identical to the retired Elec_unit_cost_sell).
│
├── generate_occupancy_profiles.R
│
├── generate_scheduling_profiles.R
│
├── climate_priority.R
│
├── full_market_information_setup.R
│       Builds 13 future-horizon price matrices (Elec_unit_cost_import_buy_df,
│       _import_sell_df, _export_buy_df, _export_sell_df,
│       Elec_unit_cost_distribution_df, and the 8
│       Flex_unit_cost_{down,up}_{com,exec}_{buy,sell}_df), one row per
│       market event (Sched_ or Pilot_ market active), and max_steps_ahead
│
├── market_commitments_setup.R
│       Initialises 12 market output matrices (Elec_buy/sell/net_plan_df,
│       Elec_buy/sell/net_plan_flex_df,
│       Elec_flex_{down,up}_{sell,buy}_plan_df, Elec_Cost_plan_df,
│       Elec_flex_Cost_plan_df), one row per market event, all zeroed.
│       The flexibility commitment is kept as two independent legs
│       (down and up), each with its own sold and bought-back matrix;
│       the optimizer only offers down-flexibility today, so the two
│       up-leg matrices stay at 0 for the whole simulation
│
├── economic_analysis_setup.R
│       Builds the empty economic_analysis list: the market table (one row per
│       Scheduling and Piloting market event, plus one row per market
│       slot for Execution) and the slot table (one row per market
│       slot), plus the index sub-list used to attribute each traded
│       slot to the market that reports it
│
├── reference_temperature_profiles.R
│
├── simulation.R ── MAIN LOOP (per MarketUTC row; uses simulation_control object)
│   │               simulation_control$flexibility holds flexibility_event_length and flexibility
│   │               simulation_control$calculation_mode holds the computation mode (default: 1)
│   │               each row runs: Scheduling (if active), Piloting (if active), Execution (always)
│   ├── is_market_active()
│   ├── resolve_market_index()
│   ├── resolve_marginal_context() [once per Scheduling/Piloting process, before run_market_process()]
│   │       resolves E_orig and current-market prices per target market
│   │       interval, from Main_df in its pre-optimization state; reuses
│   │       integrate_market_process()'s own row/column resolution so both
│   │       agree on the same market event. Passed into run_market_process()
│   │       as marginal_context.
│   ├── run_market_process()
│   │   ├── is_market_active()
│   │   ├── resolve_market_index()
│   │   ├── map_optimization_aim()
│   │   ├── context_forecast_step()
│   │   │   └── imperfect_forecast() [if forecast_type == "inaccurate"]
│   │   ├── implement_control_step() [INITIALIZE phase]
│   │   │   │   reads calculation_mode from simulation_control$calculation_mode
│   │   │   └── period_calculation()
│   │   ├── period_calculation() [aim == "operation": no optimization]
│   │   ├── evaluate_control() [aim == "operationflex": no GA, flex-window search only]
│   │   │   ├── period_calculation()
│   │   │   ├── initialize_plan_flex_columns()
│   │   │   ├── flex_evaluation() [if flexibility]
│   │   │   │   └── period_calculation()
│   │   │   └── reward_function()
│   │   │       ├── compute_marginal_energy_cost() [marginal_context is mandatory]
│   │   │       │   │   values the base-energy term at the marginal
│   │   │       │   │   (differential) cash flow relative to
│   │   │       │   │   marginal_context's baseline
│   │   │       │   └── calc_differential_cost()
│   │   │       ├── compute_marginal_distribution_cost() [base-energy term only]
│   │   │       │       -distribution_rate * (abs(E_new)-abs(E_orig)); does not
│   │   │       │       use calc_differential_cost() (see
│   │   │       │       01_Agent_Comments/20260722c_Plan_Costes_Distribucion_Recompensa.md)
│   │   │       └── compute_marginal_flex_revenue() [flexibility/operationflex modes only]
│   │   │           │   values the explicit-flexibility term via its own
│   │   │           │   down/up-leg logic, not calc_differential_cost() - see
│   │   │           │   value_flex_operation()'s header for why
│   │   │           └── value_flex_operation()
│   │   └── optimize_control_step() [aim == "energy"/"flexibility": GA-driven]
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
│   │       │   │               ├── compute_marginal_energy_cost() [marginal_context is mandatory]
│   │       │   │               │       └── calc_differential_cost()
│   │       │   │               ├── compute_marginal_distribution_cost() [base-energy term only]
│   │       │   │               └── compute_marginal_flex_revenue() [flexibility/operationflex modes only]
│   │       │   │                       └── value_flex_operation()
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
│   │       │   │               ├── compute_marginal_energy_cost() [marginal_context is mandatory]
│   │       │   │               │       └── calc_differential_cost()
│   │       │   │               ├── compute_marginal_distribution_cost() [base-energy term only]
│   │       │   │               └── compute_marginal_flex_revenue() [flexibility/operationflex modes only]
│   │       │   │                       └── value_flex_operation()
│   │       │   ├── maxmode() [final]
│   │       │   └── convert_modes_to_setpoints() [final]
│   │       └── evaluate_control() [final evaluation]
│   │           ├── period_calculation()
│   │           ├── initialize_plan_flex_columns()
│   │           ├── flex_evaluation() [if flexibility]
│   │           │   └── period_calculation()
│   │           └── reward_function()
│   │               ├── compute_marginal_energy_cost() [marginal_context is mandatory]
│   │               │       └── calc_differential_cost()
│   │               ├── compute_marginal_distribution_cost() [base-energy term only]
│   │               └── compute_marginal_flex_revenue() [flexibility/operationflex modes only]
│   │                       └── value_flex_operation()
│   │
│   ├── implement_control_step() [IMPLEMENT phase]
│   │   │   reads calculation_mode from simulation_control$calculation_mode
│   │   │   also resolves Elec_deviations_net_cost_h (calc_differential_cost(),
│   │   │   E_orig=Elec_total_plan), Elec_cost_distr_h (inline) and
│   │   │   Elec_net_cost_h (inline sum) for calculation_context == "execution"
│   │   └── period_calculation()
│   │
│   ├── integrate_market_process() [Scheduling and Piloting result-integration]
│   │       column offsets via market_time (full market-resolution grid);
│   │       row lookup via full_market_information/market_commitments' own
│   │       (one row per market event) row set; SUM-aggregates base, flex-
│   │       adjusted and explicit-flexibility commitments; writes the
│   │       differential energy into market_commitments and the absolute
│   │       *_plan/*_plan_flex columns into Main_df. Registers explicit-
│   │       flexibility cash flow for both Scheduling and Piloting alike -
│   │       see 01_Agent_Comments/20260817_Auditoria_Consistencia_Economica.md
│   │       (finding 3)
│   │   ├── value_flex_operation() [explicit flexibility, once per target
│   │   │   interval, both Scheduling and Piloting]
│   │   │       resolves the down/up-leg sold/bought-back volumes and net
│   │   │       cash flow of this target interval's flexibility commitment
│   │   │       change; the volumes feed market_commitments$Elec_flex_
│   │   │       {down,up}_{sell,buy}_plan_df immediately, the cash flow is
│   │   │       stored for propagate_unit_value() below
│   │   ├── propagate_unit_value() [explicit flexibility, after the absolute
│   │   │   Main_df update, both Scheduling and Piloting]
│   │   │       accumulates the stored net cash flow into market_commitments$
│   │   │       Elec_flex_Cost_plan_df and propagates its unit value,
│   │   │       weighted by Elec_flex_plan, into Main_df$
│   │   │       Elec_flex_commitment_revenue_h; the same totals are added to
│   │   │       Main_df$Elec_flex_sell_revenue_market (+=) and
│   │   │       Elec_flex_purchase_cost_market (-=)
│   │   ├── propagate_differential_cost() [energy: base for Scheduling,
│   │   │   flex-adjusted for Piloting]
│   │   │       accumulates delta_C into market_commitments$Elec_Cost_plan_df
│   │   │       and propagates its unit cash flow, weighted by energy, into
│   │   │       Main_df$Elec_market_net_cost_h
│   │   │   ├── calc_differential_cost()
│   │   │   │       values a commitment transition at the current market's
│   │   │   │       asymmetric buy/sell prices
│   │   │   └── propagate_unit_value()
│   │   ├── split_market_operation() [energy, once per target interval]
│   │   │       resolves the same differential into the four elementary
│   │   │       operations (new buy, buy back, new sell, resell), with a
│   │   │       quantity and a value each; their values aggregate into the
│   │   │       totals added to Main_df$Elec_sell_revenue_market (+=) and
│   │   │       Elec_purchase_cost_market (-=)
│   │   └── accumulate_market_operation()
│   │           reports those four operations on the economic_analysis$market row
│   │           that owns the target slot and on that slot's economic_analysis$slot
│   │           row
│   └── reset_index_list()
│           zeroed index list applied (by partial named-list assignment,
│           preserving n_steps) after Scheduling, Piloting and Execution
│
├── economic_analysis_finalize.R
│   │   adds the execution phase to the economic_analysis tables and derives the
│   │   reported fractions, then drops the working columns and the index
│   └── split_market_operation()
│           splits the execution deviation (last committed plan ->
│           realized delivery) at each row's own prices
│
└── data_outputs.R
```

------------------------------------------------------------------------

[Back to README](../README.md)
