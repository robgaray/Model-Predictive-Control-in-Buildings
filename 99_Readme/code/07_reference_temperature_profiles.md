# 07_reference_temperature_profiles.R

**Script** &nbsp;·&nbsp; `30_Simulation/04_Scripts/07_reference_temperature_profiles.R`

## Function

Generates the service and scheduling temperature profiles used by the reward-related comfort calculations. Sourced by Main.R before simulation.

## Called by

- [Main.R](Main.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- Main_df, with its Occupancy, Scheduling and Overall_Climate columns.
- parameters$reward : the service and setback comfort bands.
- parameters$operational_temperature_corrections : the shifts applied to the service band while the building is prepared.

## Output data

- Main_df, with the reference temperature profiles the comfort term of the reward is measured against:
    - Service_T_Low/High: the occupancy band. The executed operation, and the flexibility itineraries inside their windows, are measured against it.
    - Scheduling_T_Low/High: the more restrictive of the occupancy band and the scheduling band. The plan, and the flexibility itineraries outside their windows, are measured against it.

## Other notes from the file header

### Code outline

1. Check the Occupancy, Scheduling and Overall_Climate columns.
2. Service band of each row: the service band where the building is occupied, the setback band where it is not.
3. Scheduling band of each row: the service band where Scheduling is 1, shifted by the climate of the day, and the service band of step 2 everywhere else.
4. Plan band: the more restrictive of the bands of steps 2 and 3, stored in Scheduling_T_*. The run stops if it is empty on any row.

### Usage instructions

Not called: sourced by Main.R before the simulation, and after the occupancy and scheduling profiles it reads.

## Diagram

![Block diagram of 07_reference_temperature_profiles.R](07_reference_temperature_profiles.jpg)

Also available as [07_reference_temperature_profiles.svg](07_reference_temperature_profiles.svg).

---

[Back to the code structure index](../Code_Structure.md)
