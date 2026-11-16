# flex_up_power_limit.R

**Function** &nbsp;·&nbsp; `30_Simulation/05_Models/01_Building/03_Functions/flex_up_power_limit.R`

## Function

Returns the heat power that bounds an upward flexibility window of a system: the most the window may raise that system to.

- Heating: Q_hp_heat_1 or Q_hp_heat_2, as flex_up_max_power_heating names. They are the rated capacities of the two operating points of the heat pump, and which of them bounds an upward window is a modelling decision rather than a fact of the equipment. Above Q_hp_heat_1 the heat comes from the backup resistances, at COP 1.
- Cooling: Q_hp_cool, its only rated capacity.

The window builder and the holding of a standing window read the bound here, so both stop at the same limit.

## Called by

- [building_hold_room.R](building_hold_room.md)
- [flex_commitment_profile.R](flex_commitment_profile.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- hvac_up    : Character scalar, "heat" or "cool".
- parameters : Named list. Reads parameters$control$flex_up_max_power_heating.
- asset      : Named list. The parameters of the building, its entry of parameters$assets. Reads, from asset$model:
    - Q_hp_heat_1 (kW)
    - Q_hp_heat_2 (kW)
    - Q_hp_cool (kW)

## Output data

- Numeric scalar. The bounding heat power, in kW.

## Other notes from the file header

### Code outline

1. Check the system
2. Pick the rated capacity

### Usage instructions

```r
P_max <- flex_up_power_limit("heat", parameters, asset)
```

## Diagram

![Block diagram of flex_up_power_limit.R](flex_up_power_limit.jpg)

Also available as [flex_up_power_limit.svg](flex_up_power_limit.svg).

---

[Back to the code structure index](../Code_Structure.md)
