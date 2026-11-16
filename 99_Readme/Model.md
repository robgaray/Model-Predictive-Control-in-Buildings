# Model

The energy model is based on previous work by Peder Bacher et al. [1], where a reduced order model of a building was developed. This model was extended in Ruben Mulero et al. [2], where models for internal loads, radiators and heat pumps were integrated.

In this work, adaptations of [1] and [2] are made as per the descriptions below. This page describes the models of the assets of the system: buildings, photovoltaic installations and electric batteries.

Many of the decisions taken in the development of this model are quite simple approaches to how Heat Transfer in buildings and Heating Ventilation and Air Conditioning (HVAC) systems work. But this is still a valid approach to illustrate a MPC case.

## Building

A 2-state model is used with the following states:

- Indoor temperature (Ti)

- Envelope temperature (Te)

The following heat transfer and gains are considered:

- Solar gains are introduced both to Ti and Te

- Ventilation loop between Ti and outdoor temperature

- Heating gain into Ti, linked to the activation of the thermostat and the heat output from the heat pump.

- The following heat transfers

  - Ti - Te

  - Te - environment

## Thermostat

Heating and cooling systems are activated by a thermostat. An hysteresis thermostat is defined. In these systems, two thresholds are used:

- Lower Temperature threshold: If indoor temperature is below this value, the thermostat activates the heating system

- Upper Temperature threshold: If indoor temperature is above this value, the thermostat deactivates the heating system

In none of these occur (this means that indoor temperature is between these thresholds), the activation state remains constant.

For cooling mode, the above criteria is reversed.

In some time steps the heat or the cold is imposed from outside the thermostat, for example in the Commitment and Neutral Phases of a flexibility window. The thermostat keeps working in the background during those steps, and keeps its own state. When the imposition ends, the heating and cooling go on from the state of the thermostat.

## Heating and Cooling systems and Heat Pump capacity

The building is equipped with heat pumps for heating and cooling. Heating is modeled as per [2], while a simpler model with a fixed COP value is used for cooling.

If the thermostat activates, Heat pump power is defined by the temperature difference between the Upper Temperature threshold and the actual indoor temperature (Delta_temp).

For heating, the heat pump power depends on Delta_temp, the difference between `STP_heat_high` and the indoor temperature. Below `AT_hp_heat_1` it delivers `Q_hp_heat_1`, above `AT_hp_heat_2` it delivers `Q_hp_heat_2` (maximum installed power), and in between the power is interpolated linearly. `Q_hp_heat_1` corresponds to the heat pump cycle, while `Q_hp_heat_2` corresponds to the heat pump cycle + backup resistances. The COP of the heat pump cycle follows equations 3.11 & 3.12 in [2]: `COP = COP_hp_heat_1_coef1 + COP_hp_heat_1_coef2 * (Text - Text_ref_hp_heat) + COP_hp_heat_1_coef3 * (Tsup_hp_heat - Tsup_ref_hp_heat)`. `Text` is the outdoor temperature and `Tsup_hp_heat` the supply temperature of the heat pump. The reference point (`Text_ref_hp_heat`, `Tsup_ref_hp_heat`) is A7/W35 of EN 14511. The COP is never lower than 1: a heat pump never gives less heat than the electricity it uses. When the formula gives less than 1, for example on a very cold day, the COP is 1.

In each time step, the heat up to `Q_hp_heat_1` comes from the heat pump cycle, and uses heat divided by the COP as electricity. Any heat above `Q_hp_heat_1` comes from the backup resistances, which use one unit of electricity per unit of heat (COP 1).

For cooling, a fixed power and COP are used, Q_hp_cool and COP_hp_cool.

## Ventilation

Mechanical ventilation is assumed in the building. The ventilation rate is calculated based on the Air Changes per Hour (ACH) rate, applied over the building volume. This rate is converted into a thermal ventilation resistance (Rvent, K/kW) using the building volume, air density, and specific heat capacity of air.

The resistance is `Rvent = 3600 / (ACH * Volume * dens_air * Cp_air)`, with `ACH` in 1/h, `Volume` in m3, `dens_air` in kg/m3 and `Cp_air` in kJ/(kg.K). The air properties are in `30_Simulation/02_Config/00_Inner_parameters/03_Physical_properties.csv`. When `ACH` is 0, there is no ventilation: the resistance is infinite, and no heat goes through the ventilation.

