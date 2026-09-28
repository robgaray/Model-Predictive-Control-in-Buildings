# -------------------------------------------------------------
# Function: compute_marginal_energy_cost.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Values a candidate energy schedule (from a single GA candidate's
# period_calculation() output) at its marginal (differential) cost
# relative to a fixed baseline, per target market interval, using the
# same calc_differential_cost() already used for post-hoc market
# accounting in integrate_market_process()/propagate_differential_cost().
# The candidate's per-timestep energy is first aggregated (SUM) per
# market interval, exactly as integrate_market_process() aggregates
# E_new_*_by_market, and explicitly aligned to the target-interval key
# (market_utc) rather than relying on any implicit ordering, since the
# candidate's own MarketUTC vector may not list intervals in the same
# order every time this is called (it is called once per GA candidate
# evaluated).
# -------------------------------------------------------------
# Inputs
# E_candidate         : Numeric vector. Per-timestep energy of the
#                       candidate being evaluated (e.g. Elec_total_plan,
#                       Elec_total_plan_flex_down or Elec_flex_down_plan of a
#                       period_chunk), one value per fine timestep.
# MarketUTC_candidate  : POSIXct vector, same length as E_candidate.
#                       Market interval of each fine timestep.
# market_utc          : POSIXct vector. Target market intervals, in
#                       the order matching every *_by_market argument
#                       below (as returned by resolve_marginal_context()).
# E_orig_by_market    : Numeric vector, same length/order as market_utc.
#                       Baseline commitment per target interval, before
#                       this market's optimization.
# P_import_buy_by_market, P_import_sell_by_market,
# P_export_buy_by_market, P_export_sell_by_market :
#                       Numeric vectors, same length/order as market_utc.
#                       Current-market prices per target interval, passed
#                       straight through to calc_differential_cost() (see
#                       that function's header for their meaning). A
#                       flexibility caller maps its own up/down prices
#                       into these same four slots.
# discount_by_market  : Numeric vector, same length/order as market_utc.
#                       Revenue discount factor of each target interval,
#                       as returned by revenue_discount_factor(). It
#                       weighs down the intervals whose cash flow is an
#                       income far from the decision instant, and only
#                       those - see apply_revenue_discount().
# -------------------------------------------------------------
# Outputs
# Numeric scalar. Total marginal cash flow (positive = net income,
# negative = net expense) of moving every target interval's commitment
# from E_orig_by_market to the candidate's aggregated commitment, with
# the income of each interval discounted by its own factor.
# -------------------------------------------------------------
# Code outline
# 1. Aggregate the candidate's energy per target market interval
# 2. Differential cost per interval, discounted, and total
# -------------------------------------------------------------
# Usage instructions
# cost <- compute_marginal_energy_cost(E_candidate, MarketUTC_candidate, market_utc, E_orig_by_market, P_import_buy_by_market, P_import_sell_by_market, P_export_buy_by_market, P_export_sell_by_market, discount_by_market)
# -------------------------------------------------------------
# Where this function/script is used
# Called by reward_function.R for the base-energy term (always) and,
# when optimization_aim is "flexibility" (Scheduling) or
# "operationflex" (Piloting) with an active flexibility event, for the
# explicit flexibility revenue term.
# -------------------------------------------------------------
# functions/scripts called
# market_slot_index() - which target slot each timestep belongs to
# aggregate_by_market_slot() - adds the candidate up on that index
# calc_differential_cost()
# apply_revenue_discount() - discounts the income of each interval
# -------------------------------------------------------------

compute_marginal_energy_cost <- function(E_candidate,
                                         MarketUTC_candidate,
                                         market_utc,
                                         E_orig_by_market,
                                         P_import_buy_by_market,
                                         P_import_sell_by_market,
                                         P_export_buy_by_market,
                                         P_export_sell_by_market,
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

  # 2. Differential cost per interval, discounted, and total
  # -------------------------------------------------------------
  {
    # calc_differential_cost() is called to value, per target market
    # interval, the move from the baseline commitment
    # (E_orig_by_market) to this candidate's aggregated commitment
    # (E_new_by_market), under the four asymmetric prices supplied by
    # the caller.
    cost_by_market <- calc_differential_cost(
      E_orig        = E_orig_by_market,
      E_new         = E_new_by_market,
      P_import_buy  = P_import_buy_by_market,
      P_import_sell = P_import_sell_by_market,
      P_export_buy  = P_export_buy_by_market,
      P_export_sell = P_export_sell_by_market
    )
    # apply_revenue_discount() is called so that an interval whose
    # differential cash flow is an income counts for less the further
    # away it is from the decision instant, while an expense keeps its
    # full weight. This is a decision-time weighting only: the same
    # move is settled undiscounted by integrate_market_process().
    total_cost <- sum(apply_revenue_discount(cost_by_market, discount_by_market))
    rm(cost_by_market)
  }

  rm(E_new_by_market)

  return(total_cost)
}
