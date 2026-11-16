# period_calculation.R

**Function** &nbsp;·&nbsp; `30_Simulation/05_Models/01_Building/03_Functions/period_calculation.R`

## Function

This function performs the physical simulation of the building for a given period based on climate data and setpoint values. This function:

- runs over a dataframe
- defines control signals for each timestep and
- activates heating and cooling systems accordingly
- computes changes to the building thermal state
- calculates comfort level

This function performs no economic calculation: the cost of the electricity it computes is resolved elsewhere, by the reward of the planning contexts and by the settlement of the execution. A 2C simplified model is used, with a pseudo-static approach. Histeresis-based thermostatic control is used for heating and cooling systems. Occupancy-based ventilation is performed: the occupied rows are ventilated, and the unoccupied rows take infiltration or reinforced ventilation depending on T_ext_24h. Details of all this can be found in the readme file.

This function takes and returns dataframes, but uses vectors internally for faster computation.

## Called by

- [building_model_contract.R](building_model_contract.md)
- [continue_standing_tail.R](continue_standing_tail.md)
- [flex_evaluation.R](flex_evaluation.md)
- [implement_control_step.R](implement_control_step.md)

## What it calls, in order of appearance

- [period_simulation_cpp.cpp](period_simulation_cpp.md)

## Input data

- period_chunk     : Data frame. Time series data for the simulation period. Must contain the following columns: time        - POSIXct. Simulation timestamps. SolarR      - Numeric. Solar radiation (W/m²). Read in the "execution" context. Text        - Numeric. External air temperature (°C). Read in the "execution" context. SolarR_forec and Text_forec - Numeric. Their forecasts, read instead of SolarR and Text in the "plan", "plan_flex_down" and "plan_flex_up" contexts. T_ext_24h   - Numeric. Mean external temperature of the previous day (°C), held constant over the day. It is not a running mean. It selects the shading coefficient and the ventilation of the unoccupied rows. Read in the "execution" context. T_ext_24h_forec - Numeric. The T_ext_24h the plan knows (°C): the mean Text of the day before the clearing date of the market, constant over the period. Read instead of T_ext_24h in the "plan", "plan_flex_down" and "plan_flex_up" contexts. Occupancy   - Integer (0/1). Building occupancy flag. The C++ core runs the occupied ventilation while it is 1. MarketUTC   - POSIXct. Market period timestamps for setpoint lookup. Ti          - Numeric. Initial internal temperature (°C) at row 1. (Prefix applies based on context) Te          - Numeric. Initial envelope temperature (°C) at row 1. (Prefix applies based on context) Act_heat    - Integer (0/1/2). Initial heating activation at row 1. (Prefix applies based on context) Act_cool    - Integer (0/1/2). Initial cooling activation at row 1. (Prefix applies based on context) Thermostat_heat and Thermostat_cool - Integer (0/1). Initial state of the two thermostats at row 1, which the hysteresis of row 2 starts from. (Prefix applies based on context.) A chunk without these columns takes the state of Act_heat and Act_cool of row 1, which must then be 0 or 1. Service_T_Low and Service_T_High - Numeric. Comfort band, required when calculation_context is "execution". Scheduling_T_Low and Scheduling_T_High - Numeric. Comfort band, required when calculation_context is "plan", "plan_flex_down" or "plan_flex_up". For "plan_flex_down" and "plan_flex_up", also Service_T_Low, Service_T_High and the phase column of the leg (Flex_phase_down_plan or Flex_phase_up_plan): on the rows of a flexibility window (phase above 0) the occupancy band Service_T_* is used instead of Scheduling_T_*. If set_point_df is NULL, must ALSO contain (with context suffix):
    - STP_heat_low
    - STP_heat_high
    - STP_cool_low
    - STP_cool_high

In the "execution" context, the STP_*_exec columns are first overwritten with the STP_*_plan columns, so period_chunk must hold the six STP_*_plan columns: the execution always runs the setpoints of the plan. Optional columns (carried over from period_chunk if present, NA treated as 0, initialized to 0 if absent):

- Q_heat
- Q_cool
- Elec_heat
- Elec_cool
- Elec_total
- Comfort
- set_point_df     : Optional Data frame (Default: NULL). Setpoint schedule with columns: period        - POSIXct. Market period timestamps. STP_heat      - Numeric. Heating setpoint (°C). STP_heat_low  - Numeric. Lower heating threshold (°C). STP_heat_high - Numeric. Upper heating threshold (°C). STP_cool      - Numeric. Cooling setpoint (°C). STP_cool_low  - Numeric. Lower cooling threshold (°C). STP_cool_high - Numeric. Upper cooling threshold (°C). If provided, overwrites corresponding context-suffixed values in period_chunk, on rows 2 to n only: row 1 keeps the setpoints it already had. Each row takes the setpoints of the period equal to its MarketUTC.
- asset            : Named list. The parameters of the building, its entry of parameters$assets. Must include the group model, the thermal model coefficients, among them:
    - Ci
    - Ce
    - Rie
    - Rea
    - Aw
    - Ae
    - the heat pump coefficients
    - Rvent01
    - Rvent1
    - Rvent2
    - Rvent2_HR
    - Setpoint_Rvent1
    - inertial_fact

(Comfort thresholds are read from period_chunk, not from the parameters - see period_chunk columns above.)

