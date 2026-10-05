# -------------------------------------------------------------
# Function: reward_function.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function calculates a reward function on the adequacy of
# a particular building HVAC operation over a planning period.
# It reads a period_chunk data frame and operates in two modes
# depending on parameters$control$optimization_aim:
#   "energy"      - minimise energy cost while maintaining comfort
#   "flexibility" - additionally account for flexibility revenue
# Comfort is always evaluated over the full simulated energy flow of
# each itinerary:
#   - Elec_total_plan
#   - Elec_total_plan_flex_down
#   - Elec_total_plan_flex_up
# since the building's thermal evolution depends on the full energy
# applied. The economic
# terms are always valued at their marginal (differential) cash flow
# relative to whatever was already committed for the same market
# intervals by an earlier market process, at the current market's
# prices - see compute_marginal_energy_cost() and
# resolve_marginal_context(). marginal_context is mandatory: there is
# no no-context fallback. A previous fallback that valued the full
# candidate commitment directly (ignoring the differential baseline)
# was removed because it could silently mask a missing or broken
# marginal-cost chain upstream (e.g. a caller that forgot to call
# resolve_marginal_context()) instead of surfacing it as an error.
# In addition to the energy price, the base-energy term also accounts
# for the marginal distribution cost (Elec_unit_cost_distribution),
# via compute_marginal_distribution_cost().
# This is a decision-time-only consideration (it is never written to
# market_commitments, only to Reward): buying or selling energy always
# adds distribution cost, unbuying ("descompra") or unselling
# ("desventa") always reduces it, regardless of direction - it does
# not apply to the explicit-flexibility term.
# -------------------------------------------------------------
# The reward is dimensionless
# The two weights are what make it so, and they are kept apart on
# purpose. alpha_comfort is in 1/h and multiplies the comfort term,
# which is measured in hours out of comfort; alpha_cost is in 1/EUR and
# multiplies every economic term, which are in EUR. The reward is
# therefore a pure number, and what governs the optimizer's behaviour is
# the ratio between the two weights, not either of them on its own.
# Splitting the old single weight in two also leaves room for more
# complex price structures later: a new economic term only needs to be
# added inside the alpha_cost bracket to be weighted consistently with
# the rest.
# -------------------------------------------------------------
# Revenue discount
# Income that is far away in time weighs less in the decision than the
# same income in the next slot. Every economic term is therefore valued
# per market interval and, where that interval's cash flow turns out to
# be an income, multiplied by (1 - Revenue_discount_per_hour/100)^n,
# with n the hours from the decision instant to that interval - see
# revenue_discount_factor() and apply_revenue_discount(). Expense is
# never discounted, and neither is the comfort term: prudence is about
# what the building expects to earn, not about what it will spend or
# about whether people are comfortable.
# The discount belongs to the decision and stops there. What the winning
# candidate is then paid is settled by integrate_market_process() at the
# market's own prices, so neither the volume nor the price of any
# commitment carries it.
# -------------------------------------------------------------
# Sign convention
# Every economic term (Elec_Cost_plan, Elec_Cost_distribution_plan,
# Elec_flex_com_revenue_plan, Elec_flex_exec_revenue_plan) already
# carries the sign of its cash flow:
# positive = income, negative = expense (see calc_differential_cost(),
# compute_marginal_distribution_cost() and value_flex_operation()).
# Reward is therefore a pure sum of the comfort term and every economic
# term, never a mix of "+" and "-" that has to be remembered per term.
# The explicit-flexibility term is valued via compute_marginal_flex_revenue(),
# not compute_marginal_energy_cost(): explicit flexibility is a service
# sold to the grid in two independent down/up legs, not a single
# position that flips sign like energy import/export - see
# value_flex_operation()'s header for the full explanation of why the
# two cannot share the same valuation machinery.
# -------------------------------------------------------------
# Inputs
#   period_chunk             : Data frame. Planning-period data with *_plan (and,
#                              for "flexibility" mode, *_plan_flex_down and
#                              *_plan_flex_up) columns produced
#                              by period_calculation() and flex_evaluation_down().
#                              Required columns:
#                                time             - POSIXct. Simulation timestamps.
#                                MarketUTC        - POSIXct. Market interval of each row.
#                                Comfort_plan     - Numeric (0/1). Comfort flag (plan).
#                                Elec_total_plan  - Numeric. Total electricity (plan).
#                              Additional columns required for "flexibility" mode:
#                                Comfort_plan_flex_down    - Numeric (0/1). Comfort flag (plan_flex_down).
#                                Elec_total_plan_flex_down - Numeric. Total electricity (plan_flex_down).
#                                Comfort_plan_flex_up      - Numeric (0/1). Comfort flag (plan_flex_up).
#                                Elec_total_plan_flex_up   - Numeric. Total electricity (plan_flex_up).
#   parameters               : Named list. Must contain:
#                                parameters$reward$alpha_comfort : Numeric (1/h). Weight applied
#                                                                  to the comfort penalty term.
#                                                                  Mandatory: stop() is raised if
#                                                                  absent.
#                                parameters$reward$alpha_cost    : Numeric (1/EUR). Weight applied
#                                                                  to every economic term.
#                                                                  Mandatory: stop() is raised if
#                                                                  absent.
#                                parameters$control$optimization_aim : Character. "energy", "operation",
#                                                                       "flexibility", or
#                                                                       "operationflex".
#   simulation_control       : Named list. Simulation control object. Must contain:
#                                simulation_control$indexes_local$i_flex : Integer scalar. Row number in
#                                  period_chunk at which the flexibility event starts.
#                                  Defaults to 1 when NULL or absent.
#                                simulation_control$flexibility$commitment_phase_length : Numeric
#                                  scalar. Duration of the Commitment Phase (h). Only used to decide
#                                  whether a "flexibility" aim still behaves as "energy" (see
#                                  EXCEPTIONS below); not used for any economic calculation.
#   marginal_context          : Named list. Mandatory (no default). As returned by
#                                resolve_marginal_context(), with:
#                                  - market_utc
#                                  - E_orig_base_by_market
#                                  - E_orig_expflex_down_by_market
#                                  - E_orig_expflex_up_by_market
#                                  - P_import_buy_by_market
#                                  - P_import_sell_by_market
#                                  - P_export_buy_by_market
#                                  - P_export_sell_by_market
#                                  - distribution_rate_by_market
#                                  - p_up_buy_by_market
#                                  - p_up_sell_by_market
#                                  - p_down_buy_by_market
#                                  - p_down_sell_by_market
#                                    (the four flex prices are per leg, "up"/"down",
#                                    not "import"/"export" - see value_flex_operation())
#                                  - revenue_discount_by_market
#                                  - revenue_discount_per_hour
#                                  - discount_origin_time
#                                stop()s if NULL, and also if it carries no revenue
#                                discount.
# -------------------------------------------------------------
# Outputs
#   period_chunk : Data frame. The input data frame with a 'Reward' column
#                  added (or overwritten) containing the per-row reward value
#                  for each timestep, plus the following intermediate result
#                  columns (all modes):
#                    Elec_Cost_plan              - Numeric. Electricity cost. The whole
#                                                  interval-aggregated marginal cost is
#                                                  concentrated on the last row (this column
#                                                  is not meaningful per-timestep; only its
#                                                  sum matters).
#                    Elec_Cost_distribution_plan - Numeric. Marginal distribution cost
#                                                  (base-energy term only), same last-row
#                                                  concentration as Elec_Cost_plan.
#                  Additional columns added in "flexibility" mode:
#                    Elec_flex_down_plan        - Numeric. Energy difference
#                                                  (plan - plan_flex_down), bounded to
#                                                  the Commitment Phase: it is 0 wherever
#                                                  Flex_phase_down_plan is not 1.
#                    Elec_flex_up_plan          - Numeric. Energy difference
#                                                  (plan_flex_up - plan), bounded the
#                                                  same way to Flex_phase_up_plan == 1
#                                                  and to 0 from below. Both signals
#                                                  are non-negative by construction.
#                    Elec_flex_com_revenue_plan  - Numeric. Certain revenue of the
#                                                  flexibility commitment, at the
#                                                  commitment price alone (same
#                                                  last-row concentration as
#                                                  Elec_Cost_plan).
#                    Elec_flex_exec_revenue_plan - Numeric. Expected revenue of the
#                                                  execution: the execution price
#                                                  weighted by the activation
#                                                  probability, plus the energy the
#                                                  Recovery Phase would move if
#                                                  the service were called. Same
#                                                  last-row concentration.
#                  The caller is responsible for summing the Reward column
#                  when a scalar reward is required.
# -------------------------------------------------------------
# Code outline
# 1. Extract the alpha_comfort and alpha_cost parameters
# 2. Extract i_flex and commitment_phase_length from simulation_control
# 3. Calculate delta_t per timestep
# 3b. Resolve the revenue discount factors, per market interval and per row
# 4. Compute electricity cost (marginal) and distribution cost (marginal)
# 4c. Technical feasibility of the flexibility itineraries
# 5. Mode-specific reward (energy or flexibility)
# 6. Store per-row reward in data frame
# -------------------------------------------------------------
# Usage instructions
# result_df <- reward_function(period_chunk, parameters, simulation_control, marginal_context)
# -------------------------------------------------------------
# Where this function/script is used
# Called by evaluate_control.R, and by run_market_process(), which
# values the accepted plan with it once the optimizer has chosen.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If marginal_context is NULL, stop() is called immediately (see header).
#   - If parameters$reward$alpha_comfort or parameters$reward$alpha_cost
#     is NULL, stop() is called immediately (no default value is used).
#   - If marginal_context carries no revenue discount, stop() is called
#     immediately. Treating its absence as "no discount" would silently
#     turn a broken context into a valid-looking optimization run at a
#     different, undeclared prudence.
#   - delta_t for the first row is set to 0 (no prior timestep). It is
#     expressed in hours, so that alpha_comfort (1/h) times it yields a
#     dimensionless number, the same as alpha_cost (1/EUR) times each
#     economic term (EUR).
#   - If optimization_aim is none of "energy", "operation",
#     "flexibility" or "operationflex", stop() is called.
#   - In every mode, the comfort penalty applies to every time step
#     where ANY of Comfort_plan, Comfort_plan_flex_down or
#     Comfort_plan_flex_up is 0 (out of its own band), occupied or not.
#   - When simulation_control$indexes_local$i_flex is NULL, it defaults to 1 (first row).
#   - When simulation_control$flexibility$commitment_phase_length is NULL,
#     it falls back to parameters$control$commitment_phase_length_max.
#   - The flexibility revenue term does not distinguish a "commitment
#     window" vs "execution/Recovery Phase": Elec_flex_down_plan is
#     aggregated per market interval over the whole period_chunk and
#     valued at that interval's own effective up/down flexibility
#     price, which already values any post-event rebound at its own
#     interval's price instead of forcing every revenue component onto
#     the flex event's own price.
# -------------------------------------------------------------
# functions/scripts called
#   compute_marginal_energy_cost() - marginal cash flow, base-energy term
#   compute_marginal_distribution_cost() - marginal distribution cost
#     (base-energy term only)
#   compute_marginal_flex_revenue() - marginal cash flow, explicit
#     flexibility term (flexibility/operationflex modes only)
#   flex_window_is_feasible() - says whether a window raises the
#     electricity of both thermal systems over the plan
#   compute_recovery_energy_cost() - expected energy cost of the
#     Recovery Phase (flexibility/operationflex modes only)
#   revenue_discount_factor() - per-row revenue discount factors, for
#     the Recovery Phase rows beyond the market's horizon
# -------------------------------------------------------------
reward_function <- function(period_chunk, parameters,
                            simulation_control = NULL,
                            marginal_context = NULL) {

  # 0. marginal_context is mandatory: no no-context fallback (see header)
  if (is.null(marginal_context)) {
    stop("reward_function: marginal_context is required. The no-context ",
         "fallback (valuing the full candidate commitment without a ",
         "marginal baseline) was removed because it could silently mask ",
         "a missing or broken marginal-cost chain upstream - make sure ",
         "resolve_marginal_context() is called and its result is passed ",
         "through.")
  }

  # 1. Get the two reward weights from reward_parameters
  if (!is.null(parameters$reward$alpha_comfort)) {
    alpha_comfort <- parameters$reward$alpha_comfort
  } else {
    stop("alpha_comfort was not found")
  }
  if (!is.null(parameters$reward$alpha_cost)) {
    alpha_cost <- parameters$reward$alpha_cost
  } else {
    stop("alpha_cost was not found")
  }

  # 2. Extract i_flex and commitment_phase_length from simulation_control
  if (!is.null(simulation_control) &&
      !is.null(simulation_control$indexes_local$i_flex)) {
    i_flex <- simulation_control$indexes_local$i_flex
  } else {
    i_flex <- 1L
  }

  if (!is.null(simulation_control) &&
      !is.null(simulation_control$flexibility$commitment_phase_length)) {
    commitment_phase_length <- simulation_control$flexibility$commitment_phase_length
  } else {
    commitment_phase_length <- NULL
  }

  # 3. Calculate delta_t (hours) for each row; first row gets 0.
  # Hours is the project-wide reference unit for time, the same one
  # period_simulation_cpp.cpp uses. It is what makes the comfort term
  # dimensionally consistent with the economic ones: alpha_comfort is
  # 1/h, so alpha_comfort * delta_t (h) is a pure number, directly
  # addable to alpha_cost (1/EUR) times Elec_Cost_plan and the rest,
  # which are in EUR.
  # period_chunk$time must be POSIXct. as.numeric() is applied before
  # diff(), not after: diff() on a POSIXct vector returns a difftime
  # with an automatically chosen unit (seconds, minutes, hours or days,
  # picked from the series' own spacing), so as.numeric(diff(...))
  # would silently pick up whatever unit R chose instead of always
  # being seconds. Converting to numeric first fixes the unit to
  # seconds before diff() ever runs, so the /3600 below always yields
  # hours regardless of Main_df's resolution.
  delta_t_h <- c(0, diff(as.numeric(period_chunk$time)) / 3600)

  # 3b. Revenue discount factors
  # -------------------------------------------------------------
  # The factors of the market's own target intervals are resolved once
  # per optimization by resolve_marginal_context() and travel in the
  # context, so they are read rather than recomputed here: this function
  # runs once per GA candidate and they are the same for all of them.
  # The per-row factors are the ones the Recovery Phase term needs for
  # the rows that fall beyond the market's horizon, where it also reads
  # the prices off the period_chunk. They are built from the same origin
  # and the same rate, so a row inside the horizon gets exactly the
  # factor its interval already carries.
  # -------------------------------------------------------------
  if (is.null(marginal_context$revenue_discount_by_market) ||
      is.null(marginal_context$discount_origin_time) ||
      is.null(marginal_context$revenue_discount_per_hour)) {
    stop("reward_function: marginal_context carries no revenue discount. ",
         "revenue_discount_by_market, revenue_discount_per_hour and ",
         "discount_origin_time are resolved by resolve_marginal_context() ",
         "and have no default here - a missing one means the context was ",
         "built by something else, not that the discount should be ",
         "skipped.")
  }
  discount_by_market <- marginal_context$revenue_discount_by_market

  # revenue_discount_factor() is called to extend the same discount to
  # every row of the period_chunk, on the row's own market interval.
  discount_row <- revenue_discount_factor(
    target_time       = period_chunk$MarketUTC,
    origin_time       = marginal_context$discount_origin_time,
    discount_per_hour = marginal_context$revenue_discount_per_hour
  )

  # 4. Compute electricity cost (marginal)
  # -------------------------------------------------------------
  # The whole horizon's base-energy commitment is aggregated per market
  # interval and valued at its marginal (differential) cost relative to
  # marginal_context's baseline, at the current market's prices. The
  # resulting scalar is concentrated on the last row so that
  # sum(period_chunk$Reward) still yields the correct total.
  # -------------------------------------------------------------
  Elec_Cost_total <- compute_marginal_energy_cost(
    E_candidate             = period_chunk$Elec_total_plan,
    MarketUTC_candidate     = period_chunk$MarketUTC,
    market_utc              = marginal_context$market_utc,
    E_orig_by_market        = marginal_context$E_orig_base_by_market,
    P_import_buy_by_market  = marginal_context$P_import_buy_by_market,
    P_import_sell_by_market = marginal_context$P_import_sell_by_market,
    P_export_buy_by_market  = marginal_context$P_export_buy_by_market,
    P_export_sell_by_market = marginal_context$P_export_sell_by_market,
    discount_by_market      = discount_by_market
  )
  period_chunk$Elec_Cost_plan <- 0
  period_chunk$Elec_Cost_plan[nrow(period_chunk)] <- Elec_Cost_total
  rm(Elec_Cost_total)

  # Marginal distribution cost (base-energy term only, never for
  # flexibility).
  Elec_Cost_distribution_total <- compute_marginal_distribution_cost(
    E_candidate                 = period_chunk$Elec_total_plan,
    MarketUTC_candidate         = period_chunk$MarketUTC,
    market_utc                  = marginal_context$market_utc,
    E_orig_by_market            = marginal_context$E_orig_base_by_market,
    distribution_rate_by_market = marginal_context$distribution_rate_by_market,
    discount_by_market          = discount_by_market
  )
  period_chunk$Elec_Cost_distribution_plan <- 0
  period_chunk$Elec_Cost_distribution_plan[nrow(period_chunk)] <- Elec_Cost_distribution_total
  rm(Elec_Cost_distribution_total)

  # 4c. Technical feasibility of the flexibility itineraries
  # -------------------------------------------------------------
  # A window that raises the electricity of BOTH thermal systems over
  # the plan is not a service the building can render, and the optimizer
  # has to see that as a cost rather than simply fail to sell anything.
  # flex_evaluation_down()/flex_evaluation_up() already refuse such a
  # window before it is placed, so in a healthy run this term is zero;
  # it is the net for a candidate that carries one anyway, and it is
  # what makes the region visible to the search instead of merely
  # unprofitable.
  # The whole penalty is written on a single row, as the lump-sum terms
  # above are, so that summing over the horizon does not multiply it by
  # the number of rows.
  # -------------------------------------------------------------
  {
    # Weight of the technical-feasibility term, read from
    # 01_computing_parameters.csv rather than from
    # 09_Reward_parameters.csv: a physical restriction is not a
    # preference the user may weigh. Its magnitude only has to dominate
    # any reachable reward (of the order of 1e3). It is finite on
    # purpose: with ga(), an -Inf can reach the fitness scaling and
    # produce NaN in the selection.
    FLEX_INFEASIBLE_PENALTY <- parameters$computing$flex_infeasible_penalty
    if (is.null(FLEX_INFEASIBLE_PENALTY)) {
      stop("flex_infeasible_penalty was not found in parameters$computing")
    }

    infeasible_legs <- sum(vapply(c("down", "up"), function(one_leg) {
      as.integer(!flex_window_is_feasible(period_chunk, one_leg, parameters))
    }, integer(1)))

    # And the other way a candidate can be infeasible: over its plan, a
    # window of the guard zone that was already sold would raise both
    # thermal systems, so it can only be held as it stands.
    # derive_flex_itineraries() reports it, because it is what tried to
    # draw the window. A chunk that never went through it carries no
    # such column and nothing is added.
    if (!is.null(period_chunk$Standing_commitment_held_plan) &&
        any(period_chunk$Standing_commitment_held_plan == 0L)) {
      infeasible_legs <- infeasible_legs + 1L
    }

    period_chunk$Technical_feasibility_penalty_plan <- 0
    period_chunk$Technical_feasibility_penalty_plan[nrow(period_chunk)] <-
      -FLEX_INFEASIBLE_PENALTY * infeasible_legs

    rm(FLEX_INFEASIBLE_PENALTY, infeasible_legs)
  }

  # 5. Mode-specific reward calculation
  optimization_aim <- parameters$control$optimization_aim

  # "operation" is evaluated by the energy branch. A market with that
  # aim trades nothing and decides nothing, but what it reports is the
  # cost and the comfort of the operation it was handed, which is
  # exactly what this branch measures. It used to reach the stop() at
  # the end because it never called this function at all.
  if (optimization_aim == "energy" || optimization_aim == "operation" ||
      ((optimization_aim == "flexibility" || optimization_aim == "operationflex") &&
       (is.null(i_flex) ||
        i_flex == 0 ||
        is.null(commitment_phase_length)
        ||
        commitment_phase_length == 0
        )
       )
      ) {
    # Comfort is measured over the THREE itineraries, in energy mode as
    # much as in flexibility mode. A market that only trades energy does
    # not sell flexibility, but it can still leave the building outside
    # comfort in an itinerary that was already committed and that it is
    # obliged to hold - and it used to do so without noticing, because
    # this branch looked at Comfort_plan alone.
    # Where nothing is committed, derive_flex_itineraries() leaves both
    # flexibility itineraries as copies of the plan, so the "or" adds no
    # penalty and the result is what it always was.
    # Every time step counts, occupied or not: each itinerary carries
    # its own band (the plan band, or the occupancy band inside a
    # flexibility window), and outside occupancy and the scheduling
    # window that band is the setback band.
    Performance_plan <- ifelse(period_chunk$Comfort_plan == 0 |
                               period_chunk$Comfort_plan_flex_down == 0 |
                               period_chunk$Comfort_plan_flex_up == 0,
                             -1, 0) * delta_t_h

    # Every term already carries its own sign (comfort: neutral/positive
    # in comfort, negative out of it; economic terms: positive income,
    # negative expense), so Reward is a plain sum.
    Reward <- alpha_comfort * Performance_plan +
              alpha_cost * (period_chunk$Elec_Cost_plan +
                            period_chunk$Elec_Cost_distribution_plan) +
              period_chunk$Technical_feasibility_penalty_plan

  } else if (optimization_aim == "flexibility"  ||
             optimization_aim =="operationflex") {

    # The commitment exists only during the Commitment Phase (phase 1).
    # The recovery and Recovery Phases are a consequence of the
    # event, not a service sold to the grid, so they must not be
    # valued - not even with the opposite sign, which is what used to
    # happen: the rebound made this difference negative and
    # value_flex_operation() then booked it on the up leg, selling it
    # as upward flexibility that was never offered.
    period_chunk$Elec_flex_down_plan <-
      (period_chunk$Elec_total_plan - period_chunk$Elec_total_plan_flex_down) *
      (period_chunk$Flex_phase_down_plan == 1)

    # The upward commitment is the mirror image: the load the building
    # adds over its plan during its own Commitment Phase. Defined this way
    # round, both signals are non-negative and a real commitment is a
    # positive value on either of them.
    # The lower bound at 0 is what guarantees the non-negativity, and it
    # is not redundant. flex_evaluation_up() already refuses a window
    # whose event does not raise the building's electricity overall, but
    # within an accepted window a single row can still come out below
    # the plan, because the event switches the non-selected system off
    # and that system may have been running on the backup resistances,
    # at COP 1. A row like that delivers no upward service, so it
    # commits nothing; letting it through as a negative value would make
    # value_flex_operation() read it as a downward sale, at downward
    # prices, on the leg that is not being traded.
    period_chunk$Elec_flex_up_plan <-
      pmax(period_chunk$Elec_total_plan_flex_up - period_chunk$Elec_total_plan, 0) *
      (period_chunk$Flex_phase_up_plan == 1)

    # In flexibility mode the penalty applies if ANY of the three
    # itineraries is out of comfort. Committing to a service that leaves
    # the building outside comfort in the itinerary that would actually
    # be flown is not an acceptable commitment, whichever of the two
    # legs it belongs to. Outside the flexibility windows both flex
    # columns are the copy of Comfort_plan that
    # derive_flex_itineraries() made, so the "or" adds no false penalty
    # there.
    # Every time step counts, occupied or not: each itinerary carries
    # its own band (the plan band, or the occupancy band inside a
    # flexibility window), and outside occupancy and the scheduling
    # window that band is the setback band.
    Performance_flex <- ifelse(period_chunk$Comfort_plan == 0 |
                               period_chunk$Comfort_plan_flex_down == 0 |
                               period_chunk$Comfort_plan_flex_up == 0,
                             -1, 0) * delta_t_h

    # Marginal explicit-flexibility revenue: each leg's signal aggregated
    # per market interval, valued at that interval's own down/up
    # flexibility prices (value_flex_operation(), via
    # compute_marginal_flex_revenue() - not compute_marginal_energy_cost():
    # see that function's header for why explicit flexibility cannot be
    # valued as an import/export position), relative to the pre-existing
    # baseline of that same leg.
    # One call per leg, with the upward series negated, exactly as
    # integrate_market_process() does when it settles the same decision:
    # value_flex_operation() tells the legs apart by sign, and both
    # signals are non-negative, so a single netted call would cancel a
    # downward commitment against an upward one in the same interval.
    #
    # The revenue is split into two terms that used to be a single one,
    # because they are not equally certain and they do not carry the
    # same costs:
    #   - The COMMITMENT term is certain. Selling the service is paid
    #     for whether or not the operator ever calls it, so it is valued
    #     at the commitment price alone.
    #   - The EXECUTION term is conditional. It is valued at the
    #     execution price weighted by the activation probability, and it
    #     also carries the energy the building has to move during the
    #     Recovery Phase if it is actually called - see
    #     compute_recovery_energy_cost(), which is where that cost
    #     enters the reward for the first time. That energy is valued
    #     over the whole Recovery Phase, including the part of it
    #     that falls beyond the intervals this market trades: the
    #     building buys or sells it whenever it happens. The rows
    #     outside the market's horizon are valued at the prices and
    #     probability carried by the period_chunk itself, which are the
    #     true future values rather than a forecast - a known limitation
    #     of the model, recorded in the Known Issues section of
    #     README.md.
    # Weighting the execution price by the probability before handing it
    # to compute_marginal_flex_revenue() is what makes the two terms add
    # up to what the single effective price used to yield: the effective
    # price is exactly commitment + execution * probability, so the
    # split by itself changes nothing and the only new magnitude is the
    # Recovery Phase cost.
    Elec_flex_com_revenue_total <- compute_marginal_flex_revenue(
      E_candidate                = period_chunk$Elec_flex_down_plan,
      MarketUTC_candidate        = period_chunk$MarketUTC,
      market_utc                 = marginal_context$market_utc,
      E_orig_by_market           = marginal_context$E_orig_expflex_down_by_market,
      price_down_sell_by_market  = marginal_context$p_down_com_sell_by_market,
      price_down_buy_by_market   = marginal_context$p_down_com_buy_by_market,
      price_up_sell_by_market    = marginal_context$p_up_com_sell_by_market,
      price_up_buy_by_market     = marginal_context$p_up_com_buy_by_market,
      discount_by_market         = discount_by_market
    ) +
    compute_marginal_flex_revenue(
      E_candidate                = -period_chunk$Elec_flex_up_plan,
      MarketUTC_candidate        = period_chunk$MarketUTC,
      market_utc                 = marginal_context$market_utc,
      E_orig_by_market           = -marginal_context$E_orig_expflex_up_by_market,
      price_down_sell_by_market  = marginal_context$p_down_com_sell_by_market,
      price_down_buy_by_market   = marginal_context$p_down_com_buy_by_market,
      price_up_sell_by_market    = marginal_context$p_up_com_sell_by_market,
      price_up_buy_by_market     = marginal_context$p_up_com_buy_by_market,
      discount_by_market         = discount_by_market
    )
    period_chunk$Elec_flex_com_revenue_plan <- 0
    period_chunk$Elec_flex_com_revenue_plan[nrow(period_chunk)] <- Elec_flex_com_revenue_total
    rm(Elec_flex_com_revenue_total)

    Elec_flex_exec_revenue_total <- compute_marginal_flex_revenue(
      E_candidate                = period_chunk$Elec_flex_down_plan,
      MarketUTC_candidate        = period_chunk$MarketUTC,
      market_utc                 = marginal_context$market_utc,
      E_orig_by_market           = marginal_context$E_orig_expflex_down_by_market,
      price_down_sell_by_market  = marginal_context$p_down_exec_sell_by_market *
                                     marginal_context$flex_probab_down_by_market,
      price_down_buy_by_market   = marginal_context$p_down_exec_buy_by_market *
                                     marginal_context$flex_probab_down_by_market,
      price_up_sell_by_market    = marginal_context$p_up_exec_sell_by_market *
                                     marginal_context$flex_probab_up_by_market,
      price_up_buy_by_market     = marginal_context$p_up_exec_buy_by_market *
                                     marginal_context$flex_probab_up_by_market,
      discount_by_market         = discount_by_market
    ) +
    compute_marginal_flex_revenue(
      E_candidate                = -period_chunk$Elec_flex_up_plan,
      MarketUTC_candidate        = period_chunk$MarketUTC,
      market_utc                 = marginal_context$market_utc,
      E_orig_by_market           = -marginal_context$E_orig_expflex_up_by_market,
      price_down_sell_by_market  = marginal_context$p_down_exec_sell_by_market *
                                     marginal_context$flex_probab_down_by_market,
      price_down_buy_by_market   = marginal_context$p_down_exec_buy_by_market *
                                     marginal_context$flex_probab_down_by_market,
      price_up_sell_by_market    = marginal_context$p_up_exec_sell_by_market *
                                     marginal_context$flex_probab_up_by_market,
      price_up_buy_by_market     = marginal_context$p_up_exec_buy_by_market *
                                     marginal_context$flex_probab_up_by_market,
      discount_by_market         = discount_by_market
    ) +
    compute_recovery_energy_cost(
      E_plan                  = period_chunk$Elec_total_plan,
      E_flex                  = period_chunk$Elec_total_plan_flex_down,
      phase                   = period_chunk$Flex_phase_down_plan,
      MarketUTC_candidate     = period_chunk$MarketUTC,
      market_utc              = marginal_context$market_utc,
      P_import_buy_by_market  = marginal_context$P_import_buy_by_market,
      P_import_sell_by_market = marginal_context$P_import_sell_by_market,
      P_export_buy_by_market  = marginal_context$P_export_buy_by_market,
      P_export_sell_by_market = marginal_context$P_export_sell_by_market,
      probability_by_market   = marginal_context$flex_probab_down_by_market,
      P_import_buy_row        = period_chunk$Elec_unit_cost_import_buy,
      P_import_sell_row       = period_chunk$Elec_unit_cost_import_sell,
      P_export_buy_row        = period_chunk$Elec_unit_cost_export_buy,
      P_export_sell_row       = period_chunk$Elec_unit_cost_export_sell,
      probability_row         = period_chunk$Flex_Probab_down,
      discount_by_market      = discount_by_market,
      discount_row            = discount_row
    ) +
    compute_recovery_energy_cost(
      E_plan                  = period_chunk$Elec_total_plan,
      E_flex                  = period_chunk$Elec_total_plan_flex_up,
      phase                   = period_chunk$Flex_phase_up_plan,
      MarketUTC_candidate     = period_chunk$MarketUTC,
      market_utc              = marginal_context$market_utc,
      P_import_buy_by_market  = marginal_context$P_import_buy_by_market,
      P_import_sell_by_market = marginal_context$P_import_sell_by_market,
      P_export_buy_by_market  = marginal_context$P_export_buy_by_market,
      P_export_sell_by_market = marginal_context$P_export_sell_by_market,
      probability_by_market   = marginal_context$flex_probab_up_by_market,
      P_import_buy_row        = period_chunk$Elec_unit_cost_import_buy,
      P_import_sell_row       = period_chunk$Elec_unit_cost_import_sell,
      P_export_buy_row        = period_chunk$Elec_unit_cost_export_buy,
      P_export_sell_row       = period_chunk$Elec_unit_cost_export_sell,
      probability_row         = period_chunk$Flex_Probab_up,
      discount_by_market      = discount_by_market,
      discount_row            = discount_row
    )
    period_chunk$Elec_flex_exec_revenue_plan <- 0
    period_chunk$Elec_flex_exec_revenue_plan[nrow(period_chunk)] <- Elec_flex_exec_revenue_total
    rm(Elec_flex_exec_revenue_total)

    # Every term already carries its own sign - see the energy-mode
    # branch above.
    Reward <- alpha_comfort * Performance_flex +
              alpha_cost * (period_chunk$Elec_Cost_plan +
                            period_chunk$Elec_Cost_distribution_plan +
                            period_chunk$Elec_flex_com_revenue_plan +
                            period_chunk$Elec_flex_exec_revenue_plan) +
              period_chunk$Technical_feasibility_penalty_plan

  } else {
    stop("Invalid optimization_aim: '", optimization_aim,
         "'. Must be 'energy', 'operation', 'flexibility' or 'operationflex'.")
  }

  # 6. Store per-row reward in period_chunk and return the data frame
  period_chunk$Reward <- Reward
  return(period_chunk)
}
