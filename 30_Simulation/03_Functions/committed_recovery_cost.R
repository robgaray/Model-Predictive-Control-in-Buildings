# -------------------------------------------------------------
# Function: committed_recovery_cost.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Values, once per market, the expected cost of the Recovery Phase
# of the itineraries already committed, and the value of the energy
# they leave stored, and adds them to the market's
# marginal_context. economic_terms() values the Recovery Phase of
# each candidate as the change against it, so that a candidate
# whose itineraries are the committed ones adds nothing, whatever
# the aim.
# The committed itineraries are rebuilt the way every candidate is
# built:
#   - the plan of each asset is simulated, in its view of the piece,
#     with the setpoints already committed, from the state at the
#     start of the horizon and with the forecast of this market; a
#     row whose setpoints no market has determined takes those of
#     the lowest-numbered mode; the assets that read the net
#     electricity of the rest of the system (operation reads_rest_net
#     of their type of model) are simulated after the others
#     (asset_simulation_order()), with the electricity of the
#     committed plan of those in their view (write_rest_net());
#   - derive_flex_itineraries() draws over that plan, on the piece,
#     the flexibility earlier markets sold, with the alternative of
#     the Recovery Phase that has the best reward when an asset offers
#     several (build_recovery_valuation()), as for a candidate;
#   - their Recovery Phase is valued with this market's prices,
#     exactly as economic_terms() values a candidate's;
#   - when an asset stores energy, the value of the energy the
#     committed plan leaves stored, and that of the energy each
#     committed leg leaves stored against the plan, which
#     economic_terms() takes as the reference of its own terms of
#     stored energy.
# The derivation is handed back with the plan it was drawn over.
# A market that keeps its plan (aims "operation" and
# "operationflex") simulates that same plan again and draws the same
# itineraries over it, so it takes them from here instead of drawing
# them a second time, when its plan and its control are identical.
# -------------------------------------------------------------
# Inputs
#   piece              : List. The piece of the optimization horizon
#                        of the market, before the optimization: its
#                        *_plan setpoints and its committed
#                        flexibility are those of the earlier
#                        markets.
#   parameters         : Named list. Model parameters. Its asset
#                        registry (parameters$assets) gives the type of
#                        model of each asset (model_type_contract()),
#                        and parameters$joined_cols the column order of
#                        the view of an asset.
#   simulation_control : Named list. The control object the market
#                        optimizes with, as handed to
#                        derive_flex_itineraries().
#   marginal_context   : Named list, as returned by
#                        resolve_marginal_context().
# -------------------------------------------------------------
# Outputs
#   A named list with:
#   marginal_context : The marginal_context received, with two more
#                      elements (EUR):
#                        - recovery_cost_committed_down
#                        - recovery_cost_committed_up
#                      and, only when an asset stores energy, three
#                      more (EUR):
#                        - stored_value_committed_plan
#                        - stored_value_committed_down
#                        - stored_value_committed_up
#   derivation       : Named list. The committed flexibility drawn
#                      over the committed plan:
#                        - piece: the piece with the committed plan
#                          simulated, before the derivation.
#                        - simulation_control: the control the
#                          derivation was drawn with.
#                        - derived: what derive_flex_itineraries()
#                          gave over that piece.
# -------------------------------------------------------------
# Code outline
# 1. The committed plan of each asset, under this market's
#    information
# 2. The committed flexibility, drawn over that plan
# 3. Recovery Phase cost of each leg and value of the stored energy
# 4. The derivation handed back
# -------------------------------------------------------------
# Usage instructions
# committed <- committed_recovery_cost(piece, parameters,
#                                      simulation_control,
#                                      marginal_context)
# marginal_context <- committed$marginal_context
# -------------------------------------------------------------
committed_recovery_cost <- function(piece,
                                    parameters,
                                    simulation_control,
                                    marginal_context
                                    ) {

  # -------------------------------------------------------------
  # 1. The committed plan of each asset, under this market's
  #    information
  # Each asset simulates its committed plan in its own view of the
  # piece, and the plan goes back into its table. The assets that
  # read the net electricity of the rest of the system are simulated
  # after the others.
  # -------------------------------------------------------------
  {
    column_order <- parameters$joined_cols

    # asset_simulation_order is called to order the assets: those that
    # read the net electricity of the rest of the system are simulated
    # after the others.
    simulation_order <- asset_simulation_order(parameters)
    simulated        <- character(0)

    for (CONT_003 in simulation_order) {
      # Every operation of the type of model of an asset receives its
      # parameters, its entry of parameters$assets.
      asset <- parameters$assets[[CONT_003]]

      # model_type_contract is called to take the operations of the type
      # of model of the asset, through which its committed plan is
      # simulated.
      model <- model_type_contract(asset$asset_type)

      # piece_asset_view is called to take the view of the asset: the
      # table that its operations work on.
      view <- piece_asset_view(
        piece        = piece,
        asset_id     = CONT_003,
        column_order = column_order
      )

      # The operation default_control of the model
      # (lowest_mode_setpoints() for a building) is called to fill the
      # rows whose control no market has determined: those that are
      # missing (NA).
      fill <- model$default_control(parameters, asset)
      for (CONT_001 in names(fill)) {
        fill_col   <- paste0(CONT_001, "_plan")
        needs_fill <- is.na(view[[fill_col]])
        view[[fill_col]][needs_fill] <- fill[[CONT_001]]
      }

      # The operation reads_rest_net of the model says whether the
      # asset works over the net electricity of the rest of the
      # system. If it does, write_rest_net is called to write in its
      # view the electricity of the committed plan of the assets
      # simulated before it.
      if (model$reads_rest_net(asset)) {
        view <- write_rest_net(
          view      = view,
          assets    = piece$assets,
          asset_ids = simulated,
          itinerary = "plan",
          rows      = seq_len(nrow(view))
        )
      }

      # The operation simulate_itinerary of the model
      # (period_calculation() for a building) is called to simulate the
      # committed plan with the forecast of this market.
      view <- model$simulate_itinerary(
        period_chunk        = view,
        asset               = asset,
        calculation_mode    = 1,
        calculation_context = "plan"
      )

      # piece_absorb_asset is called to take the simulated plan back
      # into the table of the asset.
      piece <- piece_absorb_asset(
        piece    = piece,
        asset_id = CONT_003,
        view     = view
      )
      simulated <- c(simulated, CONT_003)
      rm(list = c("asset", "model", "view"))
      # An asset with no control has no columns to fill: those objects
      # exist only when default_control gave some.
      rm(list = intersect(c("fill", "CONT_001", "fill_col", "needs_fill"),
                          ls()))
    }
    rm(list = c("CONT_003", "simulation_order", "simulated"))
  }

  # -------------------------------------------------------------
  # 2. The committed flexibility, drawn over that plan
  # The piece with the committed plan is kept, to be handed back with
  # the derivation drawn over it.
  # -------------------------------------------------------------
  {
    plan_piece <- piece

    # build_recovery_valuation is called to resolve what the system
    # needs to choose how an asset draws the Recovery Phase of a
    # window, so that the committed flexibility is drawn with the same
    # choice as a candidate's.
    recovery_valuation <- build_recovery_valuation(
      piece            = piece,
      parameters       = parameters,
      marginal_context = marginal_context
    )

    # derive_flex_itineraries is called to draw the flexibility that
    # earlier markets sold over the committed plan, as it is drawn
    # over every candidate's plan.
    derived <- derive_flex_itineraries(
      piece              = piece,
      parameters         = parameters,
      simulation_control = simulation_control,
      recovery_valuation = recovery_valuation
    )
    piece   <- derived$piece
    rm(list = "recovery_valuation")
  }

  # -------------------------------------------------------------
  # 3. Recovery Phase cost of each leg and value of the stored energy
  # The cost is resolved with the same functions and the same prices
  # as a candidate's, so a candidate identical to the committed
  # itineraries gets exactly this value. The same goes for the value
  # of the stored energy, which is only resolved when an asset stores
  # energy.
  # -------------------------------------------------------------
  {
    # system_stored_energy is called to add the change of the energy
    # that the assets store in the committed itineraries. It is NULL
    # when no asset stores energy.
    stored_energy <- system_stored_energy(
      piece      = piece,
      parameters = parameters
    )

    # build_reward_cache is called to resolve the discount factors and
    # the market interval of each row of the committed itineraries,
    # with that change of the stored energy.
    reward_cache <- build_reward_cache(
      piece            = piece,
      parameters       = parameters,
      marginal_context = marginal_context,
      fixed_leg        = NULL,
      stored_energy    = stored_energy
    )

    # The value of the energy the committed plan leaves stored is only
    # taken when the cache values it, that is when an asset stores
    # energy.
    if (!is.null(reward_cache$stored_value_plan)) {
      marginal_context$stored_value_committed_plan <-
        reward_cache$stored_value_plan
    }

    # system_energy_rows is called to take from the committed
    # itineraries the rows the economic side values: the net
    # electricity of the system, the phases, the prices, the
    # probabilities and the change of the stored energy of each row.
    system_rows <- system_energy_rows(
      period_chunk  = piece$system,
      stored_energy = stored_energy
    )

    # flex_leg_reward_terms is called for each leg to value the
    # Recovery Phase of the committed itineraries.
    for (CONT_002 in c("down", "up")) {
      terms <- flex_leg_reward_terms(
        system_rows      = system_rows,
        leg              = CONT_002,
        marginal_context = marginal_context,
        reward_cache     = reward_cache
      )
      marginal_context[[paste0("recovery_cost_committed_", CONT_002)]] <-
        terms$recovery_cost
      if (!is.null(stored_energy)) {
        marginal_context[[paste0("stored_value_committed_", CONT_002)]] <-
          terms$stored_value
      }
    }
    rm(list = c("piece", "column_order", "reward_cache", "system_rows",
                "stored_energy", "CONT_002", "terms"))
  }

  # -------------------------------------------------------------
  # 4. The derivation handed back
  # -------------------------------------------------------------
  {
    derivation <- list(piece              = plan_piece,
                       simulation_control = simulation_control,
                       derived            = derived)
    rm(list = c("plan_piece", "derived"))
  }

  return(list(marginal_context = marginal_context,
              derivation       = derivation))
}
