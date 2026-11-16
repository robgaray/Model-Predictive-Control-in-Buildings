# -------------------------------------------------------------
# Function: reward_function.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function calculates a reward function on the adequacy of
# a particular building HVAC operation over a planning period.
# It reads a piece of the market and values it with the same
# terms whatever the optimization_aim is:
#   - comfort, over the three itineraries;
#   - the marginal energy and distribution cost of the plan;
#   - the revenue of the flexibility of each leg, with the cost of
#     its Recovery Phase;
#   - when an asset stores energy, the value of the energy the plan
#     leaves stored, in the term of the energy of the plan
#     (Elec_Cost_plan), and the value of the energy each leg leaves
#     stored against the plan, in the term of the execution revenue
#     (Elec_flex_exec_revenue_plan), both as the change against the
#     committed itineraries;
#   - the technical feasibility penalty.
# It brings together the two sides of the reward:
#   - the asset side, each asset of the asset registry, through the
#     operations of its type of model (model_type_contract()):
#       - comfort (comfort_term() for a Building) computes the
#         comfort term of the asset from the comfort flags of the
#         three itineraries, weighed with the comfort weight of the
#         asset; the reward adds the terms of all the assets;
#       - window_feasible (flex_window_is_feasible() for a
#         Building) says whether the windows of each leg are a
#         service the asset can render; the technical feasibility
#         penalty counts one penalty per asset and leg that breaks
#         the technical rules of its type, plus one when the
#         windows already sold could not be drawn over the plan;
#   - the system side: economic_terms() computes every economic
#     term from the rows of system_energy_rows() alone, that is
#     the net electricity of the system in each itinerary per row
#     and market interval, and the change of the energy the assets
#     store, with the commitments and prices of marginal_context. It
#     never sees a temperature, a mode or a setpoint.
# Every economic term is differential: it values only the change
# against what earlier markets already committed. An itinerary
# identical to the committed one is valued 0, whatever the aim.
# marginal_context is mandatory: there is no fallback that values
# the full candidate commitment directly (ignoring the differential
# baseline), because such a fallback could silently mask a missing
# or broken marginal-cost chain upstream (e.g. a caller that forgot
# to call resolve_marginal_context()) instead of surfacing it as an
# error.
# Comfort is always evaluated over the full simulated energy flow of
# each itinerary, since the building's thermal evolution depends on
# the full energy applied.
# -------------------------------------------------------------
# The reward is dimensionless
# The two weights are what make it so, and they are kept apart on
# purpose. alpha_comfort is in 1/h and multiplies the comfort term,
# which is measured in hours out of comfort; each building has its
# own, in its comfort group. alpha_cost is in 1/EUR and multiplies
# every economic term, which are in EUR; it is of the system, which
# values the energy of all its assets together. The reward is
# therefore a pure number, and what governs the optimizer's behaviour is
# the ratio between the two weights, not either of them on its own.
# Keeping the two weights apart also leaves room for more complex
# price structures: a new economic term only needs to be added inside
# economic_terms() to be weighted consistently with the rest.
# -------------------------------------------------------------
# Sign convention
# Every term already carries its own sign: comfort is 0 in comfort and
# negative out of it, every economic term is positive for an income
# and negative for an expense, and the feasibility penalty is 0 or
# negative. Reward is therefore a pure sum of the comfort term, the
# weighted economic term and the feasibility penalty, never a mix of
# "+" and "-" that has to be remembered per term.
# -------------------------------------------------------------
# Inputs
#   piece                    : The piece of the planning period. The asset
#                              side (feasibility and comfort) works on the
#                              view of each asset, and the system side on
#                              the table of the system. They hold *_plan,
#                              *_plan_flex_down and *_plan_flex_up columns
#                              produced by period_calculation(),
#                              derive_flex_itineraries() and the flexibility
#                              evaluation functions.
#                              Columns read by comfort_term():
#                                - time
#                                - Comfort_plan
#                                - Comfort_plan_flex_down
#                                - Comfort_plan_flex_up
#                              Columns read by system_energy_rows(), for
#                              the economic terms:
#                                - MarketUTC
#                                - Elec_total_plan
#                                - Elec_total_plan_flex_down
#                                - Elec_total_plan_flex_up
#                                - Flex_phase_down_plan
#                                - Flex_phase_up_plan
#                                - the four row prices
#                                  Elec_unit_cost_import/export_buy/sell
#                                - Flex_Probab_down
#                                - Flex_Probab_up
#                              Columns read by the feasibility check:
#                                - the columns flex_window_is_feasible()
#                                  reads
#                                - Standing_commitment_held_legs_plan,
#                                  when the caller wrote it from
#                                  derive_flex_itineraries()
#   parameters               : Named list. Must contain:
#                                parameters$reward$alpha_cost : Numeric (1/EUR).
#                                  Weight applied to every economic term.
#                                  Mandatory: stop() is raised if absent.
#                                parameters$computing$flex_infeasible_penalty :
#                                  Numeric. Weight of the technical
#                                  feasibility term. Mandatory.
#                                parameters$assets : the asset registry,
#                                  one entry per asset; its asset_type
#                                  gives the type of model, and the
#                                  comfort group of a building its
#                                  comfort weight, alpha_comfort (1/h),
#                                  read by comfort_term().
#   optimization_aim       : Character. Aim of the market the reward is
#                                computed for: "energy", "operation",
#                                "flexibility", or "operationflex".
#                                Mandatory (no default).
#   marginal_context          : Named list. Mandatory (no default). As returned
#                                by resolve_marginal_context(), with:
#                                  - market_utc
#                                  - E_orig_base_by_market
#                                  - E_orig_gross_by_market
#                                  - E_orig_expflex_down_by_market
#                                  - E_orig_expflex_up_by_market
#                                  - P_import_buy_by_market
#                                  - P_import_sell_by_market
#                                  - P_export_buy_by_market
#                                  - P_export_sell_by_market
#                                  - distribution_rate_by_market
#                                  - p_down_com_buy_by_market
#                                  - p_down_com_sell_by_market
#                                  - p_up_com_buy_by_market
#                                  - p_up_com_sell_by_market
#                                  - p_down_exec_buy_by_market
#                                  - p_down_exec_sell_by_market
#                                  - p_up_exec_buy_by_market
#                                  - p_up_exec_sell_by_market
#                                    (the flex prices are per leg,
#                                    "up"/"down", not "import"/"export" - see
#                                    value_flex_operation())
#                                  - flex_probab_down_by_market
#                                  - flex_probab_up_by_market
#                                  - revenue_discount_by_market
#                                  - revenue_discount_per_hour
#                                  - discount_origin_time
#                                  - beyond_control_by_market
#                                  - recovery_cost_committed_down
#                                  - recovery_cost_committed_up
#                                    (added by committed_recovery_cost())
#                                stop()s if NULL, and also if it carries no
#                                revenue discount.
#   reward_cache              : Named list or NULL (default NULL). As returned
#                                by build_reward_cache() for this piece's
#                                plan.
#                                The search for flexibility windows of
#                                evaluate_control() builds it once per leg, with
#                                the other leg fixed, and hands it to every
#                                candidate. With NULL it is built here, with no
#                                leg fixed.
# -------------------------------------------------------------
# Outputs
#   piece        : The input piece, with a 'Reward' column added (or
#                  overwritten) in its table of the system, containing the
#                  per-row reward value for each timestep, plus the
#                  following intermediate result columns (all modes), as
#                  returned by economic_terms(), in the same table:
#                    Elec_Cost_plan              - Numeric. Electricity cost.
#                                                  The whole interval-aggregated
#                                                  marginal cost is concentrated
#                                                  on the last row (this column
#                                                  is not meaningful
#                                                  per-timestep; only its sum
#                                                  matters).
#                    Elec_Cost_distribution_plan - Numeric. Marginal
#                                                  distribution cost
#                                                  (base-energy term only), same
#                                                  last-row concentration as
#                                                  Elec_Cost_plan.
#                  And the columns of the flexibility terms:
#                    Elec_flex_down_plan        - Numeric. Energy difference
#                                                  (plan - plan_flex_down),
#                                                  bounded to the Commitment
#                                                  Phase: it is 0 wherever
#                                                  Flex_phase_down_plan is not
#                                                  1.
#                    Elec_flex_up_plan          - Numeric. Energy difference
#                                                  (plan_flex_up - plan),
#                                                  bounded the same way to
#                                                  Flex_phase_up_plan == 1 and
#                                                  to 0 from below. Both signals
#                                                  are non-negative by
#                                                  construction.
#                    Elec_flex_com_revenue_plan  - Numeric. Certain revenue of
#                                                  the flexibility commitment,
#                                                  at the commitment price alone
#                                                  (same last-row concentration
#                                                  as Elec_Cost_plan).
#                    Elec_flex_exec_revenue_plan - Numeric. Expected revenue of
#                                                  the execution: the execution
#                                                  price weighted by the
#                                                  activation probability, plus
#                                                  the change of the cost of the
#                                                  energy the Recovery Phase
#                                                  would move if the service
#                                                  were called, against the
#                                                  committed itineraries. Same
#                                                  last-row concentration.
#                  And the column of the feasibility penalty:
#                    Technical_feasibility_penalty_plan - Numeric. The
#                                                  whole penalty, of all
#                                                  the assets and legs, on
#                                                  the last row.
#                  The caller is responsible for summing the Reward column
#                  when a scalar reward is required.
# -------------------------------------------------------------
# Code outline
# 1. Extract the alpha_cost parameter
# 2. Terms that depend on the plan only: revenue discount, target
#    interval of each row, and marginal energy and distribution cost
#    (build_reward_cache())
# 3. Technical feasibility of the flexibility itineraries, per asset
#    and leg
# 4. Comfort term (the operation comfort of the model of each asset)
# 5. Economic terms (system_energy_rows() and economic_terms())
# 6. Store the terms and the per-row reward in the data frame
# -------------------------------------------------------------
# Usage instructions
# piece <- reward_function(piece, parameters, optimization_aim,
#                          marginal_context)
# piece <- reward_function(piece, parameters, optimization_aim,
#                          marginal_context, reward_cache)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If marginal_context is NULL, stop() is called immediately (see header).
#   - If parameters$reward$alpha_cost is NULL, stop() is called
#     immediately (no default value is used). comfort_term() does the
#     same with the alpha_comfort of a building.
#   - If marginal_context carries no revenue discount, stop() is called
#     immediately. Treating its absence as "no discount" would silently
#     turn a broken context into a valid-looking optimization run at a
#     different, undeclared prudence.
#   - If optimization_aim is none of "energy", "operation",
#     "flexibility" or "operationflex", stop() is called.
#   - Whatever the aim, the comfort penalty applies to every time step
#     where ANY of Comfort_plan, Comfort_plan_flex_down or
#     Comfort_plan_flex_up is 0 (out of its own band), occupied or not.
#   - Only the Commitment Phase carries a commitment:
#     Elec_flex_down_plan and Elec_flex_up_plan are 0 outside it,
#     and each market interval is valued at its own flexibility
#     prices. The Neutral and Recovery Phases are a consequence of
#     the event, not a service sold, so they enter the reward only
#     through the change of the Recovery Phase cost.
# -------------------------------------------------------------
reward_function <- function(piece,
                            parameters,
                            optimization_aim,
                            marginal_context = NULL,
                            reward_cache     = NULL
                            ) {

  # 0. marginal_context is mandatory: no no-context fallback (see header)
  if (is.null(marginal_context)) {
    stop("reward_function: marginal_context is required. There is no ",
         "fallback that values the full candidate commitment without a ",
         "marginal baseline, because it could silently mask a missing ",
         "or broken marginal-cost chain upstream - make sure ",
         "resolve_marginal_context() is called and its result is passed ",
         "through.")
  }

  # 1. Get the weight of the economic terms from reward_parameters.
  # The weight of the comfort term is of each building, and its
  # comfort operation reads it.
  if (!is.null(parameters$reward$alpha_cost)) {
    alpha_cost <- parameters$reward$alpha_cost
  } else {
    stop("alpha_cost was not found")
  }

  # 2. Terms that depend on the plan only
  # -------------------------------------------------------------
  # build_reward_cache() resolves what every candidate valued over
  # the same plan shares: the revenue discount factors, the target
  # interval of each row and the marginal cost of the plan's energy
  # and distribution. A caller that values many candidates over one
  # plan builds it once and hands it in, with the leg it keeps
  # fixed; otherwise it is built here. The values are the same
  # either way. A cache built here is built on this very piece, so
  # the change of the stored energy it is built with is the one the
  # economic terms read below, and it is resolved only once.
  # -------------------------------------------------------------
  {
    cache_built_here <- is.null(reward_cache)
    if (cache_built_here) {
      # system_stored_energy is called to add the change of the energy
      # that the assets store, in each itinerary of the piece. It is
      # NULL when no asset stores energy.
      stored_energy <- system_stored_energy(
        piece      = piece,
        parameters = parameters
      )

      # build_reward_cache is called to resolve the plan's terms for
      # this call alone, with no leg fixed.
      reward_cache <- build_reward_cache(
        piece            = piece,
        parameters       = parameters,
        marginal_context = marginal_context,
        fixed_leg        = NULL,
        stored_energy    = stored_energy
      )
    }
  }

  # 2.1. Views of the assets
  # Each asset is judged, and its comfort is computed, in its own view.
  # The views are taken once, for blocks 3 and 4.
  # -------------------------------------------------------------
  {
    views <- lapply(
      setNames(names(parameters$assets), names(parameters$assets)),
      function(one_id) {
        # piece_asset_view is called to take the table of the asset
        # joined with that of the system.
        piece_asset_view(
          piece        = piece,
          asset_id     = one_id,
          column_order = parameters$joined_cols
        )
      }
    )
  }

  # 3. Technical feasibility of the flexibility itineraries
  # -------------------------------------------------------------
  # A window that breaks the technical rules of an asset is not a
  # service the asset can render, and the optimizer has to see that
  # as a cost rather than simply fail to sell anything. For a
  # building, the rule is that a window may not raise the
  # electricity of BOTH its thermal systems over the plan.
  # flex_evaluation() already refuses such a
  # window before it is placed, so in a healthy run this term is zero;
  # it is the net for a candidate that carries one anyway, and it is
  # what makes the region visible to the search instead of merely
  # unprofitable.
  # The rules are checked within each asset, one leg at a time, and
  # each asset and leg that breaks them adds one penalty. Nothing is
  # checked between two assets: one building may raise its heating
  # while another raises its cooling.
  # It is a check of the assets, made over the view of each asset: the
  # economic side never sees the windows.
  # The whole penalty is written on a single row, as the lump-sum
  # economic terms are, so that summing over the horizon does not
  # multiply it by the number of rows.
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

    infeasible_legs <- 0L
    for (CONT_001 in names(parameters$assets)) {
      asset <- parameters$assets[[CONT_001]]

      # model_type_contract is called to take the operations of the
      # type of model of the asset, whose technical rules are checked.
      model <- model_type_contract(asset$asset_type)

      for (CONT_002 in c("down", "up")) {
        if (identical(reward_cache$fixed_leg, CONT_002)) {
          # reward_cache already carries the answer of each asset for
          # the leg it keeps fixed.
          feasible <- reward_cache$fixed_terms$feasible[[CONT_001]]
        } else {
          # The operation window_feasible of the model
          # (flex_window_is_feasible() for a building) is called to
          # judge the windows of this leg by the technical rules of
          # the asset.
          feasible <- model$window_feasible(
            period_chunk = views[[CONT_001]],
            leg          = CONT_002,
            parameters   = parameters,
            asset        = asset
          )
        }
        infeasible_legs <- infeasible_legs + as.integer(!feasible)
      }
      rm(list = c("asset", "model", "feasible"))
    }
    rm(list = c("CONT_001", "CONT_002"))

    # And the other way a candidate can be infeasible: over its plan, an
    # asset cannot rebuild a window of the guard zone that was already
    # sold, because it would raise both thermal systems, or because the
    # plan leaves it no room (for an upward window whose system the
    # prudence rule leaves undecided, with both systems), so it can
    # only hold it within the limits of its equipment.
    # derive_flex_itineraries() reports each asset and leg that holds
    # such a window, because it is what tried to draw it, and the
    # caller writes how many they are in
    # Standing_commitment_held_legs_plan. Each of them adds one
    # penalty, whatever the number of windows it holds on that leg. A
    # piece that never went through it carries no such column and
    # nothing is added.
    if (!is.null(piece$system$Standing_commitment_held_legs_plan)) {
      infeasible_legs <- infeasible_legs +
        max(c(0L, piece$system$Standing_commitment_held_legs_plan),
            na.rm = TRUE)
    }

    Technical_feasibility_penalty <- rep(0, nrow(piece$system))
    Technical_feasibility_penalty[nrow(piece$system)] <-
      -FLEX_INFEASIBLE_PENALTY * infeasible_legs

    rm(list = c("FLEX_INFEASIBLE_PENALTY", "infeasible_legs"))
  }

  # -------------------------------------------------------------
  # 4. Comfort term
  # The reward has the same terms whatever the aim:
  #   - comfort, over the three itineraries;
  #   - the marginal energy and distribution cost of the plan;
  #   - the commitment and execution revenue of each flexibility
  #     leg, with the cost of its Recovery Phase;
  #   - the technical feasibility penalty.
  # The aim is checked here, although no term depends on it, so
  # that a market with an unknown aim stops instead of being
  # valued.
  # -------------------------------------------------------------
  {
    if (!optimization_aim %in% c("energy", "operation", "flexibility", "operationflex")) {
      stop("Invalid optimization_aim: '", optimization_aim,
           "'. Must be 'energy', 'operation', 'flexibility' or 'operationflex'.")
    }

    # The comfort term is the sum of the comfort terms of the assets,
    # each weighed with the comfort weight of its asset. The term of
    # the first asset is taken as it is, and those of the others are
    # added to it.
    comfort <- NULL
    for (CONT_003 in names(parameters$assets)) {
      asset <- parameters$assets[[CONT_003]]

      # model_type_contract is called to take the operations of the
      # type of model of the asset, whose comfort term this is.
      model <- model_type_contract(asset$asset_type)

      # The operation comfort of the model (comfort_term() for a
      # building) is called to compute, from the comfort flags of
      # the three itineraries, the weighted hours out of comfort of
      # each row.
      asset_comfort <- model$comfort(
        period_chunk = views[[CONT_003]],
        asset        = asset
      )
      comfort <- if (is.null(comfort)) {
        asset_comfort
      } else {
        comfort + asset_comfort
      }
      rm(list = c("asset", "model", "asset_comfort"))
    }
    rm(list = c("CONT_003", "views"))
  }

  # -------------------------------------------------------------
  # 5. Economic terms
  # The flexibility terms are always computed, and they are 0 when
  # no leg carries a commitment. A market with the "energy" aim
  # places no new window, but its itineraries still carry the
  # flexibility that earlier markets sold: derive_flex_itineraries()
  # restates it over the candidate's plan. Inside the control
  # horizon any change of it is settled at this market's prices.
  # After it the commitment stands, and a candidate is valued at
  # most at it: the part the plan can no longer hold is the
  # re-purchase a later market will have to make. Either way, a plan
  # that can no longer hold a sold commitment pays for it, and the
  # flexibility terms make that cost visible to the decision.
  # -------------------------------------------------------------
  {
    # The change of the stored energy is only resolved when the cache
    # values it, that is when an asset stores energy. The cache is
    # built on the plan of the candidate, which is the one the
    # itineraries of this piece follow. A cache built above already
    # resolved it on this piece.
    if (!cache_built_here) {
      stored_energy <- NULL
      if (!is.null(reward_cache$stored_value_plan)) {
        # system_stored_energy is called to add the change of the
        # energy that the assets store, in each itinerary of the
        # candidate.
        stored_energy <- system_stored_energy(
          piece      = piece,
          parameters = parameters
        )
      }
    }

    # system_energy_rows is called to take from the table of the
    # system only what it knows of the candidate: the net
    # electricity of the system in each itinerary, with the market
    # interval, the phases, the prices, the probabilities and the
    # change of the stored energy of each row.
    system_rows <- system_energy_rows(
      period_chunk  = piece$system,
      stored_energy = stored_energy
    )

    # economic_terms is called to value those rows against the
    # commitments and prices of marginal_context, with the plan's
    # terms reward_cache carries.
    economic <- economic_terms(
      system_rows      = system_rows,
      alpha_cost       = alpha_cost,
      marginal_context = marginal_context,
      reward_cache     = reward_cache
    )

    rm(list = c("system_rows", "stored_energy", "cache_built_here"))
  }

  # -------------------------------------------------------------
  # 6. Store the terms and the per-row reward
  # Every term already carries its own sign (comfort: neutral in
  # comfort, negative out of it; economic terms: positive income,
  # negative expense; feasibility: 0 or negative), so Reward is a
  # plain sum.
  # -------------------------------------------------------------
  {
    piece$system$Elec_Cost_plan                     <- economic$Elec_Cost_plan
    piece$system$Elec_Cost_distribution_plan        <- economic$Elec_Cost_distribution_plan
    piece$system$Technical_feasibility_penalty_plan <- Technical_feasibility_penalty
    piece$system$Elec_flex_down_plan                <- economic$Elec_flex_down_plan
    piece$system$Elec_flex_up_plan                  <- economic$Elec_flex_up_plan
    piece$system$Elec_flex_com_revenue_plan         <- economic$Elec_flex_com_revenue_plan
    piece$system$Elec_flex_exec_revenue_plan        <- economic$Elec_flex_exec_revenue_plan

    piece$system$Reward <- comfort +
                           economic$economic_reward +
                           Technical_feasibility_penalty

    rm(list = c("alpha_cost", "reward_cache", "comfort", "economic",
                "Technical_feasibility_penalty"))
  }

  return(piece)
}
