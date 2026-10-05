# reward_function.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/reward_function.R`

## Function

This function calculates a reward function on the adequacy of a particular building HVAC operation over a planning period. It reads a period_chunk data frame and operates in two modes depending on parameters$control$optimization_aim:

- "energy"      - minimise energy cost while maintaining comfort
- "flexibility" - additionally account for flexibility revenue

Comfort is always evaluated over the full simulated energy flow of each itinerary:

- Elec_total_plan
- Elec_total_plan_flex_down
- Elec_total_plan_flex_up

since the building's thermal evolution depends on the full energy applied. The economic terms are always valued at their marginal (differential) cash flow relative to whatever was already committed for the same market intervals by an earlier market process, at the current market's prices - see compute_marginal_energy_cost() and resolve_marginal_context(). marginal_context is mandatory: there is no no-context fallback. A previous fallback that valued the full candidate commitment directly (ignoring the differential baseline) was removed because it could silently mask a missing or broken marginal-cost chain upstream (e.g. a caller that forgot to call resolve_marginal_context()) instead of surfacing it as an error. In addition to the energy price, the base-energy term also accounts for the marginal distribution cost (Elec_unit_cost_distribution), via compute_marginal_distribution_cost(). This is a decision-time-only consideration (it is never written to market_commitments, only to Reward): buying or selling energy always adds distribution cost, unbuying ("descompra") or unselling ("desventa") always reduces it, regardless of direction - it does not apply to the explicit-flexibility term.

## Called by

- [evaluate_control.R](evaluate_control.md)
- [run_market_process.R](run_market_process.md)

## What it calls, in order of appearance

- [revenue_discount_factor.R](revenue_discount_factor.md)
- [compute_marginal_energy_cost.R](compute_marginal_energy_cost.md)
- [compute_marginal_distribution_cost.R](compute_marginal_distribution_cost.md)
- [flex_window_is_feasible.R](flex_window_is_feasible.md)
- [compute_marginal_flex_revenue.R](compute_marginal_flex_revenue.md) &nbsp;(4 call sites)
- [compute_recovery_energy_cost.R](compute_recovery_energy_cost.md) &nbsp;(2 call sites)

## Input data

- period_chunk             : Data frame. Planning-period data with *_plan (and, for "flexibility" mode, *_plan_flex_down and *_plan_flex_up) columns produced by period_calculation() and flex_evaluation_down(). Required columns: time             - POSIXct. Simulation timestamps. MarketUTC        - POSIXct. Market interval of each row. Comfort_plan     - Numeric (0/1). Comfort flag (plan). Elec_total_plan  - Numeric. Total electricity (plan). Additional columns required for "flexibility" mode: Comfort_plan_flex_down    - Numeric (0/1). Comfort flag (plan_flex_down). Elec_total_plan_flex_down - Numeric. Total electricity (plan_flex_down). Comfort_plan_flex_up      - Numeric (0/1). Comfort flag (plan_flex_up). Elec_total_plan_flex_up   - Numeric. Total electricity (plan_flex_up).
- parameters               : Named list. Must contain: parameters$reward$alpha_comfort : Numeric (1/h). Weight applied to the comfort penalty term. Mandatory: stop() is raised if absent. parameters$reward$alpha_cost    : Numeric (1/EUR). Weight applied to every economic term. Mandatory: stop() is raised if absent. parameters$control$optimization_aim : Character. "energy", "operation", "flexibility", or "operationflex".
- simulation_control       : Named list. Simulation control object. Must contain: simulation_control$indexes_local$i_flex : Integer scalar. Row number in period_chunk at which the flexibility event starts. Defaults to 1 when NULL or absent. simulation_control$flexibility$commitment_phase_length : Numeric scalar. Duration of the Commitment Phase (h). Only used to decide whether a "flexibility" aim still behaves as "energy" (see EXCEPTIONS below); not used for any economic calculation.
- marginal_context          : Named list. Mandatory (no default). As returned by resolve_marginal_context(), with:
    - market_utc
    - E_orig_base_by_market
    - E_orig_expflex_down_by_market
    - E_orig_expflex_up_by_market
    - P_import_buy_by_market
    - P_import_sell_by_market
    - P_export_buy_by_market
    - P_export_sell_by_market
    - distribution_rate_by_market
    - p_up_buy_by_market
    - p_up_sell_by_market
    - p_down_buy_by_market
    - p_down_sell_by_market (the four flex prices are per leg, "up"/"down", not "import"/"export" - see value_flex_operation())
    - revenue_discount_by_market
    - revenue_discount_per_hour
    - discount_origin_time

stop()s if NULL, and also if it carries no revenue discount.

## Output data

