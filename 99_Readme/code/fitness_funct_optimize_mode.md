# fitness_funct_optimize_mode.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/fitness_funct_optimize_mode.R`

## Function

This function is the fitness function used by the Genetic Algorithm in optimize_modes(). It converts an integer mode vector (one mode index per market period) into a structured setpoint data frame, evaluates the building simulation, and returns the resulting scalar reward.

## Called by

- [optimize_modes.R](optimize_modes.md)

## What it calls, in order of appearance

- [maxmode.R](maxmode.md)
- [convert_modes_to_setpoints.R](convert_modes_to_setpoints.md)
- [evaluate_control.R](evaluate_control.md)

## Input data

- x            : Integer vector of length n_periods. Each element is a mode index (integer value from 1 to n_modes) representing the active mode for that market period.
- n_modes      : Integer scalar. Number of available control modes.
- n_periods    : Integer scalar. Number of market periods in the optimization horizon.
- timestamps   : Named list. Timestamp metadata. Must contain: timestamps$target_periods : POSIXct vector of market period timestamps.
- parameters   : Named list. Model and control parameters. Must contain: parameters$setpoint_modes : Data frame mapping mode indices to setpoint values. parameters$control$Deadband : Numeric. Deadband. All other sub-elements required by evaluate_control().
- period_chunk : Data frame. Simulation data for the optimization horizon, as passed from optimize_modes(). Must contain all columns required by period_calculation() (called inside evaluate_control()).
- simulation_control : Named list. Simulation control object passed through to evaluate_control().
- marginal_context   : Named list or NULL. Passed through to evaluate_control().

## Output data

- evaluation : Numeric scalar. Reward value extracted from evaluate_control() return list for the given mode schedule. Higher is better.

## Other notes from the file header

### A candidate that cannot be evaluated

A chromosome carrying NA is not a building operation: it cannot be turned into setpoints and there is nothing to simulate. It is scored with a penalty large enough to be worse than any reachable reward, so the optimizer discards it, instead of being allowed to stop the run inside convert_modes_to_setpoints(). The chromosome should never arrive in that state - optimize_modes() sizes the elitism so that ga() cannot build one - and this is the net under that.

### Code outline

1. Create mode data frame from integer vector
2. Convert modes to setpoints
3. Evaluate control and compute reward

### Usage instructions

```r
fitness <- fitness_funct_optimize_mode(x, n_modes, n_periods, timestamps, parameters, period_chunk)
```

## Diagram

![Block diagram of fitness_funct_optimize_mode.R](fitness_funct_optimize_mode.jpg)

Also available as [fitness_funct_optimize_mode.svg](fitness_funct_optimize_mode.svg).

---

[Back to the code structure index](../Code_Structure.md)
