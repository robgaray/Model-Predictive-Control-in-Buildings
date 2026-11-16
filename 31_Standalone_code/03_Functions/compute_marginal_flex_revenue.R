# -------------------------------------------------------------
# Function: compute_marginal_flex_revenue.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Values a candidate explicit-flexibility schedule (from a single GA
# candidate's period_calculation() output) at its marginal
# (differential) revenue relative to a fixed baseline, per target
# market interval, using value_flex_operation() - the down/up-leg
# valuation, NOT calc_differential_cost() (see that function's header
# for why explicit flexibility cannot be valued the same way energy
# is). Mirrors compute_marginal_energy_cost()'s structure: the
# candidate's per-timestep flexibility commitment is first aggregated
# (SUM) per market interval, exactly as compute_market_operations()
# aggregates E_by_market$new, and explicitly aligned to the
# target-interval key (market_utc) rather than relying on any implicit
# ordering, since the candidate's own MarketUTC vector may not list
# intervals in the same order every time this is called (it is called
# once per GA candidate evaluated).
# -------------------------------------------------------------
# Inputs
# E_candidate         : Numeric vector. Per-timestep explicit
#                       flexibility commitment of the candidate being
#                       evaluated, one value per fine timestep. It is one
#                       leg's signal, not both: Elec_flex_down_plan for
#                       the down leg, -Elec_flex_up_plan for the up leg,
#                       since value_flex_operation() tells the two apart
#                       by sign and both signals are non-negative.
# slot_index          : Factor, same length as E_candidate.
#                       Target market interval of each fine
#                       timestep, as returned by
#                       market_slot_index(); its levels follow
#                       the order of every *_by_market argument
#                       below.
# E_orig_by_market    : Numeric vector, same length/order as
#                       the levels of slot_index.
#                       Baseline commitment per target interval, before
#                       this market's optimization.
# price_down_sell_by_market, price_down_buy_by_market,
# price_up_sell_by_market, price_up_buy_by_market :
#                       Numeric vectors, same length/order as
#                       the levels of slot_index.
#                       Effective down/up flexibility prices per target
#                       interval, as returned by resolve_marginal_context().
# discount_by_market  : Numeric vector, same length/order as
#                       the levels of slot_index.
#                       Revenue discount factor of each target interval,
#                       as returned by revenue_discount_factor(). It
#                       weighs down the intervals that pay and only
#                       those - see apply_revenue_discount().
# capped_by_market    : Logical vector, same length/order as the levels
#                       of slot_index. TRUE for the target intervals
#                       whose commitment no market may change yet,
#                       those after the close of the control horizon.
#                       There the candidate is valued at most at the
#                       baseline commitment.
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
# 2. Cap the intervals whose commitment may not change
# 3. Net cash flow per interval, discounted, and total
# -------------------------------------------------------------
# Usage instructions
# revenue <- compute_marginal_flex_revenue(E_candidate, slot_index,
# E_orig_by_market, price_down_sell_by_market, price_down_buy_by_market,
# price_up_sell_by_market, price_up_buy_by_market, discount_by_market,
# capped_by_market)
# -------------------------------------------------------------

compute_marginal_flex_revenue <- function(E_candidate,
                                          slot_index,
                                          E_orig_by_market,
                                          price_down_sell_by_market,
                                          price_down_buy_by_market,
                                          price_up_sell_by_market,
                                          price_up_buy_by_market,
                                          discount_by_market,
                                          capped_by_market) {

  # 1. Aggregate the candidate's flexibility commitment per target
  #    market interval
  # -------------------------------------------------------------
  # Explicitly aligned to the target intervals (not assumed
  # order), since this runs once per GA candidate.
  # -------------------------------------------------------------
  {
    # aggregate_by_market_slot is called to add the candidate up on
    # slot_index, the target interval of each timestep, which the
    # caller resolves once with market_slot_index(). The order of the
    # sums is fixed by the index, so the totals do not depend on how
    # the rows are laid out.
    E_new_by_market <- aggregate_by_market_slot(
      values     = E_candidate,
      slot_index = slot_index
    )
  }

  # 2. Cap the intervals whose commitment may not change
  # -------------------------------------------------------------
  # After the close of the control horizon the commitment earlier
  # markets sold stands: this market does not trade it, and a later
  # market will restate it in its own control horizon. A candidate
  # that holds it is therefore worth nothing there, and one that
  # falls short costs the re-purchase that later market will have to
  # make. A candidate that would draw more is not selling anything,
  # so it is valued at the commitment that stands. Each leg's signal
  # keeps one sign, so the cap is taken on the magnitude.
  # -------------------------------------------------------------
  {
    E_new_by_market[capped_by_market] <-
      sign(E_orig_by_market[capped_by_market]) *
      pmin(abs(E_new_by_market[capped_by_market]),
           abs(E_orig_by_market[capped_by_market]))
  }

  # 3. Net cash flow per interval, discounted, and total
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
    # apply_revenue_discount() is called on the per-interval revenue,
    # so that selling a service far into the future weighs less in the
    # decision than selling the same service in the next slot. Only the
    # intervals that pay are discounted; one that costs money keeps its
    # full weight.
    total_revenue <- sum(apply_revenue_discount(operation$revenue, discount_by_market))
    rm(list = "operation")
  }

  rm(list = "E_new_by_market")

  return(total_revenue)
}
