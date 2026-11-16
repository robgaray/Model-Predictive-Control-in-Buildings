# period_simulation_cpp.cpp

**C++ module** &nbsp;·&nbsp; `30_Simulation/05_Models/01_Building/03_1_Functions_Cpp/period_simulation_cpp.cpp`

## Function

This function implements the core thermal simulation loop in C++ using Rcpp. It performs a sequential step-by-step calculation of building temperatures (internal Ti and envelope Te) based on a 2C RC building model.

## Called by

- [period_calculation.R](period_calculation.md)

## What it calls, in order of appearance

- [heat_pump_cop_cpp.h](heat_pump_cop_cpp.md)
- [heat_pump_electricity_step.h](heat_pump_electricity_step.md)

## Input data

- Ti                     : NumericVector. Internal temperature.
- Te                     : NumericVector. Envelope temperature.
- Act_heat               : IntegerVector. Heating activation of each step: 0 off, 1 on by the thermostat, 2 imposed (calculation_mode 2 with heat).
- Act_cool               : IntegerVector. Cooling activation of each step, with the same codes.
- Thermostat_heat        : IntegerVector. State of the heating thermostat at the end of each step (0/1), the state the hysteresis of the next step starts from. Row 1 is the initial state.
- Thermostat_cool        : IntegerVector. The same, for cooling.
- Q_heat                 : NumericVector. Heating energy per step (kWh).
- Q_cool                 : NumericVector. Cooling energy per step (kWh).
- Elec_heat              : NumericVector. Heating electricity per step (kWh).
- Elec_cool              : NumericVector. Cooling electricity per step (kWh).
- Elec_total             : NumericVector. Total electricity per step (kWh).
- Comfort                : IntegerVector. Comfort flags: 1 when Ti is strictly inside the comfort band.
- SolarR                 : NumericVector. Solar radiation (W/m2).
- Text                   : NumericVector. Outdoor temperature.
- T_ext_24h              : NumericVector. Mean outdoor temperature of the previous day (degC), held constant over the day (not a running mean). It selects the shading coefficient and the ventilation of the unoccupied rows (see block 1.4).
- Occupancy              : IntegerVector. Building occupancy (0/1). The occupied ventilation runs while the building is occupied (see block 1.4).
- time                   : NumericVector. Simulation timestamps (seconds since epoch; converted to hours per step below).
- comfort_low            : NumericVector. Lower comfort temperature limit.
- comfort_high           : NumericVector. Upper comfort temperature limit.
- STP_heat_low           : NumericVector. Lower heating setpoint.
- STP_heat_high          : NumericVector. Upper heating setpoint.
- STP_cool_low           : NumericVector. Lower cooling setpoint.
- STP_cool_high          : NumericVector. Upper cooling setpoint.
- calculation_mode_vec   : IntegerVector. Computation mode per step. 1 = Setpoint, 2 = Heat Input, 3 = Setpoint with a per-step power cap.
- Q_heat_cap             : NumericVector. Per-step upper bound on the heating energy of calculation_mode 3 (kWh per step, the same unit as Q_heat). R_PosInf means no bound. Ignored by modes 1 and 2.
- Q_cool_cap             : NumericVector. Per-step upper bound on the cooling energy of calculation_mode 3 (kWh per step, the same unit as Q_cool). R_PosInf means no bound. Ignored by modes 1 and 2.
- Ci, Ce                 : Double. Thermal capacitances (kWh/K).
- Rie, Rea               : Double. Thermal resistances (K/kW).
- Aw, Ae                 : Double. Solar aperture parameters (m2).
- Shading_0, Shading_1   : Double. Fraction of the window solar gain that is blocked, below and above the shading threshold.
- Setpoint_Shading1      : Double. Shading activation threshold on T_ext_24h (degC).
- AT_hp_heat_1, AT_hp_heat_2: Double. Heat pump temperature deltas (degC).
- Q_hp_heat_1, Q_hp_heat_2  : Double. Heat pump heating capacities (kW).
- COP_hp_heat_1_coef1    : Double. Heating COP at the reference point (Text_ref_hp_heat, Tsup_ref_hp_heat), dimensionless.
- COP_hp_heat_1_coef2    : Double. Sensitivity of the heating COP to the outdoor temperature (1/degC).
- COP_hp_heat_1_coef3    : Double. Sensitivity of the heating COP to the supply temperature (1/degC).
- Tsup_hp_heat           : Double. Heat pump supply temperature.
- Text_ref_hp_heat       : Double. Outdoor temperature of the reference point the COP is referred to (degC).
- Tsup_ref_hp_heat       : Double. Supply temperature of that same reference point (degC).
- Q_hp_cool              : Double. Cooling capacity (kW).
- COP_hp_cool            : Double. Cooling COP (dimensionless).
- Rvent01                : Double. Ventilation resistance of the unoccupied rows below Setpoint_Rvent1 (infiltration) (K/kW).
- Rvent1                 : Double. Ventilation resistance of the unoccupied rows at or above Setpoint_Rvent1 (reinforced ventilation) (K/kW).
- Rvent2, Rvent2_HR      : Double. Ventilation resistance of the occupied rows, without and with heat recovery (K/kW).
- Setpoint_Rvent1        : Double. Threshold on T_ext_24h that selects Rvent1 instead of Rvent01 (degC).
- inertial_fact          : Double. Fraction of the heating and cooling power that reaches the indoor air one step late: the RC equation takes this fraction of the power of the previous step and the rest of the power of the step itself.