Three distinct ventilation scenarios are considered, each with a different ACH value defined in the configuration file:

- **Daytime ventilation (during occupancy):** A higher ventilation rate is applied to ensure indoor air quality. The ACH value for this regime is defined by `RENvent2`. A heat recovery unit is included to prevent excessive energy consumption due to ventilation. See below for the heat recovery activation logic.

- **Ventilation while unoccupied (base infiltration):** While the building is unoccupied, only infiltration losses are considered. This corresponds to a very low ACH rate defined by `RENvent01`.

- **Reinforced ventilation while unoccupied:** In hot periods, a higher ventilation rate (`RENvent1`) replaces `RENvent01` in every unoccupied time step: at night, but also during the day at weekends or in August. It is applied when the mean outdoor temperature of the previous day (`T_ext_24h`) is at or above `Setpoint_Rvent1` (°C). The outdoor temperature is not compared with the indoor temperature, so the reinforced ventilation also runs when outdoor air is warmer than indoor air.

### Heat recovery

During daytime ventilation, a heat recovery unit is modelled to reduce the thermal impact of fresh-air intake. The heat recovery efficiency is defined by `Efi_Vent_Rec` (0–1) in the configuration file.

Heat recovery is activated selectively, based on a thermal equilibrium temperature (T_equilibrium), defined as the midpoint between the heating and cooling setpoints:

```
T_equilibrium = (STP_heat_high + STP_cool_low) / 2
```

This temperature defines the current operating mode of the building:

- If indoor temperature **below** T_equilibrium: the building is in **heating mode**.
- If indoor temperature **above** T_equilibrium: the building is in **cooling mode**.

Once the mode is established, heat recovery is activated whenever it is energetically beneficial:

- In **heating mode**, the heat recovery unit is activated when the outdoor temperature is **lower** than the indoor temperature (prevents cold outdoor air from extracting heat from the building).
- In **cooling mode**, the heat recovery unit is activated when the outdoor temperature is **higher** than the indoor temperature (prevents warm outdoor air from adding heat to the building).

When heat recovery is active, the effective ventilation resistance increases according to:

```
Rvent_HR = Rvent / (1 - Efi_Vent_Rec)
```

A higher resistance means less thermal coupling between the indoor air and the outdoor air through ventilation. With `Efi_Vent_Rec = 1`, the recovery is perfect: the resistance is infinite, and no heat goes through the ventilation.

## Shading

A shading coefficient reduces the solar gain entering through windows (it modifies the Aw coefficient in [1]).

The coefficient represents the fraction of solar radiation blocked: 0 means unshaded (all radiation is transmitted), 1 means fully  shaded (none is transmitted).

The coefficient switches between two configured values based on `T_ext_24h`, the mean outdoor temperature of the previous calendar day. It is constant within each day. When a market plans, it does not know the mean of a day that has not ended: its plan uses, over the whole horizon, the mean outdoor temperature of the day before the date the market clears. The first simulated day has no previous day and takes `t_ext_24h_default` from `30_Simulation/02_Config/15_Forecast_parameters.csv`:

- Above the Setpoint_Shading1 threshold, full shading (Shading_1) is applied;

- At or below the Setpoint_Shading1 threshold, the baseline coefficient (Shading_0) applies.

In the repository's default configuration, Shading_0 = 0.7 and Shading_1 = 1 (Setpoint_Shading1 = 20°C) - meaning 70% of solar radiation is blocked as a baseline, and 100% is blocked whenever the mean outdoor temperature of the previous day exceeds 20°C.

## Occupancy & Internal loads

Occupancy is read from `14_Use_Patterns.csv`, in the folder of the building (`30_Simulation/02_Config/20_Assets/Building_001/14_Use_Patterns.csv`). Each month and day of the week is given a type of day, and each type of day says, hour by hour, whether the building is occupied (1) or not (0). An hour column covers the hour that ends at its number: `H01` covers the time steps from 00:00 to 01:00, `H07` those from 06:00 to 07:00, and `H24` those from 23:00 to 24:00 of the same day. Each time step reads the hour in which it starts.

In the default configuration there are three types of day:

- `TYPE001`: occupied from 07:00 to 20:00.
- `TYPE002`: occupied from 07:00 to 16:00.
- `TYPE003`: not occupied.

