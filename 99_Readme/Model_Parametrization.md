# Model Parametrization

## Introduction

This computational code has many parameters that can be modified to adapt the model to different buildings, contexts, and simulation settings. This section describes the main parameters of the model and how they can be modified.

## Parameter Files

All configuration parameters are stored as CSV files in `01_Simulation/02_Config/`. Each file follows a `Parameter,Value` format and controls a specific aspect of the simulation. The parameter files are presented in subsections below.

Please be aware that this file reports on the parameter files. For a detailed definition of models to be parametrized, please refer to in [Model.md](Model.md).

### model_parameters.csv — Building Physics & HVAC

Contains the physical and thermal parameters of the building and HVAC system, including:

-   **Building thermal properties**: Internal thermal mass (`Ci`), external thermal mass (`Ce`), internal-external thermal resistance (`Rie`), external-ambient resistance (`Rea`), window area (`Aw`), and envelope area (`Ae`).
-   **Solar control**: Shading factors (`Shading_0`, `Shading_1`) and the temperature trigger for shading activation (`Setpoint_Shading1`).
-   **Heat pump — Heating**
    -   Temperature difference thresholds (`AT_hp_heat_1`, `AT_hp_heat_2`)
    -   Heating power at each stage (`Q_hp_heat_1`, `Q_hp_heat_2`)
    -   COP coefficients (`COP_hp_heat_1_coef1`, `COP_hp_heat_1_coef2`, `COP_hp_heat_1_coef3`, `COP_hp_heat_2`)
    -   and supply temperature (`Tsup_hp_heat`).
-   **Heat pump — Cooling**: Cooling parameters (`AT_hp_cool`, `Q_hp_cool`, `COP_hp_cool`).
-   **Ventilation**: Ventilation resistance parameters (`Rvent01`, `Rvent1`, `Rvent2`) and ventilation temperature setpoint (`Setpoint_Rvent1`).
-   **State initialization**: Initial indoor temperature (`Ti_0`), envelope temperature (`Te_0`), heating power (`Qh_0`), and cooling power (`Qc_0`).

### control_parameters.csv — Control Parameters

Contains HVAC control settings:

-   **Setpoint ranges**: Minimum and maximum heating and cooling setpoints (`set_point_range_heating_low`, `set_point_range_heating_high`, `set_point_range_cooling_low`, `set_point_range_cooling_high`).
-   **Hysteresis & defaults**: Temperature deadband (`Deadband`), default heating and cooling setpoints, default operating mode.
-   **Control type**: `control_type` — 1 for mode-based optimization, 2 for setpoint-based optimization.
-   **Optimization aim**: `optimization_aim` — 1 for energy-only optimization, 2 for flexibility optimization.
-   **Flexibility parameters**:
    -   Maximum event length (`flexibility_event_length_max`)
    -   Number of flexibility splits (`flexibility_splits`)
    -   Recovery timespan (`flexibility_recover_timespan`)
    -   Thermal stabilization time (`thermal_stabilization_timespan`)
    -   Flexibility commitment level (`flexibility_commitment`)
    -   Minimum flexibility (`minimum_flexibility`)
    -   and minimum spare capacity (`minimum_spare_capacity`)

### optimization_parameters.csv — Genetic Algorithm & MPC Horizon

Contains parameters for the genetic algorithm and the MPC optimization horizons:

-   **Genetic Algorithm**: Population size (`population_size`), number of iterations/generations (`iteration_number`), number of runs (`run_number`), crossover probability (`pcrossover`), and mutation probability (`pmutation`).
-   **MPC Horizon**: Optimization horizon (`control_optimization_horizon`), implementation/control horizon (`control_implementation_horizon`), optimization anticipation (`control_optimization_anticipation`), and market resolution (`market_resolution`).

### forecast_parameters.csv — Weather Forecast Parameters

Controls how weather forecasts are used in the simulation:

