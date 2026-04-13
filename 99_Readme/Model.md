# Model

The energy model is based on a previous work by Peder Bacher et Al. [1], where a reduced order model of a building was developed. This model was extended by ourselves in Ruben Mulero et Al. [2], where we integrated models for internal loads, radiators and heat pumps.

In this work, adaptations of [1] and [2] are made as per the descriptions below.

Many of the decisions taken in the development of this model are quite simple approaches to how Heat Transfer in buildings and Heating Ventilation and Air Conditioning (HVAC) systems work. But this is still a valid approach to illustrate a MPC case.

## Building

A 2-state model is used with the following states:

-   Indoor temperature (Ti)

-   Envelope temperature (Te)

The following heat transfer and gains are considered:

-   Solar gains are introduced both to Ti and Te

-   Ventilation loop between Ti and outdoor temperature

-   Heating gain into Ti, linked to the activation of the thermostat and the heat output from the heat pump.

-   The following heat transfers

    -   Ti - Te

    -   Te - environment

## Thermostat

Heating and cooling systems are activated by a thermostat. An hysteresis thermostat is defined. In these systems, two thresholds are used:

-   Lower Temperature threshold: If indoor temperature is below this value, the thermostat activates the heating system

-   Upper Temperature threshold: If indoor temperature is above this value, the thermostat deactivates the heating system

In none of these occur (this means that indoor temperature is between these thresholds), the activation state remains constant.

For cooling mode, the above criteria is reversed.

## Heating and Cooling systems and Heat Pump capacity

The building is equipped with heat pumps for heating and cooling. Heating is modeled as per [2], while a simpler model with a fixed COP value is used for cooling.

If the thermostat activates, Heat pump power is defined by the temperature difference between the Upper Temperature threshold and the actual indoor temperature (Delta_temp).

For heating, Heat Pump power is constrained by a minimum (Q_hp1) for small Delta_temp values and a maximum (Q_hp2) for large Delta_temp values (maximum installed power). Q_hp1 corresponds to the heat pump cycle, while Q_hp2 corresponds to the heat pump cycle + backup resistances. The COP of the heat pump is calculated in agreement with equations 3.11 & 3.12 in [2].

For cooling, a fixed power and COP are used, Q_hp_cool and COP_hp_cool.

## Ventilation

Mechanical ventilation is assumed in the building.

When the building is active (see the following section), the building is ventilated at a 2 ACH / 6.36K/kW rate.

During non-occupied hours, a lower ventilation rate of 0.1 ACH / 127.15K/kW is considered. As an exception to this, in very hot periods, larger ventilation rates of 1ACH / 12.75K/kW are used in agreement with a night ventilation strategy.

It should be considered that this approach seems to be OK for a heating-only HVAC system in a cold climate. potentially more advanced approaches would be required in a milder or even hot climate.

## Shading

As a baseline. a 0.7 shading coefficient is used except for very hot periods, where a full shading coefficient of 1 is adopted.

## Occupancy & Internal loads

The building is set as occupied everyday between 7AM and 7PM (actually 6:50PM). This occupancy is used to set ventilation rates, as well as influence comfort-related policies.

No internal loads are used. Although these could be added to the model, they are considered not to be extremely relevant in a low-density building.

# References

[1] Peder Bacher, Henrik Madsen, Identifying suitable models for the heat dynamics of buildings, Energy and Buildings, 2011, <https://doi.org/10.1016/j.enbuild.2011.02.005>.

[2] Mulero R, Garay-Martinez R, Mendialdua I, Arregi B. A training workbench based on transient building models for creating intelligent energy operators, Data-Centric Engineering, 2025, <https://doi.org/10.1017/dce.2025.10016>

------------------------------------------------------------------------

[Back to README](../README.md)