They are spread over the year as follows:

- From October to May: Monday, Wednesday and Thursday are `TYPE001`, Tuesday is `TYPE002`, and Friday, Saturday and Sunday are not occupied.
- June, July and September: Monday to Friday are `TYPE002`, and the weekend is not occupied.
- August: not occupied.

This occupancy sets the ventilation rate (daytime ventilation runs while the building is occupied) and the comfort bands of the reward.

No internal loads are used. Although these could be added to the model, they are considered not to be extremely relevant in a low-density building.

## Photovoltaic installation

A photovoltaic installation has no control. It produces electricity whenever there is solar radiation, and the optimizer takes no decision on it.

The weather file gives the solar radiation on a horizontal plane, in W/m2, and the outdoor temperature, in degC. The model first works out the radiation that reaches the modules, then the temperature of the cells, and then the electric power. The markets plan with the forecast of the radiation and of the temperature, and the execution uses the actual weather.

First, the position of the sun. From the date and time of each row, and the latitude and longitude of the installation, the model computes the elevation and the azimuth of the sun. It uses the algorithm of the NOAA Solar Calculator. The radiation of a row stands for a moment that may not be the time of the row: hourly means, for example, are usually stamped at the end of the hour. `Irradiance_time_offset` is the time added to each row to find the moment the radiation stands for. Its default is -30 minutes, for hourly means stamped at the end of the hour. Use 0 for values at an instant.

Second, the radiation is split into direct and diffuse. The weather file does not tell them apart, so the model uses one simple rule. If the sun is below `Min_sun_elevation`, all the radiation is diffuse. If not, the radiation above `Diffuse_threshold` is direct and the rest is diffuse. The direct and the diffuse radiation always add up to the radiation of the row. The direct radiation measured on a plane facing the sun cannot be larger than the solar constant, 1361 W/m2.

Third, the radiation is projected on the modules. The direct radiation depends on the angle between the sun and the modules, which come from `Tilt` and `Azimuth`. It does not count when the sun is behind the modules. The diffuse radiation is taken as equal in all directions of the sky, so the modules get more of it the more they face up. The modules also receive the radiation that the ground reflects, a share `Albedo` of the radiation of the row. With horizontal modules (`Tilt` of 0), the radiation on the modules is the radiation of the row.

Fourth, the temperature of the cells is `T_cell = Text + (NOCT - 20) * G_poa / 800`, where `G_poa` is the radiation on the modules. The DC power of the modules, in kW, is `Module_area * Module_efficiency * G_poa / 1000 * (1 - DC_losses) * (1 + Temperature_coefficient / 100 * (T_cell - 25))`. The peak power of the installation is `Module_area * Module_efficiency` times 1 kW/m2. `DC_losses` holds the losses of the wiring, the dirt, the mismatch of the modules, their first degradation and their tolerance, but not those of temperature, which the model computes.

Last, the inverter delivers `Inverter_efficiency` times the DC power, limited to `Inverter_power`. The production of a step is that power times the duration of the step.

1000 W/m2 and 25 degC are the conditions at which the efficiency of the modules is rated; 800 W/m2 and 20 degC of air are those at which the NOCT is measured. They, and the solar constant, are in `30_Simulation/02_Config/00_Inner_parameters/03_Physical_properties.csv`.

With the default parameters (25 m2 of modules at 20 % efficiency, 5 kWp, tilted 30 degrees and facing south, in Bilbao), the production of a year with the weather file of the repository is about 1155 kWh per kWp.

The production is negative electricity for the system: it is subtracted from what the buildings use. When it is larger, the system exports. The parameters are in `17_Photovoltaic_parameters.csv`, in the folder of the installation. They are the location (`Latitude` and `Longitude`), the solar radiation (`Irradiance_time_offset`, `Diffuse_threshold` and `Min_sun_elevation`), the orientation (`Tilt`, `Azimuth` and `Albedo`), the modules (`Module_area`, `Module_efficiency`, `DC_losses`, `Temperature_coefficient` and `NOCT`) and the inverter (`Inverter_efficiency` and `Inverter_power`).

## Battery

A battery takes electricity from the system to charge, and gives it back to the system when it discharges. It is the asset that can move electricity in time: what it takes at one moment it can give at another, minus its losses.