- calculation_mode : Integer scalar or vector. Computation mode per timestep: 1 - Setpoint mode: Q_heat and Q_cool are computed from histeresis control logic. 2 - Heat Input mode: Q_heat and Q_cool are read directly from period_chunk columns. 3 - Setpoint with a per-step power cap: as mode 1, but the decision of every step is bounded by Q_heat_cap/Q_cool_cap before the RC equations, so the bound propagates to the next step's state. If a scalar is provided, it is expanded to all timesteps. Default: 1.
- Q_heat_cap       : Numeric vector or NULL. Per-step upper bound on the heating energy of the timesteps in mode 3 (kWh per step, the same unit as the Q_heat columns). Must have one value per row of period_chunk. NULL (the default) means no bound anywhere, which leaves mode 3 identical to mode 1. Ignored by the timesteps in modes 1 and 2.
- Q_cool_cap       : Numeric vector or NULL. Same as Q_heat_cap, for cooling.
- calculation_context: Character. Determines the dataframe columns to read from/write to. Valid options: "execution" (default), "plan", "plan_flex_down", "plan_flex_up". "execution" reads/writes with "_exec" suffix (e.g. Ti_exec, Q_heat_exec, STP_heat_low_exec). "plan" reads/writes with "_plan" suffix (e.g. Ti_plan, STP_heat_low_plan). "plan_flex_down" reads/writes with "_plan_flex_down" suffix (downward flexibility itinerary). "plan_flex_up" reads/writes with "_plan_flex_up" suffix (upward flexibility itinerary).

## Output data

- period_chunk : Data frame. The input data frame with the following columns added or updated (depending on calculation_context): Ti         - Numeric. Internal temperature time series (°C). Te         - Numeric. Envelope temperature time series (°C). Q_heat     - Numeric. Heating energy per timestep (kWh). Q_cool     - Numeric. Cooling energy per timestep (kWh). Elec_heat  - Numeric. Heating electricity consumption per timestep (kWh). Elec_cool  - Numeric. Cooling electricity consumption per timestep (kWh). Elec_total - Numeric. Total electricity consumption per timestep (kWh). Comfort    - Integer (0/1). Comfort flag per timestep: 1 when Ti is strictly inside the comfort band of the row. Act_heat   - Integer (0/1/2). Heating activation per timestep: 0 off, 1 on by the thermostat, 2 imposed (calculation_mode 2 with a heating above 0). Act_cool   - Integer (0/1/2). Cooling activation per timestep, with the same codes. Thermostat_heat and Thermostat_cool - Integer (0/1). State of each thermostat at the end of each timestep, also while the heat is imposed. STP_*      - Numeric. The six setpoint columns of the context, as used by the simulation.

## Other notes from the file header

### Code outline

1. Validate inputs and calculation context
2. Extract model parameters
3. Create internal vectors for fast computation
4. Apply setpoints from set_point_df if provided (vectorized by MarketUTC)
5. Validate initial states and setpoint vectors
6. Simulation loop: hysteresis control, thermal dynamics, energy
7. Write results back to data frame

### Usage instructions

```r
result_df <- period_calculation(period_chunk, asset)
```

```r
result_df <- period_calculation(period_chunk, asset, calculation_mode =
  2, calculation_context = "plan", set_point_df = sp_df)
```

### Exceptions and special cases

- If period_chunk has fewer than 2 rows, the function returns the input data frame unchanged (no simulation is performed).
- If set_point_df is NULL and suffixed setpoint columns are missing in period_chunk, an error is raised via stop().
- calculation_mode can be a per-timestep vector; invalid values (not 1, 2 or 3) raise an error via stop(). A length mismatch with the number of timesteps also raises an error.
- Q_heat_cap/Q_cool_cap are accepted whatever the modes in use, and are only read by the timesteps in mode 3. A non-NULL cap whose length does not match the number of timesteps raises an error via stop(); NA values inside a cap vector are treated as "no bound", the same as Inf.
- The system lock these caps implement is an interpretation of the legal regulation of HVAC systems, which does not allow energy management through the alternating use of heating and cooling. See build_hvac_lock_caps.R.
- Invalid calculation_context value will raise an error via stop().
- If a MarketUTC value in period_chunk has no matching 'period' entry in set_point_df, the function raises an error via stop().
- If set_point_df$period contains duplicated values, the function raises an error via stop() before applying setpoints.
- Heating and cooling are mutually exclusive: if heating is active, cooling is forced off regardless of the temperature relative to the cooling setpoint.
- Setpoints are applied using hysteresis: heating activates when Ti drops below STP_heat_low and deactivates when Ti rises above STP_heat_high; cooling applies the same logic with STP_cool_low and STP_cool_high.
- The optional columns listed under Inputs are carried over from period_chunk's existing value at row 1 (the initial-condition row, never recomputed by the simulation loop) whenever the column is already present, and initialized to 0 if absent from period_chunk; NA values in these columns are also treated as 0.
- If required initial states or setpoint values are missing, the function stops with an error so the simulation does not continue with undefined control logic.
- inertial_fact is read from asset$model and always used in the internal temperature calculation: a fraction inertial_fact of the heat of each step reaches the indoor air one step later (the power of the previous step), and the rest in the step itself.

## Diagram

![Block diagram of period_calculation.R](period_calculation.jpg)

Also available as [period_calculation.svg](period_calculation.svg).

---

[Back to the code structure index](../Code_Structure.md)
