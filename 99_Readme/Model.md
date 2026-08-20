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

For heating, Heat Pump power is constrained by a minimum (Q_hp1) for small Delta_temp values and a maximum (Q_hp2) for large Delta_temp values (maximum installed power). Q_hp1 corresponds to the heat pump cycle, while Q_hp2 corresponds to the heat pump cycle + backup resistances. The COP of the heat pump is calculated in agreement with equations 3.11 & 3.12 in [2].

For cooling, a fixed power and COP are used, Q_hp_cool and COP_hp_cool.

## Ventilation

Mechanical ventilation is assumed in the building. The ventilation rate is calculated based on the Air Changes per Hour (ACH) rate, applied over the building volume. This rate is converted into a thermal ventilation resistance (Rvent, K/kW) using the building volume, air density, and specific heat capacity of air.

Three distinct ventilation scenarios are considered, each with a different ACH value defined in the configuration file:

- **Daytime ventilation (during occupancy):** A higher ventilation rate is applied to ensure indoor air quality. The ACH value for this regime is defined by `RENvent2`. A heat recovery unit is included to prevent excessive energy consumption due to ventilation. See below for the heat recovery activation logic.

- **Night-time ventilation (base infiltration):** During unoccupied hours, only infiltration losses are considered. This corresponds to a very low ACH rate defined by `RENvent01`.

- **Night cooling (reinforced night ventilation):** In hot periods, a higher night ventilation rate (`RENvent1`) is applied to cool the building by taking advantage of lower outdoor temperatures. This mode is activated when the 24-hour running mean of the outdoor temperature exceeds `Setpoint_Rvent1` (°C).

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

The coefficient switches between two configured values based on the 24-hour running mean of the outdoor temperature (T_ext_24h):

- Above the Setpoint_Shading1 threshold, full shading (Shading_1) is applied;

- At or below the Setpoint_Shading1 threshold, the baseline coefficient (Shading_0) applies.

In the repository's default configuration, Shading_0 = 0.7 and Shading_1 = 1 (Setpoint_Shading1 = 20°C) - meaning 70% of solar radiation is blocked as a baseline, and 100% is blocked whenever the 24-hour average outdoor temperature exceeds 20°C.

## Occupancy & Internal loads

The building is set as occupied everyday between 7AM and 7PM (actually 6:50PM). This occupancy is used to set ventilation rates, as well as influence comfort-related policies.

No internal loads are used. Although these could be added to the model, they are considered not to be extremely relevant in a low-density building.

# References

[1] Peder Bacher, Henrik Madsen, Identifying suitable models for the heat dynamics of buildings, Energy and Buildings, 2011, <https://doi.org/10.1016/j.enbuild.2011.02.005>.

[2] Mulero R, Garay-Martinez R, Mendialdua I, Arregi B. A training workbench based on transient building models for creating intelligent energy operators, Data-Centric Engineering, 2025, <https://doi.org/10.1017/dce.2025.10016>

------------------------------------------------------------------------

[Back to README](../README.md)