- period_chunk : Data frame. The input data frame with a 'Reward' column added (or overwritten) containing the per-row reward value for each timestep, plus the following intermediate result columns (all modes): Elec_Cost_plan              - Numeric. Electricity cost. The whole interval-aggregated marginal cost is concentrated on the last row (this column is not meaningful per-timestep; only its sum matters). Elec_Cost_distribution_plan - Numeric. Marginal distribution cost (base-energy term only), same last-row concentration as Elec_Cost_plan. Additional columns added in "flexibility" mode: Elec_flex_down_plan        - Numeric. Energy difference (plan - plan_flex_down), bounded to the Commitment Phase: it is 0 wherever Flex_phase_down_plan is not 1. Elec_flex_up_plan          - Numeric. Energy difference (plan_flex_up - plan), bounded the same way to Flex_phase_up_plan == 1 and to 0 from below. Both signals are non-negative by construction. Elec_flex_com_revenue_plan  - Numeric. Certain revenue of the flexibility commitment, at the commitment price alone (same last-row concentration as Elec_Cost_plan). Elec_flex_exec_revenue_plan - Numeric. Expected revenue of the execution: the execution price weighted by the activation probability, plus the energy the Recovery Phase would move if the service were called. Same last-row concentration. The caller is responsible for summing the Reward column when a scalar reward is required.

## Other notes from the file header

### The reward is dimensionless

The two weights are what make it so, and they are kept apart on purpose. alpha_comfort is in 1/h and multiplies the comfort term, which is measured in hours out of comfort; alpha_cost is in 1/EUR and multiplies every economic term, which are in EUR. The reward is therefore a pure number, and what governs the optimizer's behaviour is the ratio between the two weights, not either of them on its own. Splitting the old single weight in two also leaves room for more complex price structures later: a new economic term only needs to be added inside the alpha_cost bracket to be weighted consistently with the rest.

### Revenue discount

Income that is far away in time weighs less in the decision than the same income in the next slot. Every economic term is therefore valued per market interval and, where that interval's cash flow turns out to be an income, multiplied by (1 - Revenue_discount_per_hour/100)^n, with n the hours from the decision instant to that interval - see revenue_discount_factor() and apply_revenue_discount(). Expense is never discounted, and neither is the comfort term: prudence is about what the building expects to earn, not about what it will spend or about whether people are comfortable. The discount belongs to the decision and stops there. What the winning candidate is then paid is settled by integrate_market_process() at the market's own prices, so neither the volume nor the price of any commitment carries it.

### Sign convention

Every economic term (Elec_Cost_plan, Elec_Cost_distribution_plan, Elec_flex_com_revenue_plan, Elec_flex_exec_revenue_plan) already carries the sign of its cash flow: positive = income, negative = expense (see calc_differential_cost(), compute_marginal_distribution_cost() and value_flex_operation()). Reward is therefore a pure sum of the comfort term and every economic term, never a mix of "+" and "-" that has to be remembered per term. The explicit-flexibility term is valued via compute_marginal_flex_revenue(), not compute_marginal_energy_cost(): explicit flexibility is a service sold to the grid in two independent down/up legs, not a single position that flips sign like energy import/export - see value_flex_operation()'s header for the full explanation of why the two cannot share the same valuation machinery.

### Code outline

1. Extract the alpha_comfort and alpha_cost parameters
2. Extract i_flex and commitment_phase_length from simulation_control
3. Calculate delta_t per timestep

3b. Resolve the revenue discount factors, per market interval and per row

4. Compute electricity cost (marginal) and distribution cost (marginal)

4c. Technical feasibility of the flexibility itineraries

5. Mode-specific reward (energy or flexibility)
6. Store per-row reward in data frame

### Usage instructions

```r
result_df <- reward_function(period_chunk, parameters, simulation_control, marginal_context)
```

### Exceptions and special cases

- If marginal_context is NULL, stop() is called immediately (see header).
- If parameters$reward$alpha_comfort or parameters$reward$alpha_cost is NULL, stop() is called immediately (no default value is used).
- If marginal_context carries no revenue discount, stop() is called immediately. Treating its absence as "no discount" would silently turn a broken context into a valid-looking optimization run at a different, undeclared prudence.
- delta_t for the first row is set to 0 (no prior timestep). It is expressed in hours, so that alpha_comfort (1/h) times it yields a dimensionless number, the same as alpha_cost (1/EUR) times each economic term (EUR).
- If optimization_aim is none of "energy", "operation", "flexibility" or "operationflex", stop() is called.
- In every mode, the comfort penalty applies to every time step where ANY of Comfort_plan, Comfort_plan_flex_down or Comfort_plan_flex_up is 0 (out of its own band), occupied or not.
- When simulation_control$indexes_local$i_flex is NULL, it defaults to 1 (first row).
- When simulation_control$flexibility$commitment_phase_length is NULL, it falls back to parameters$control$commitment_phase_length_max.
- The flexibility revenue term does not distinguish a "commitment window" vs "execution/Recovery Phase": Elec_flex_down_plan is aggregated per market interval over the whole period_chunk and valued at that interval's own effective up/down flexibility price, which already values any post-event rebound at its own interval's price instead of forcing every revenue component onto the flex event's own price.

## Diagram

![Block diagram of reward_function.R](reward_function.jpg)

Also available as [reward_function.svg](reward_function.svg).

---

[Back to the code structure index](../Code_Structure.md)
