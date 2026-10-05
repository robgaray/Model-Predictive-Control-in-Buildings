# -------------------------------------------------------------
# Function: compute_marginal_distribution_cost.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Values a candidate energy schedule (from a single GA candidate's
# period_calculation() output) at its marginal (differential)
# distribution-cost impact relative to a fixed baseline, per target
# market interval. Unlike compute_marginal_energy_cost(), this does NOT
# use calc_differential_cost(): buying, selling, unbuying ("descompra")
# and unselling ("desventa") energy all incur the same distribution
# rate regardless of direction, so the whole 8-branch buy/sell/unwind
# casuistry collapses to a single formula, valuing only how the gross
# magnitude of the commitment changes:
#   cost = -distribution_rate * (abs(E_new) - abs(E_orig))
# Growing the commitment (buying more or selling more) always adds
# distribution cost, i.e. makes the result more negative; shrinking it
# ("descompra"/"desventa") always reduces it; crossing from import to
# export (or back) is handled automatically, without any explicit
# branch, because abs(E) already passes through its minimum exactly at
# the crossing point. This single formula reproduces the same
# casuistry as the 4-branch buy/sell/unwind logic, branch by branch.
# Its sign is set so that, like every other economic term in this
# repository, an expense is negative and never a positive number that
# has to be remembered and subtracted.
# Only used for the base-energy term of reward_function() - explicitly
# not applied to flexibility.
# -------------------------------------------------------------
# Inputs
# E_candidate         : Numeric vector. Per-timestep energy of the
#                       candidate being evaluated (Elec_total_plan of a
#                       period_chunk), one value per fine timestep.
# MarketUTC_candidate  : POSIXct vector, same length as E_candidate.
#                       Market interval of each fine timestep.
# market_utc          : POSIXct vector. Target market intervals, in
#                       the order matching every *_by_market argument
#                       below (as returned by resolve_marginal_context()).
# E_orig_by_market    : Numeric vector, same length/order as market_utc.
#                       Baseline commitment per target interval, before
#                       this market's optimization.
# distribution_rate_by_market :
#                       Numeric vector, same length/order as market_utc.
#                       Current-market Elec_unit_cost_distribution rate
#                       per target interval.
# discount_by_market  : Numeric vector, same length/order as market_utc.
#                       Revenue discount factor of each target interval,
#                       as returned by revenue_discount_factor(). It has
#                       no effect on this term, whose every non-zero
#                       entry is an expense - see the call site.
# -------------------------------------------------------------
# Outputs
# Numeric scalar. Total marginal distribution cost (negative = added
# cost, positive = reduced cost) of moving every target interval's
# commitment from E_orig_by_market to the candidate's aggregated
# commitment.
# -------------------------------------------------------------
# Code outline
# 1. Aggregate the candidate's energy per target market interval
# 2. Distribution cost per interval, discounted, and total
# -------------------------------------------------------------
# Usage instructions
# cost <- compute_marginal_distribution_cost(E_candidate, MarketUTC_candidate, market_utc, E_orig_by_market, distribution_rate_by_market)
# -------------------------------------------------------------
# Where this function/script is used
# Called by reward_function.R for the base-energy term only.
# -------------------------------------------------------------
# functions/scripts called
# market_slot_index() - which target slot each timestep belongs to
# aggregate_by_market_slot() - adds the candidate up on that index
# apply_revenue_discount() - discounts each slot's cost to the
#   instant the decision is taken
# -------------------------------------------------------------

compute_marginal_distribution_cost <- function(E_candidate,
                                               MarketUTC_candidate,
                                               market_utc,
                                               E_orig_by_market,
                                               distribution_rate_by_market,
                                               discount_by_market) {

  # 1. Aggregate the candidate's energy per target market interval
  # -------------------------------------------------------------
  # Explicitly aligned to market_utc (not assumed order), since this
  # runs once per GA candidate.
  # -------------------------------------------------------------
  {
    # market_slot_index is called to say which target slot each timestep
    # of the candidate belongs to, and aggregate_by_market_slot to add
    # the candidate up on that index. Together they replace a walk that
    # masked the candidate once per slot, comparing two POSIXct vectors
    # on every step; the totals are the same bit for bit, and the
    # ordering of the sums is what guarantees it.
    E_new_by_market <- aggregate_by_market_slot(
      values     = E_candidate,
      slot_index = market_slot_index(MarketUTC_candidate, market_utc)
    )
  }

  # 2. Distribution cost per interval, discounted, and total
  # -------------------------------------------------------------
  {
    cost_by_market <- -distribution_rate_by_market *
      (abs(E_new_by_market) - abs(E_orig_by_market))
    # apply_revenue_discount() is called for consistency with the rest
    # of the economic terms rather than for effect: this term is an
    # expense in every interval where it is not zero (moving energy in
    # either direction adds distribution cost), so no entry is ever
    # positive and the factors leave it untouched. Applying it here
    # means a later change of sign convention in this term would be
    # weighted by the same rule without anyone having to remember it.
    total_cost <- sum(apply_revenue_discount(cost_by_market, discount_by_market))
    rm(cost_by_market)
  }

  rm(E_new_by_market)

  return(total_cost)
}
