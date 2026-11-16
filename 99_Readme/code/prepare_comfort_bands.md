# prepare_comfort_bands.R

**Function** &nbsp;·&nbsp; `30_Simulation/05_Models/01_Building/03_Functions/prepare_comfort_bands.R`

## Function

Generates the service and scheduling temperature profiles used by the reward-related comfort calculations.

## Called by

- [building_prepare_period.R](building_prepare_period.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- asset_df                            : data frame, the table of the building, with its Occupancy, Scheduling and Overall_Climate columns.
- comfort                             : List. The comfort group of the building, in its entry of parameters$assets, with the service and setback comfort bands:
    - Service_T_Low and Service_T_High [degC]
    - Setback_T_Low and Setback_T_High [degC]
- operational_temperature_corrections : List. The shifts applied to the service band while the building is prepared, those of the building, in its entry of parameters$assets:
    - Service_AT_Low_Sched_HDD [degC]
    - Service_AT_High_Sched_CDD [degC]

## Output data

- asset_df, as received, with the reference temperature profiles the comfort term of the reward is measured against:
- Service_T_Low/High: the occupancy band. The executed operation, and the flexibility itineraries inside their windows, are measured against it.
- Scheduling_T_Low/High: the more restrictive of the occupancy band and the scheduling band. The plan, and the flexibility itineraries outside their windows, are measured against it.

## Other notes from the file header

### Code outline

1. Check the Occupancy, Scheduling and Overall_Climate columns.
2. Service band of each row: the service band where the building is occupied, the setback band where it is not.
3. Scheduling band of each row: the service band where Scheduling is 1, shifted by the climate of the day, and the service band of step 2 everywhere else.
4. Plan band: the more restrictive of the bands of steps 2 and 3, stored in Scheduling_T_*. The run stops if it is empty on any row.

### Usage instructions

```r
asset_df <- prepare_comfort_bands(
  asset_df                            = asset_df,
  comfort                             =
  parameters$assets[[1]]$comfort,
  operational_temperature_corrections =
  parameters$assets[[1]]$operational_temperature_corrections
  )
```

## Diagram

![Block diagram of prepare_comfort_bands.R](prepare_comfort_bands.jpg)

Also available as [prepare_comfort_bands.svg](prepare_comfort_bands.svg).

---

[Back to the code structure index](../Code_Structure.md)
