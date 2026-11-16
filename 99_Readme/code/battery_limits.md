# battery_limits.h

**C++ module** &nbsp;·&nbsp; `30_Simulation/05_Models/03_Battery/03_1_Functions_Cpp/battery_limits.h`

## Function

Reads the parameters of a battery, the group battery of the parameters of its asset, and gives the limits that every step of the compiled physics of the battery uses. The values are read by name, as the R functions of the battery read them, and the energies are computed with the same operations:

- energy_max = SOC_max * Capacity (kWh)
- energy_min = SOC_min * Capacity (kWh)

It is the only place of the compiled code where the parameters of a battery are read. The file is a header, included by battery_trajectory_cpp.cpp, so that the single Rcpp::sourceCpp() call that compiles the module compiles it too. It is not callable from R.

## Called by

- [battery_factor_search_cpp.h](battery_factor_search_cpp.md)
- [battery_free_trajectory_cpp.h](battery_free_trajectory_cpp.md)
- [battery_recovery_correction_cpp.h](battery_recovery_correction_cpp.md)
- [battery_trajectory_cpp.cpp](battery_trajectory_cpp.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- battery : Rcpp::List. The parameters of the battery (asset$battery), with the elements:
    - Capacity
    - SOC_min
    - SOC_max
    - Charge_efficiency
    - Discharge_efficiency
    - Charge_power_max
    - Discharge_power_max
    - Self_discharge

## Output data

- BatteryLimits, the limits of the battery.

## Other notes from the file header

### The structure BatteryLimits

energy_max     : Double. The highest energy stored (kWh). energy_min     : Double. The lowest energy stored (kWh). eta_charge     : Double. The efficiency of the charge (-). eta_disch      : Double. The efficiency of the discharge (-). power_charge   : Double. The maximum charge power (kW). power_disch    : Double. The maximum discharge power (kW). self_discharge : Double. The self-discharge (% per day).

### Code outline

1. Read the parameters and compute the limits of the energy

### Usage instructions

From C++, after including this header:

- BatteryLimits limits = battery_limits(battery);

## Diagram

![Block diagram of battery_limits.h](battery_limits.jpg)

Also available as [battery_limits.svg](battery_limits.svg).

---

[Back to the code structure index](../Code_Structure.md)
