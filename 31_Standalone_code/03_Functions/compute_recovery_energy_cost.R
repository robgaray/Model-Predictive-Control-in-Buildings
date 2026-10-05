# -------------------------------------------------------------
# Function: compute_recovery_energy_cost.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Values the energy a flexibility event would move during its
# Recovery Phase, weighted by the probability that the event is
# actually called, for one leg of the service.
# -------------------------------------------------------------
# Why this term exists
# Executing a flexibility commitment is not free for the building.
# Once the event and the recovery are over, the thermostat takes over
# again and the building spends the Recovery Phase returning to
# the state it would have been in, buying or selling energy it had not
# planned to. The flexibility prices pay the commitment and the
# expected execution, and say nothing about that energy, so this term
# values it.
# Only the Recovery Phase is valued, and not by convention: the
# Commitment Phase's own energy is assumed to be already remunerated by
# the execution price, and during the Neutral Phase the deviation is
# exactly zero by construction. The Neutral Phase is simulated in
# calculation_mode 2, which reads the power of every step from the Q_*
# columns, and those columns still hold the copy of the _plan itinerary
# that derive_flex_itineraries() laid as baseline, since the flexibility
# evaluation only overwrites the rows of the Commitment Phase. As the
# simulation loop derives electricity from Q and the outdoor
# temperature alone, the flexibility itinerary and the plan spend
# exactly the same in every Neutral Phase row.
# -------------------------------------------------------------
# Every row of the window is valued
# The energy the building moves while recovering is bought or sold
# whenever it happens. A flexibility window never runs past the rows
# of the period_chunk, and every row of the period_chunk that can hold
# a window falls in an interval of the market being optimized, so every
# Recovery Phase row is valued with that market's prices and
# probability.
# -------------------------------------------------------------
# The baseline is the plan, not the market position
# The deviation is measured against the building's own plan, not
# against what was committed in an earlier market. This is a
# conditional scenario - "if I am called, my profile would be this one
# instead of that one" - rather than a change of commitment towards the
# market. Being a differential against the plan, it does not double
# count with the base-energy term of the reward, which values
# Elec_total_plan against the previous commitment.
# -------------------------------------------------------------
# Inputs
#   E_plan              : Numeric vector. Per-timestep electricity of the
#                         baseline itinerary (Elec_total_plan), kWh.
#   E_flex              : Numeric vector, same length. Per-timestep
#                         electricity of the flexibility itinerary of
#                         this leg (Elec_total_plan_flex_down or
#                         Elec_total_plan_flex_up), kWh.
#   phase               : Numeric/integer vector, same length. Phase code
#                         of each timestep for this leg
#                         (Flex_phase_down_plan or Flex_phase_up_plan).
#                         Only the rows of phase 3 are valued.
#   MarketUTC_candidate : POSIXct vector, same length. Market interval of
#                         each timestep.
#   market_utc          : POSIXct vector. Target market intervals, in the
#                         order matching every *_by_market argument
#                         (as returned by resolve_marginal_context()).
#   P_import_buy_by_market, P_import_sell_by_market,
#   P_export_buy_by_market, P_export_sell_by_market :
#                         Numeric vectors, same length/order as
#                         market_utc. Energy prices of each target
#                         interval.
#   probability_by_market : Numeric vector in [0, 1], same length/order
#                         as market_utc. Activation probability of this
#                         leg in each target interval.
#   discount_by_market  : Numeric vector, same length/order as
#                         market_utc. Revenue discount factor of each
#                         target interval, as returned by
#                         revenue_discount_factor().
# -------------------------------------------------------------
# Outputs
#   Numeric scalar. Expected cash flow of the Recovery Phase deviation
#   across every target interval, with the repository's sign convention:
#   income positive, expense negative, and the income of each interval
#   discounted by its own factor.
# -------------------------------------------------------------
# Code outline
# 1. Market intervals holding a Recovery Phase row
# 2. Prices and probability of each of those intervals
# 3. Aggregate the two itineraries over the Recovery Phase rows
# 4. Value the deviation of each interval, weight it by probability and
#    discount its income
# -------------------------------------------------------------
# Usage instructions
# dC_recov <- compute_recovery_energy_cost(E_plan, E_flex, phase,
#              MarketUTC_candidate, market_utc, P_import_buy_by_market,
#              P_import_sell_by_market, P_export_buy_by_market,
#              P_export_sell_by_market, probability_by_market,
#              discount_by_market)
# -------------------------------------------------------------
# Where this function/script is used
#   - reward_function()
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - The result is exactly 0 for a leg that placed no window at all:
#     with no phase-3 row there is nothing to value, and the function
#     returns before doing any work.
#   - An interval whose activation probability is 0 contributes 0, which
#     is correct: a service that will not be called costs nothing to
#     execute.
#   - Only the intervals that actually hold a Recovery Phase row are
#     valued; the target intervals of the market that hold none do not
#     enter the sum at all.
#   - A Recovery Phase row whose interval is not a target interval
#     stops execution: it has no price to be valued with.
# -------------------------------------------------------------
# functions/scripts called
#   calc_differential_cost() - net cash flow of moving an energy position
#   apply_revenue_discount() - discounts the income of each interval
# -------------------------------------------------------------
compute_recovery_energy_cost <- function(E_plan,
                                         E_flex,
                                         phase,
                                         MarketUTC_candidate,
                                         market_utc,
                                         P_import_buy_by_market,
                                         P_import_sell_by_market,
                                         P_export_buy_by_market,
                                         P_export_sell_by_market,
                                         probability_by_market,
                                         discount_by_market
                                         ) {

  # -------------------------------------------------------------
  # 1. Market intervals holding a Recovery Phase row
  # -------------------------------------------------------------
  {
    recovery_rows <- (phase == 3)

    if (!any(recovery_rows)) {
      return(0)
    }

    mkt_recov <- sort(unique(MarketUTC_candidate[recovery_rows]))
  }

  # -------------------------------------------------------------
  # 2. Prices and probability of each of those intervals
  # -------------------------------------------------------------
  # The market's own prices and the market's own view of the activation
  # probability are used, which is what the rest of the reward is
  # valued with.
  # -------------------------------------------------------------
  {
    pos_in_target <- match(mkt_recov, market_utc)

    if (any(is.na(pos_in_target))) {
      stop("compute_recovery_energy_cost: a Recovery Phase row falls ",
           "outside the market intervals being valued")
    }

    P_import_buy_recov  <- P_import_buy_by_market[pos_in_target]
    P_import_sell_recov <- P_import_sell_by_market[pos_in_target]
    P_export_buy_recov  <- P_export_buy_by_market[pos_in_target]
    P_export_sell_recov <- P_export_sell_by_market[pos_in_target]
    probability_recov   <- probability_by_market[pos_in_target]
    discount_recov      <- discount_by_market[pos_in_target]

    rm(pos_in_target)
  }

  # -------------------------------------------------------------
  # 3. Aggregate the two itineraries over the Recovery Phase rows
  # -------------------------------------------------------------
  # Explicitly aligned to mkt_recov rather than assuming the order of the
  # rows, the same way compute_marginal_flex_revenue() does.
  # -------------------------------------------------------------
  {
    E_recov_plan_by_market <- vapply(
      mkt_recov,
      function(mkt) sum(E_plan[recovery_rows & MarketUTC_candidate == mkt]),
      numeric(1)
    )
    E_recov_flex_by_market <- vapply(
      mkt_recov,
      function(mkt) sum(E_flex[recovery_rows & MarketUTC_candidate == mkt]),
      numeric(1)
    )
  }

  # -------------------------------------------------------------
  # 4. Value the deviation of each interval and weight it by probability
  # -------------------------------------------------------------
  # calc_differential_cost() is called with the plan as the origin and
  # the flexibility itinerary as the destination, so the result already
  # carries the repository's sign. The probability turns the certain
  # cost of an executed event into the expected cost of one that may or
  # may not be called.
  # -------------------------------------------------------------
  {
    dC_by_market <- calc_differential_cost(
      E_orig        = E_recov_plan_by_market,
      E_new         = E_recov_flex_by_market,
      P_import_buy  = P_import_buy_recov,
      P_import_sell = P_import_sell_recov,
      P_export_buy  = P_export_buy_recov,
      P_export_sell = P_export_sell_recov
    )

    # apply_revenue_discount() is called after the probability weighting
    # and not before it, because what the discount weighs is the money
    # the decision expects to see: the expected cash flow of an interval
    # is probability times deviation, and it is that expectation, once
    # it is an income, that is worth less the further away it happens.
    # Applying the two weights in the other order would give the same
    # number here, since both are scalars per interval, but it would
    # read as if the discount corrected the probability rather than the
    # money.
    total_cost <- sum(apply_revenue_discount(
      probability_recov * dC_by_market,
      discount_recov
    ))
  }

  rm(recovery_rows, mkt_recov, E_recov_plan_by_market, E_recov_flex_by_market,
     P_import_buy_recov, P_import_sell_recov, P_export_buy_recov,
     P_export_sell_recov, probability_recov, discount_recov, dC_by_market)

  return(total_cost)
}
