# optimize_control_step.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/optimize_control_step.R`

## Function

This function performs the optimization of the control strategy for a single MPC step. It selects either setpoint-based or mode-based optimization depending on control_type, and then computes the forecasted building states resulting from the optimized setpoints. It performs the following steps:

1. Calls optimize_setpoints() or optimize_modes() according to control_type to find the optimal control schedule (each of these already returns a set_point_df with hysteresis deadbands, built internally via convert_setpoints()).
2. Calls evaluate_control() with the optimized setpoints to compute the expected building states under forecasted weather (period_calculation() internally reads Text_forec/SolarR_forec instead of Text/SolarR for the "plan"/"plan_flex_down" calculation contexts; period_chunk$Text/ SolarR are not overwritten).

## Called by

- [run_market_process.R](run_market_process.md)

## What it calls, in order of appearance

- [optimize_setpoints.R](optimize_setpoints.md)
- [optimize_modes.R](optimize_modes.md)
- [evaluate_control.R](evaluate_control.md)

## Input data

- period_chunk             : Data frame. Simulation data for the optimization horizon. Must contain 'Text_forec', 'SolarR_forec', 'Text', 'SolarR', and all columns required by period_calculation().
- timestamps               : Named list. Timestamp metadata, passed through to optimize_setpoints()/optimize_modes() and to evaluate_control(). Must contain timestamps$target_periods (POSIXct vector of market period timestamps for the optimization horizon).
- parameters               : List. Model parameters passed to period_calculation() and reward_function(). The following sub-elements are extracted internally: parameters$control$control_type parameters$control$set_point_range_heating parameters$control$set_point_range_cooling parameters$control$Deadband parameters$control$optimization_aim parameters$optimization parameters$setpoint_modes
- simulation_control        : Named list. Index/step metadata, passed through to optimize_setpoints()/optimize_modes() and evaluate_control() for interface consistency.
- marginal_context          : Named list or NULL (default NULL). Passed through to optimize_setpoints()/optimize_modes() and to the final evaluate_control() call.

## Output data

- A named list with two elements: set_point_actual : Data frame. Optimized setpoint schedule with histeresis deadbands for the target periods, as returned by optimize_setpoints() or optimize_modes(). period_chunk     : Data frame. Expected building states under the optimized setpoints and forecasted weather, corresponding to the best flexibility scenario found (period_chunk from evaluate_control()). Contains all columns returned by period_calculation() plus these *_plan columns:
    - Ti_plan
    - Te_plan
    - STP_heat_low_plan
    - STP_heat_high_plan
    - STP_cool_low_plan
    - STP_cool_high_plan
    - Act_heat_plan
    - Act_cool_plan
    - Q_heat_plan
    - Q_cool_plan
    - Elec_heat_plan
    - Elec_cool_plan
    - Elec_total_plan

and these *_flex columns, representing the best flexibility scenario (Q=0 over the optimal window):

- Ti_plan_flex_down
- Te_plan_flex_down
- STP_heat_low_plan_flex_down
- STP_heat_high_plan_flex_down
- STP_cool_low_plan_flex_down
- STP_cool_high_plan_flex_down
- Act_heat_plan_flex_down
- Act_cool_plan_flex_down
- Q_heat_plan_flex_down
- Q_cool_plan_flex_down
- Elec_heat_plan_flex_down
- Elec_cool_plan_flex_down
- Elec_total_plan_flex_down
- Elec_flex_down_plan
- Elec_flex_com_revenue_plan
- Elec_flex_exec_revenue_plan

The last two are reward_function()'s own internal/transient columns (see that function's header), unrelated to any persisted Main_df column.

## Other notes from the file header

### Code outline

1. Dispatch to optimize_setpoints() or optimize_modes() according to control_type
2. Run evaluate_control() with the optimized setpoints and forecasted weather to compute expected building states
3. Return the optimized set_point_actual and period_chunk

### Usage instructions

```r
result <- optimize_control_step(period_chunk, timestamps, parameters, simulation_control)
```

### Exceptions and special cases

- If control_type is neither "setpoints" nor "modes", the function raises an error via stop().
- Parallelization is initialized inside optimize_setpoints() and optimize_modes(); the cluster is stopped within those functions.

## Diagram

![Block diagram of optimize_control_step.R](optimize_control_step.jpg)

Also available as [optimize_control_step.svg](optimize_control_step.svg).

---

[Back to the code structure index](../Code_Structure.md)
