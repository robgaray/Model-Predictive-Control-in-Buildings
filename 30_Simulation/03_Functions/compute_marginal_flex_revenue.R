# -------------------------------------------------------------
# Function: compute_marginal_flex_revenue.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Values a candidate explicit-flexibility schedule (from a single GA
# candidate's period_calculation() output) at its marginal
# (differential) revenue relative to a fixed baseline, per target
# market interval, using value_flex_operation() - the down/up-leg
# valuation, NOT calc_differential_cost() (see that function's header
# for why explicit flexibility cannot be valued the same way energy
# is). Mirrors compute_marginal_energy_cost()'s structure: the
# candidate's per-timestep flexibility commitment is first aggregated
# (SUM) per market interval, exactly as integrate_market_process()
# aggregates E_new_expflex_by_market, and explicitly aligned to the
# target-interval key (market_utc) rather than relying on any implicit
# ordering, since the candidate's own MarketUTC vector may not list
# intervals in the same order every time this is called (it is called
# once per GA candidate evaluated).
# -------------------------------------------------------------
# Inputs
# E_candidate         : Numeric vector. Per-timestep explicit
#                       flexibility commitment of the candidate being
#                       evaluated (Elec_flex_plan of a period_chunk),
#                       one value per fine timestep.
# MarketUTC_candidate  : POSIXct vector, same length as E_candidate.
#                       Market interval of each fine timestep.
# market_utc          : POSIXct vector. Target market intervals, in
#                       the order matching every *_by_market argument
#                       below (as returned by resolve_marginal_context()).
# E_orig_by_market    : Numeric vector, same length/order as market_utc.
#                       Baseline commitment per target interval, before
#                       this market's optimization.
# price_down_sell_by_market, price_down_buy_by_market,
# price_up_sell_by_market, price_up_buy_by_market :
#                       Numeric vectors, same length/order as market_utc.
#                       Effective down/up flexibility prices per target
#                       interval, as returned by resolve_marginal_context().
# -------------------------------------------------------------
# Outputs
# Numeric scalar. Total marginal cash flow (positive = net income,
# negative = net expense) of moving every target interval's
# flexibility commitment from E_orig_by_market to the candidate's
# aggregated commitment.
# -------------------------------------------------------------
# Code outline
# 1. Aggregate the candidate's flexibility commitment per target
#    market interval
# 2. Net cash flow per interval and total
# -------------------------------------------------------------
# Usage instructions
# revenue <- compute_marginal_flex_revenue(E_candidate, MarketUTC_candidate, market_utc, E_orig_by_market, price_down_sell_by_market, price_down_buy_by_market, price_up_sell_by_market, price_up_buy_by_market)
# -------------------------------------------------------------
# Where this function/script is used
# Called by reward_function.R for the explicit flexibility revenue
# term, when optimization_aim is "flexibility" (Scheduling) or
# "operationflex" (Piloting) with an active flexibility event.
# -------------------------------------------------------------
# functions/scripts called
# value_flex_operation()
# -------------------------------------------------------------

compute_marginal_flex_revenue <- function(E_candidate,
                                          MarketUTC_candidate,
                                          market_utc,
                                          E_orig_by_market,
                                          price_down_sell_by_market,
                                          price_down_buy_by_market,
                                          price_up_sell_by_market,
                                          price_up_buy_by_market) {

  # 1. Aggregate the candidate's flexibility commitment per target
  #    market interval
  # -------------------------------------------------------------
  # Explicitly aligned to market_utc (not assumed order), since this
  # runs once per GA candidate.
  # -------------------------------------------------------------
  {
    E_new_by_market <- vapply(
      market_utc,
      function(mkt) sum(E_candidate[MarketUTC_candidate == mkt]),
      numeric(1)
    )
  }

  # 2. Net cash flow per interval and total
  # -------------------------------------------------------------
  {
    # value_flex_operation is called to resolve, per target market
    # interval, the move from the baseline commitment
    # (E_orig_by_market) to this candidate's aggregated commitment
    # (E_new_by_market), under the down/up prices supplied by the
    # caller.
    operation   <- value_flex_operation(
      E_orig          = E_orig_by_market,
      E_new           = E_new_by_market,
      price_down_sell = price_down_sell_by_market,
      price_down_buy  = price_down_buy_by_market,
      price_up_sell   = price_up_sell_by_market,
      price_up_buy    = price_up_buy_by_market
    )
    total_revenue <- sum(operation$revenue)
    rm(operation)
  }

  rm(E_new_by_market)

  return(total_revenue)
}
