# evaluate_control.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/evaluate_control.R`

## Function

This function evaluates the optimality of a control setpoint schedule over a particular period. This is a generic wrapper function that allows to integrate an optimizer with a simulation code in "period_calculation". It performs the following steps:

1. Calls period_calculation() to simulate the building over the period and stores results in *_plan columns of period_chunk_plan.
2. Calls derive_flex_itineraries() to build the *_plan_flex_down and *_plan_flex_up itineraries from the *_plan columns and the flexibility standing from earlier markets.
3. For "energy" mode, calls reward_function() directly on the plan columns.
4. For "flexibility" mode, performs a parametric evaluation over all market slots in period_chunk_plan as candidate flexibility event start points. For each market slot:
    - Skips if sum of Elec_total_plan is 0 or Flex_unit_cost_down_com_sell is 0
    - Tests expanding flexibility events by adding consecutive market slots, up to commitment_phase_length_max
    - Uses flexibility = 1 (full flexibility)
    - Stops expanding when Flex_unit_cost_down_com_sell is 0 or reward doesn't improve

The best reward across all candidates is returned.

## Called by

- [fitness_funct_optimize_mode.R](fitness_funct_optimize_mode.md)
- [fitness_funct_optimize_setpoint.R](fitness_funct_optimize_setpoint.md)
- [optimize_control_step.R](optimize_control_step.md)
- [run_market_process.R](run_market_process.md)

## What it calls, in order of appearance

- [period_calculation.R](period_calculation.md)
- [derive_flex_itineraries.R](derive_flex_itineraries.md)
- [reconstruct_flex_phases.R](reconstruct_flex_phases.md) &nbsp;(2 call sites)
- [reward_function.R](reward_function.md) &nbsp;(2 call sites)
- [flex_evaluation_down.R](flex_evaluation_down.md)
- [flex_evaluation_up.R](flex_evaluation_up.md)
- [resolve_flex_up_system.R](resolve_flex_up_system.md)

## Blocks

The piece calls 7 items, so it is documented in blocks:

- [Called items, block 1 of 2](evaluate_control__1.md)
- [Called items, block 2 of 2](evaluate_control__2.md)

## Input data

- period_chunk : Data frame. Simulation data for the period to evaluate. Must include the columns expected by period_calculation(), for example:
    - time
    - Text
    - SolarR
    - Occupancy
    - MarketUTC
    - Ti_plan
    - Te_plan
    - Act_heat_plan
    - Act_cool_plan
- set_point_df : Data frame. Setpoint schedule with hysteresis deadbands already applied, as returned by convert_setpoints() or convert_modes_to_setpoints().
- parameters   : Named list. Model and control parameters passed to period_calculation(), flex_evaluation_down(), and reward_function(). Must contain: parameters$control$optimization_aim : Character. "energy" or "flexibility". parameters$market$market_resolution : Numeric (minutes). Market slot duration used as the minimum Commitment Phase length step. parameters$control$commitment_phase_length_max : Numeric (hours). Longest Commitment Phase a candidate window may reach.
- simulation_control : Named list. Simulation control object. Used to pass these elements to flex_evaluation_down() and reward_function() via a cloned object:
    - simulation_control$indexes_local$i_flex
    - simulation_control$flexibility$commitment_phase_length
    - simulation_control$flexibility$flexibility
- marginal_context   : Named list or NULL (default NULL). Passed through to reward_function() (see resolve_marginal_context()).

## Output data

- A named list with the following elements (in this order):
- period_chunk : Data frame. The plan data frame corresponding to the best flexibility scenario found (for "flexibility" mode), or the plan data frame itself (for "energy" mode). Always contains a 'Reward' column with the per-row reward values as set by reward_function().
- reward       : Numeric scalar. Sum of per-row reward values in period_chunk$Reward. Best reward found over all flexibility candidate market slots (for "flexibility" mode), or the direct reward from the plan (for "energy" mode).

## Other notes from the file header

### Code outline