## Output data

- List                   : Contains all updated simulation vectors. Row 1 of every vector is the initial condition and is returned as received. Q_heat, Q_cool, Elec_heat, Elec_cool and Elec_total are cloned before the loop writes into them. Ti, Te, Act_heat, Act_cool, Thermostat_heat, Thermostat_cool and Comfort are not cloned: the loop writes into the vectors it receives, which period_calculation() builds for this call alone.

## Other notes from the file header

### The electrical model

The COP of the heat pump and the electricity of each step are not written here: they come from heat_pump_cop_cpp.h and heat_pump_electricity_step.h, the only copy of the electrical model of the simulator. This file includes those headers, and the two that R calls besides the simulation (heat_pump_electricity_cpp.h and apply_commitment_margin_cpp.h), so that the single Rcpp::sourceCpp() call that compiles it compiles and exports all of them:

- period_simulation_cpp()
- heat_pump_cop_cpp()
- heat_pump_electricity_cpp()
- apply_commitment_margin_cpp()

### Units

The project uses a single pair of reference units: kW for power and kWh for energy. Every timestep is measured in hours, so the two are related by delta_t alone, with no extra conversion factor:

- energy [kWh] = power [kW] * delta_t [h]
- power  [kW]  = energy [kWh] / delta_t [h]

Inside this loop Q_heat_new/Q_cool_new hold a POWER (kW) while the RC equations are evaluated, and are converted to the step's ENERGY (kWh) in block 1.5 just before being stored. The Q_heat/Q_cool vectors that cross the R boundary, in both directions, always hold energy per step (kWh) - which is why calculation_mode 2 divides them by delta_t when reading them back. The model's capacity parameters follow the same convention: Ci and Ce are kWh/K and the thermal resistances are K/kW. This function performs no economic calculation: energy cost is always resolved afterwards in R, through reward_function()/ compute_marginal_energy_cost() (planning contexts) or through calc_differential_cost() (execution accounting), both of which apply the buy/sell price distinction this simplified per-timestep multiplication cannot express.

### Calculation modes

1 Setpoint             - the hysteresis thermostat decides the heating

- and cooling power of every step.

2 Heat Input           - the power of every step is imposed from the

- Q_heat/Q_cool vectors and the thermostat does
- not decide it. Act_heat (Act_cool) is 2 on a
- step whose imposed heating (cooling) is above
- 0, and 0 otherwise. The hysteresis still runs
- on the simulated Ti and writes its state in
- Thermostat_heat and Thermostat_cool, so the
- thermostat goes on from its own state when
- the imposition ends.

3 Setpoint with cap    - the thermostat decides as in mode 1 and the

- decision is then bounded, step by step, by
- Q_heat_cap/Q_cool_cap. The bound is applied
- inside the loop, BEFORE the RC equations, so
- the state of the next step is computed with
- the already-bounded power and the thermostat
- of the next step decides on the real state of
- the building. Capping a finished trajectory
- afterwards would not be physical.
- With both caps at R_PosInf, mode 3 reproduces
- mode 1 exactly.

Mode 3 exists to enforce the system lock of the Recovery Phase of a flexibility event: the system that was not used to provide the flexibility service may hold or reduce its power, never increase it. That restriction is an interpretation of the legal regulation of HVAC systems, which does not allow energy management through the alternating use of heating and cooling. See build_hvac_lock_caps.R, which is what builds these two vectors.

### Code outline

1. Extract dimensions, verify inputs, clone the vectors that are written and compute the COP of every step (heat_pump_cop_cpp()).
2. Loop through each timestep to calculate thermal dynamics and the electricity of the step (heat_pump_electricity_step()).
3. Construct and return the output List.

### Usage instructions

Called from R via period_calculation.R. Compiled with Rcpp::sourceCpp() on this file alone: the headers it includes are found in its own folder.

## Diagram

![Block diagram of period_simulation_cpp.cpp](period_simulation_cpp.jpg)

Also available as [period_simulation_cpp.svg](period_simulation_cpp.svg).

---

[Back to the code structure index](../Code_Structure.md)