The parameters are in `19_Battery_parameters.csv`, in the folder of the battery. `Capacity` is the energy it stores from empty to full, in kWh. `SOC_min` and `SOC_max` are its lowest and highest state of charge, as a share of the capacity: the battery does not discharge below the first, and does not charge above the second. `SOC_initial` is its state of charge at the start of the simulation. `Charge_power_max` and `Discharge_power_max` are the largest power, in kW, at which it takes electricity from the system and gives it back. `Charge_efficiency` is the share of the electricity taken that is stored, and `Discharge_efficiency` the share of the stored energy taken out that reaches the system. `Self_discharge` is the share of the stored energy it loses per day, in %.

With the default parameters, the battery stores 10 kWh, works between 10 % and 90 % of its capacity, starts half full, charges and discharges at up to 5 kW, keeps 95 % of the energy on the way in and 95 % on the way out, and loses 0.05 % of its energy per day.

On each market interval the battery works in one of five modes. The optimizer chooses them, as it chooses the modes of a building.

| Mode | Name | What the battery does |
| --- | --- | --- |
| 1 | Surplus charge | It charges only with the electricity the rest of the system would give to the grid, never from the grid. |
| 2 | Charge | It charges as much as its limits allow, also from the grid. |
| 3 | Local discharge | It discharges only to cover the electricity the rest of the system takes from the grid, never to give electricity to the grid. |
| 4 | Discharge | It discharges as much as its limits allow, also giving electricity to the grid. |
| 5 | Stop | It neither charges nor discharges. A time that no market has decided runs in this mode. |

The rest of the system is what the other assets take from the grid or give to it. A battery sees the assets that do not depend on the net electricity of the system, such as the buildings and the photovoltaic installations, and the batteries listed before it in `12_Asset_registry.csv`. Modes 1 and 3 follow what it sees, so in those modes the battery never buys electricity from the grid to charge, and never sells to the grid what it discharges.

The energy stored is computed on every time step of the simulation, in this order:

1. The self-discharge. The energy left from the step before shrinks by the factor `f = (1 - Self_discharge / 100) ^ (hours of the step / 24)`.
2. The limits. The mode asks the battery to charge or to discharge some electricity. The battery takes or gives as much of it as its limits allow: its largest power over the step, and the room left up to `SOC_max` or the energy left above `SOC_min`. It never charges and discharges in the same step.
3. The new energy. `Stored energy = f * Stored energy of the step before + Charge_efficiency * Charge - Discharge / Discharge_efficiency`, where `Charge` and `Discharge` are the electricity taken from and given to the system in the step, in kWh.

`SOC_min` limits the discharge, not the rest. A battery at rest keeps losing energy by self-discharge, so it can go a little below `SOC_min`. This is not an error: it simply cannot discharge again until it has charged above `SOC_min`. With the default parameters the loss is at most about 0.0005 kWh per day.

When the simulation runs the real operation, the battery keeps the mode of the plan, but the other assets take or give the electricity of the real weather, not that of the forecast. So in modes 1 and 3 the battery charges or discharges what the real operation asks, and the energy it stores can differ from the plan.

The energy the battery stores has a value in the reward: it is energy that will not have to be bought later. Without that value, the optimizer would empty the battery at the end of every horizon, because the energy left in it would seem worth nothing. How it is valued is explained in the reward section of the [README](../README.md#reward-definition-in-the-context-of-flexibilized-behavior).

The model has no cost of wear: charging and discharging cost only the electricity bought and the energy lost.

A battery can provide downward and upward flexibility. How it does it, and when it has to recover after a flexibility event, is explained in [Flexibility_Events](Flexibility_Events.md#batteries). Its table of results is described in [Input-Output files](Input_Output_Files.md#battery-tables).

# References

[1] Peder Bacher, Henrik Madsen, Identifying suitable models for the heat dynamics of buildings, Energy and Buildings, 2011, <https://doi.org/10.1016/j.enbuild.2011.02.005>.

[2] Mulero R, Garay-Martinez R, Mendialdua I, Arregi B. A training workbench based on transient building models for creating intelligent energy operators, Data-Centric Engineering, 2025, <https://doi.org/10.1017/dce.2025.10016>

------------------------------------------------------------------------

[Back to README](../README.md)
