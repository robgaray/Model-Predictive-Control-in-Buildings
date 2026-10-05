# compute_marginal_distribution_cost.R

**Function** &nbsp;·&nbsp; `30_Simulation/03_Functions/compute_marginal_distribution_cost.R`

## Function

Values a candidate energy schedule (from a single GA candidate's period_calculation() output) at its marginal (differential) distribution-cost impact relative to a fixed baseline, per target market interval. Unlike compute_marginal_energy_cost(), this does NOT use calc_differential_cost(): buying, selling, unbuying ("descompra") and unselling ("desventa") energy all incur the same distribution rate regardless of direction, so the whole 8-branch buy/sell/unwind casuistry collapses to a single formula, valuing only how the gross magnitude of the commitment changes:

- cost = -distribution_rate * (abs(E_new) - abs(E_orig))

Growing the commitment (buying more or selling more) always adds distribution cost, i.e. makes the result more negative; shrinking it ("descompra"/"desventa") always reduces it; crossing from import to export (or back) is handled automatically, without any explicit branch, because abs(E) already passes through its minimum exactly at the crossing point. This single formula reproduces the same casuistry as the 4-branch buy/sell/unwind logic, branch by branch. Its sign is set so that, like every other economic term in this repository, an expense is negative and never a positive number that has to be remembered and subtracted. Only used for the base-energy term of reward_function() - explicitly not applied to flexibility.

## Called by

- [reward_function.R](reward_function.md)

## What it calls, in order of appearance

- [aggregate_by_market_slot.R](aggregate_by_market_slot.md)
- [market_slot_index.R](market_slot_index.md)
- [apply_revenue_discount.R](apply_revenue_discount.md)

## Input data

- E_candidate         : Numeric vector. Per-timestep energy of the candidate being evaluated (Elec_total_plan of a period_chunk), one value per fine timestep.
- MarketUTC_candidate  : POSIXct vector, same length as E_candidate. Market interval of each fine timestep.
- market_utc          : POSIXct vector. Target market intervals, in the order matching every *_by_market argument below (as returned by resolve_marginal_context()).
- E_orig_by_market    : Numeric vector, same length/order as market_utc. Baseline commitment per target interval, before this market's optimization.
- distribution_rate_by_market : Numeric vector, same length/order as market_utc. Current-market Elec_unit_cost_distribution rate per target interval.
- discount_by_market  : Numeric vector, same length/order as market_utc. Revenue discount factor of each target interval, as returned by revenue_discount_factor(). It has no effect on this term, whose every non-zero entry is an expense - see the call site.

## Output data

- Numeric scalar. Total marginal distribution cost (negative = added cost, positive = reduced cost) of moving every target interval's commitment from E_orig_by_market to the candidate's aggregated commitment.

## Other notes from the file header

### Code outline

1. Aggregate the candidate's energy per target market interval
2. Distribution cost per interval, discounted, and total

### Usage instructions

```r
cost <- compute_marginal_distribution_cost(E_candidate, MarketUTC_candidate, market_utc, E_orig_by_market, distribution_rate_by_market)
```

## Diagram

![Block diagram of compute_marginal_distribution_cost.R](compute_marginal_distribution_cost.jpg)

Also available as [compute_marginal_distribution_cost.svg](compute_marginal_distribution_cost.svg).

---

[Back to the code structure index](../Code_Structure.md)
