# Model

The energy model is based on previous work by Peder Bacher et al. [1], where a reduced order model of a building was developed. This model was extended in Ruben Mulero et al. [2], where models for internal loads, radiators and heat pumps were integrated.

In this work, adaptations of [1] and [2] are made as per the descriptions below.

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

## Heating and Cooling systems and Heat Pump capacity

The building is equipped with heat pumps for heating and cooling. Heating is modeled as per [2], while a simpler model with a fixed COP value is used for cooling.

If the thermostat activates, Heat pump power is defined by the temperature difference between the Upper Temperature threshold and the actual indoor temperature (Delta_temp).

For heating, the heat pump power depends on Delta_temp, the difference between `STP_heat_high` and the indoor temperature. Below `AT_hp_heat_1` it delivers `Q_hp_heat_1`, above `AT_hp_heat_2` it delivers `Q_hp_heat_2` (maximum installed power), and in between the power is interpolated linearly. `Q_hp_heat_1` corresponds to the heat pump cycle, while `Q_hp_heat_2` corresponds to the heat pump cycle + backup resistances. The COP of the heat pump is calculated in agreement with equations 3.11 & 3.12 in [2].

For cooling, a fixed power and COP are used, Q_hp_cool and COP_hp_cool.

## Ventilation

Mechanical ventilation is assumed in the building. The ventilation rate is calculated based on the Air Changes per Hour (ACH) rate, applied over the building volume. This rate is converted into a thermal ventilation resistance (Rvent, K/kW) using the building volume, air density, and specific heat capacity of air.

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

A higher resistance means less thermal coupling between the indoor air and the outdoor air through ventilation.

## Shading

A shading coefficient reduces the solar gain entering through windows (it modifies the Aw coefficient in [1]).

The coefficient represents the fraction of solar radiation blocked: 0 means unshaded (all radiation is transmitted), 1 means fully  shaded (none is transmitted).

The coefficient switches between two configured values based on `T_ext_24h`, the mean outdoor temperature of the previous calendar day. It is constant within each day. The first simulated day has no previous day and takes `t_ext_24h_default` from `30_Simulation/02_Config/15_Forecast_parameters.csv`:

- Above the Setpoint_Shading1 threshold, full shading (Shading_1) is applied;

- At or below the Setpoint_Shading1 threshold, the baseline coefficient (Shading_0) applies.

In the repository's default configuration, Shading_0 = 0.7 and Shading_1 = 1 (Setpoint_Shading1 = 20°C) - meaning 70% of solar radiation is blocked as a baseline, and 100% is blocked whenever the mean outdoor temperature of the previous day exceeds 20°C.

## Occupancy & Internal loads

Occupancy is read from `30_Simulation/02_Config/14_Use_Patterns.csv`. Each month and day of the week is given a type of day, and each type of day says, hour by hour, whether the building is occupied (1) or not (0). An hour column covers the whole hour: `H07` covers the time steps from 07:00 to 07:55.

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

# References

[1] Peder Bacher, Henrik Madsen, Identifying suitable models for the heat dynamics of buildings, Energy and Buildings, 2011, <https://doi.org/10.1016/j.enbuild.2011.02.005>.

[2] Mulero R, Garay-Martinez R, Mendialdua I, Arregi B. A training workbench based on transient building models for creating intelligent energy operators, Data-Centric Engineering, 2025, <https://doi.org/10.1017/dce.2025.10016>

------------------------------------------------------------------------

[Back to README](../README.md)
