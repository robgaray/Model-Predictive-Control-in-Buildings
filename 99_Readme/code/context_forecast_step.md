# context_forecast_step.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/context_forecast_step.R`

## Function

This function extracts or generates a fake forecast context for a given optimization horizon.

It returns a data frame containing only the time, external temperature forecast (Text_forec), and solar radiation forecast (SolarR_forec) columns for the requested horizon window. When an inaccurate forecast type is requested, the function calls imperfect_forecast() to blend ground-truth values with a historical average, introducing realistic forecast uncertainty.

The forecast consists of a weighted average beween the actual climate and a historical average, with the weight of the historical average increasing linearly along the horizon. This allows to introduce realistic forecast uncertainty in the building performance predictions.

## Called by

- [14_simulation.R](14_simulation.md)

## What it calls, in order of appearance

- [imperfect_forecast.R](imperfect_forecast.md) &nbsp;(2 call sites)

## Input data

- simulation_control : Named list. Must contain simulation_control$indexes_global$i0 (Integer. Index of the current simulation step in Main_df) and simulation_control$indexes_global$i_end_horizon (Integer. Index of the last step of the forecast horizon in Main_df).
- time_sec         : Numeric vector. Time in seconds (currently unused internally but kept for interface consistency).
- Main_df          : Data frame. Full simulation time series containing at least the columns 'time', 'Text', and 'SolarR'.
- parameters       : List. Model/forecast parameters. Must contain a sub-list 'forecast_parameters' with fields: weather_forecast_type           (default "accurate"): Character. Either "accurate" or "inaccurate". Extracted internally. weather_forecast_n_days_back    (default 5) weather_forecast_weight_history (default 0.2) Also requires: debug_and_config_parameters$verbose: Logical. Read into a local variable but not currently used (no progress messages are printed).

## Output data

- A named list with one element: forecast_df : Data frame with columns: time         – POSIXct timestamps Text_forec   – Forecast of external air temperature (°C) SolarR_forec – Forecast of solar radiation (W/m²) Rows span from index i0 to i_end_horizon in Main_df.

## Other notes from the file header

### Code outline

1. Extract forecast parameters
2. Select forecast method (accurate or inaccurate)
3. Generate forecast data frame
4. Return forecast results

### Usage instructions

```r
result <- context_forecast_step(simulation_control, time_sec, Main_df, parameters)
```

### Exceptions and special cases

- If weather_forecast_type == "inaccurate" and imperfect_forecast() returns no matching timestamps, the corresponding forecast column retains the ground-truth value (fallback to accurate forecast).
- Parameters weather_forecast_n_days_back and weather_forecast_weight_history default to 5 and 0.2 respectively when not present in parameters$forecast.
- If all predicted values are NA (e.g., at the very start of the series where no historical days exist), the original ground-truth values are kept unchanged.

## Diagram

![Block diagram of context_forecast_step.R](context_forecast_step.jpg)

Also available as [context_forecast_step.svg](context_forecast_step.svg).

---

[Back to the code structure index](../Code_Structure.md)