1. Run period_calculation for plan context
2. Derive the *_plan_flex_down and *_plan_flex_up itineraries from *_plan and the standing commitment
3. Evaluate flexibility scenarios (if optimization_aim is flexibility): phase A downward, then phase B upward
4. Compute reward function
5. Return results

### Usage instructions

```r
result <- evaluate_control(period_chunk, set_point_df, parameters, simulation_control)
```

### Exceptions and special cases

- Simulation results are stored under execution column names (no suffix) and then aliased to *_plan columns before reward_function() is called, so that reward_function() can read Comfort_plan, Elec_total_plan, etc.
- For "flexibility" mode, evaluate_control() always initializes the *_plan_flex_down and *_plan_flex_up columns before searching. The downward loop skips market slots whose Elec_total_plan sums to (effectively) zero in absolute value, or where Flex_unit_cost_down_com_sell is 0 (no flexibility profit available). The absolute value matters: a slot with a net export sums to a negative number and is still a candidate for down-flexibility.
- Accepted flexibility windows never overlap WITHIN a leg, and the window that is skipped over is the WHOLE one: Commitment, Neutral and Recovery. When a window whose Commitment Phase is n slots is accepted at slot i, the outer loop resumes past slot i + n + the slots the Neutral and Recovery Phases take, so a later window can neither rewrite the columns of a stretch already committed nor start while the building is still recovering. The outer loop is a while loop for this reason.
- Windows of DIFFERENT legs may overlap, and that is intended. The two searches run one after the other over their own set of columns, so a slot can carry a downward commitment and an upward one at the same time; physically they are two different itineraries and neither is flown unless the operator calls it.
- The two searches share one algorithm, written once and told which leg it works on. The legs differ only in three filters: the price column that gates a slot, the null-planned-energy skip (downward only - a slot planning no energy has nothing to switch off, but it can always switch something on), and the dominant-system pre-filter (upward only).
- A candidate window may close on the last market slot of period_chunk, but it is never accepted: flex_evaluation_down()/ flex_evaluation_up() return the chunk untouched when the time left from i_flex to the close of the control horizon does not cover the Commitment, Neutral and Recovery Phases, and a window closing that late never does. The reward then comes back unchanged and the inner loop breaks.
- A candidate window never grows past commitment_phase_length_max. The Commitment Phase is assembled from whole market slots, so the bound is applied as floor(commitment_phase_length_max / market_slot_h) slots. When commitment_phase_length_max is shorter than one market slot no window is admissible and no flexibility is committed, because a maximum below the resolution of the market the commitment is sold on cannot be expressed on that market's grid.
- If all market slots are skipped in "flexibility" mode, the returned reward is the baseline reward without flexibility.
- commitment_phase_length and flexibility are set in simulation_control$flexibility and passed through to flex_evaluation_down() and reward_function() via a cloned simulation_control_2 object.
- COMPUTATIONAL COST: for "flexibility"/"operationflex" mode, the outer loop visits each of the L unique market slots of period_chunk at most once (accepted windows are skipped over, not re-entered), and for each starting slot the inner while loop keeps expanding the candidate flexibility window as long as the reward keeps improving, calling flex_evaluation_down() + reward_function() once per expansion step. The expansion stops at M = floor(commitment_phase_length_max / market_slot_h) slots, so the inner loop is bounded by M rather than by the horizon: worst case is O(M) calls per starting slot and O(L * M) overall, each itself proportional to the flexibility window size via period_calculation(). This function is in turn evaluated once per GA individual per generation by optimize_control_step()/fitness_funct_optimize_setpoint(), so a longer optimization horizon (larger L) or a larger GA population/generation count multiplies this cost accordingly. Keep the Piloting optimization horizon and GA population/generation settings conservative for long horizons.

## Diagram

![Block diagram of evaluate_control.R](evaluate_control.jpg)

Also available as [evaluate_control.svg](evaluate_control.svg).

---

[Back to the code structure index](../Code_Structure.md)