-   **Forecast type**: `forecast_type` — 1 for inaccurate (historical-based) forecast, 2 for accurate (perfect) forecast.
-   **Inaccurate model settings**: Number of days of historical data used (`forecast_n_days_back`), weight assigned to history (`forecast_weight_history`), and default external temperature when no previous data is available (`t_ext_24h_default`).

### reward_parameters.csv — Reward Function Parameters

Defines the reward/penalty function used to evaluate optimization solutions:

-   `Alpha_confort`: Weight of comfort in the reward function (high values strongly penalize discomfort).
-   `confort_low` and `confort_high`: Lower and upper comfort bounds in °C.

### setpoint_modes.csv — Operating Modes Table

Defines a table of predefined operating modes, each with specific heating and cooling setpoints. Each row has a `mode` identifier and corresponding `heating` and `cooling` setpoint values.

### debug_and_config.csv — Debug & Configuration Flags

Controls the simulation scope and execution behavior:

-   `month_subset`: 0 for a full year simulation, 1–12 for a specific month.
-   `period_subset`: Subset of timesteps to simulate (0 for all).
-   `verbose`: 1 to enable verbose output, 0 to disable.
-   `parallel`: 1 to enable parallel execution, 0 to disable.
-   `Price_emulation`: 1 to enable price emulation for flexibility, 0 to disable.

### flex_price_simulation.csv — Flexibility Price Simulation

Parameters for generating simulated flexibility price signals:

-   `Max_flex_periods_day`: Maximum number of flexibility periods per day.
-   `Max_flex_com_price`: Maximum commitment price (€/kWh).
-   `Max_flex_exec_price`: Maximum execution price (€/kWh).
-   `Max_flex_period_duration`: Maximum period duration (hours).
-   `Max_flex_probability`: Maximum flexibility activation probability.

## Graphic User Interface (GUI)

A Shiny-based Graphic User Interface is provided in `40_GUI/01_Configure_Simulation/GUI_config.R` to modify all the parameters described above without manually editing CSV files. This GUI is particularly useful for users who are not familiar with coding, as it provides an intuitive and user-friendly way to modify the parameters of the model and generate the necessary configuration files for the simulations.

### How to launch the GUI

From the repository root directory, run the following command in R:

``` r
shiny::runApp("40_GUI/01_Configure_Simulation")
```

Alternatively, open `40_GUI/01_Configure_Simulation/GUI_config.R` in RStudio and click the "Run App" button.

### GUI Structure

The GUI is organized into 8 tabs, one for each configuration file:

1.  **Model Parameters** — Building physics, solar control, heat pump (heating/cooling), ventilation, and state initialization.
2.  **Control Parameters** — Setpoint ranges, hysteresis, control type, optimization aim, and flexibility parameters.
3.  **Optimization Parameters** — Genetic algorithm settings and MPC horizon parameters.
4.  **Forecast Parameters** — Forecast type selection and inaccurate model parameters.
5.  **Reward Parameters** — Comfort penalty weights and bounds.
6.  **Setpoint Modes** — Editable table for defining operating modes (add/remove rows).
7.  **Debug & Config** — Simulation scope, execution flags, and price emulation toggle.
8.  **Flex Price Simulation** — Flexibility price generation parameters.

Each tab displays the current values from the corresponding CSV file. The user can edit the values and click the "Save" button to write the changes back to the CSV file.

### Screenshot

```{=html}
<!-- TODO: Insert a screenshot of the GUI here.
     To generate the screenshot:
     1. Launch the GUI with shiny::runApp("40_GUI/01_Configure_Simulation")
     2. Take a screenshot of the application window
     3. Save the screenshot as 99_Readme/GUI_config_screenshot.png
     4. Replace this comment block with:
        ![GUI Configuration Editor](GUI_config_screenshot.png)
-->
```

*A screenshot of the GUI Configuration Editor should be placed here. See the instructions above to generate it.*

------------------------------------------------------------------------

[Back to README](../README.md)
