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
# planned to. That deviation was not valued anywhere: the effective
# flexibility price bundles the commitment payment with the expected
# execution payment into a single number and says nothing about energy.
# Only the Recovery Phase is valued, and not by convention: the
# Commitment Phase's own energy is assumed to be already remunerated by
# the execution price, and during the Neutral Phase the deviation is
# exactly zero by construction. The Neutral Phase is simulated in
# calculation_mode 2, which reads the power of every step from the Q_*
# columns, and those columns still hold the copy of the _plan itinerary
# that initialize_plan_flex_columns() made, since the flexibility
# evaluation only overwrites the rows of the Commitment Phase. As the
# simulation loop derives electricity from Q and the outdoor
# temperature alone, the flexibility itinerary and the plan spend
# exactly the same in every Neutral Phase row.
# -------------------------------------------------------------
# Every row of the window is valued, inside the market horizon or not
# The energy the building moves while recovering is bought or sold
# whenever it happens. A flexibility window is longer than the stretch
# of time a single market trades, so part of it falls beyond that
# market's target intervals; valuing only the part inside would leave a
# real cost of executing the service unseen, and would make the reward
# depend on where the window happens to fall relative to the market
# grid. Every Recovery Phase row is therefore valued, with the market's
# prices where the market has a view and with the row's own prices
# where it does not.
# That second case reads the true future prices rather than a forecast,
# which is a known limitation of the model - see the Known Issues
# section of README.md.
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
#   P_import_buy_row, P_import_sell_row,
#   P_export_buy_row, P_export_sell_row :
#                         Numeric vectors, same length as E_plan. Energy
#                         prices of every timestep, read from the
#                         period_chunk itself. They are what the
#                         Recovery Phase rows that fall outside the
#                         market's target intervals are valued with.
#   probability_row     : Numeric vector in [0, 1], same length as
#                         E_plan. Activation probability of this leg at
#                         every timestep, for the same rows.
#   discount_by_market  : Numeric vector, same length/order as
#                         market_utc. Revenue discount factor of each
#                         target interval, as returned by
#                         revenue_discount_factor().
#   discount_row        : Numeric vector, same length as E_plan. The
#                         same factor at every timestep, used for the
#                         Recovery Phase rows that fall outside the
#                         market's target intervals. Both are needed for
#                         the same reason the prices are: this term
#                         reaches beyond the market's horizon, and every
#                         interval it values has to be discounted by its
#                         own distance from the decision instant.
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
#              P_import_buy_row, P_import_sell_row, P_export_buy_row,
#              P_export_sell_row, probability_row)
# -------------------------------------------------------------
# Where this function/script is used
# Called by reward_function(), once per leg, as part of the expected
# execution term of the reward. integrate_market_process() values the
# same thing, so that what is settled matches what the reward valued,
# but it does so as a differential between the state before and after
# its own decision, with calc_differential_cost() directly: a settlement
# has to book only the change it makes, or the same Recovery Phase
# is re-booked once per market that covers the interval. The reward has
# no such need, because within one market the baseline is the same for
# every candidate, so an absolute value and a differential one rank the
# candidates identically.
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
                                              P_import_buy_row,
                                              P_import_sell_row,
                                              P_export_buy_row,
                                              P_export_sell_row,
                                              probability_row,
                                              discount_by_market,
                                              discount_row) {

  # 1. Market intervals to value
  # -------------------------------------------------------------
  # Every interval that holds a Recovery Phase row, not only the target
  # intervals of the current market. The energy the building would move
  # is bought or sold whenever it happens, so it is valued whenever it
  # happens; stopping at the market horizon would leave part of the cost
  # of executing the service unseen.
  # -------------------------------------------------------------
  {
    recovery_rows <- (phase == 3)

    if (!any(recovery_rows)) {
      return(0)
    }

    mkt_recov <- sort(unique(MarketUTC_candidate[recovery_rows]))
  }

  # 2. Prices and probability of each of those intervals
  # -------------------------------------------------------------
  # Inside the market's target set, the market's own prices and the
  # market's own view of the activation probability are used, which is
  # what the rest of the reward is valued with. Outside it there is no
  # market view, so the row's own signals are read instead, taking the
  # first row of the interval, the same convention the rest of the code
  # follows.
  # Those out-of-horizon signals are the true future values, not a
  # forecast, which is a known limitation of the model rather than of
  # this function: see the Known Issues section of README.md.
  # -------------------------------------------------------------
  {
    pos_in_target <- match(mkt_recov, market_utc)
    first_row_of  <- match(mkt_recov, MarketUTC_candidate)

    pick <- function(by_market, row_vector) {
      out <- row_vector[first_row_of]
      inside <- !is.na(pos_in_target)
      out[inside] <- by_market[pos_in_target[inside]]
      out
    }

    P_import_buy_recov  <- pick(P_import_buy_by_market,  P_import_buy_row)
    P_import_sell_recov <- pick(P_import_sell_by_market, P_import_sell_row)
    P_export_buy_recov  <- pick(P_export_buy_by_market,  P_export_buy_row)
    P_export_sell_recov <- pick(P_export_sell_by_market, P_export_sell_row)
    probability_recov   <- pick(probability_by_market,   probability_row)
    discount_recov      <- pick(discount_by_market,      discount_row)

    rm(pos_in_target, first_row_of, pick)
  }

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
