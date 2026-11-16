# -------------------------------------------------------------
# Function: evaluate_control.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function evaluates the optimality of a control setpoint
# schedule over a particular period.
# This is a generic wrapper function that allows to integrate an
# optimizer with the simulation of the building. The building is
# simulated through the operation simulate_itinerary of its type of
# model (model_type_contract(); period_calculation() for a Building).
# The function works on the piece of a market: each asset is
# simulated in its view of the piece, and its plan goes back into its
# table. The derivation of the itineraries and the reward work on the
# piece too. The search for flexibility windows asks each asset in its
# view whether it has something to offer, and builds each candidate
# window on the piece, through system_flex_window(), which hands back
# a new piece with the window and never modifies the piece it
# receives. The reward of the candidate is computed on that new piece.
# Its internal objects are removed with rm(list = ), which does not
# call match.call() as rm() with names does: this function runs once
# for every candidate of the genetic algorithm.
# The flexibility windows are windows of the system:
# system_flex_window() fixes their phases, has every asset draft its
# contribution through the operation window_draft of its type of
# model, applies the commitment margin of the set of assets, has every
# asset draw its contribution through the operation
# window_contribution, and checks the commitment of the net.
# It performs the following steps:
#   1. Simulates each asset over the period in its view, through the
#      operation simulate_itinerary, and stores results in *_plan
#      columns of its table. The assets that read the net electricity
#      of the rest of the system (operation reads_rest_net) are
#      simulated after the others (asset_simulation_order()), with
#      the electricity of the plan of those in their view
#      (write_rest_net()).
#   2. Calls derive_flex_itineraries() on the piece to build the
#      *_plan_flex_down and *_plan_flex_up itineraries from the *_plan
#      columns and the flexibility standing from earlier markets.
#      When an asset offers alternatives for the Recovery Phase of a
#      window (a battery), the valuation that chooses among them is
#      built before (build_recovery_valuation()), and the windows
#      standing are drawn with the alternative that has the best
#      reward. When the evaluation receives a derivation already
#      drawn over the same plan with the same control (derivation),
#      it takes it instead of drawing it again: the result is the
#      same.
#   3. Calls reward_function() on the piece, on the three itineraries.
#      For the "energy" aim this is the result.
#   4. For "flexibility" mode, performs a parametric evaluation over
#      all market slots of the piece as candidate flexibility
#      event start points. Each candidate window is built on the
#      piece by system_flex_window(), which returns a new piece with
#      the window, and valued there. When an asset offers alternatives
#      for the Recovery Phase of a window (a battery), the window is
#      built with the alternative that has the best reward
#      (build_recovery_valuation()). For each market slot:
#      - Skips it if the leg's flexibility is worth nothing there (see
#        "Value of a slot" below), or if no asset has anything to offer
#        on the leg there (operation slot_offer)
#      - Tests expanding flexibility events by adding consecutive market
#        slots, up to commitment_phase_length_max
#      - Uses flexibility = 1 (full flexibility)
#      - Stops expanding at a slot where the leg's flexibility is worth
#        nothing, or when the reward does not improve
#      The best reward across all candidates is returned.
# -------------------------------------------------------------
# Inputs
#   piece        : List. The piece of the optimization horizon, as
#                  build_market_piece() gives it: the table of the
#                  system and the table of each asset. The plan of each
#                  asset is simulated in its view; the derivation and the
#                  reward work on the piece, and the search builds each
#                  candidate window on the piece.
#                  Together the tables must include the columns expected by
#                  period_calculation(), for example:
#                    - time
#                    - Text
#                    - SolarR
#                    - Occupancy
#                    - MarketUTC
#                    - Ti_plan
#                    - Te_plan
#                    - Act_heat_plan
#                    - Act_cool_plan
#   controls     : Named list or NULL (default NULL). The control of
#                  each asset, named by its asset_id, as
#                  decode_chromosome() returns it. For the building,
#                  the setpoint schedule with hysteresis deadbands
#                  already applied, as returned by
#                  convert_modes_to_setpoints(). NULL keeps the
#                  setpoints its view holds.
#   parameters   : Named list. Model and control parameters passed to
#                  period_calculation(), system_flex_window(), and
#                  reward_function(). Must contain:
#                    parameters$assets :
#                      The asset registry; the asset_type of each
#                      asset gives its type of model.
#                    parameters$joined_cols :
#                      The column order of the view of an asset.
#                      The flexibility search reads every asset of the
#                      registry, through the operation slot_offer.
#                    What the operation slot_offer of each asset reads:
#                      for a Building,
#                      parameters$computing$flex_energy_tol and what
#                      resolve_flex_up_hvac() reads.
#                    parameters$market$market_resolution :
#                      Numeric (minutes). Market slot duration used as the
#                      minimum Commitment Phase length step.
#                    parameters$control$commitment_phase_length_max :
#                      Numeric (hours). Longest Commitment Phase a candidate
#                      window may reach.
#   simulation_control : Named list. Simulation control object. Used to
#                        pass these elements to the flexibility
#                        evaluation functions via a cloned object:
#     - simulation_control$evaluation$optimization_aim : Character.
#       "energy", "operation", "flexibility" or "operationflex".
#     - simulation_control$indexes_local$i_flex
#     - simulation_control$flexibility$commitment_phase_length
#     - simulation_control$flexibility$flexibility
#   marginal_context   : Named list or NULL (default NULL). Passed through to
#                        reward_function() (see resolve_marginal_context()).
#                        The flexibility search also reads from it, for
#                        each leg, the commitment and execution sell
#                        prices and the activation probability of every
#                        target interval:
#                          - p_<leg>_com_sell_by_market
#                          - p_<leg>_exec_sell_by_market
#                          - flex_probab_<leg>_by_market
#   derivation         : Named list or NULL (default NULL). A derivation
#                        of the itineraries already drawn, as
#                        committed_recovery_cost() hands it back:
#                          - piece: the piece it was drawn over.
#                          - simulation_control: the control it was
#                            drawn with.
#                          - derived: what derive_flex_itineraries()
#                            gave.
#                        It is used only when its piece and its control
#                        are identical to the plan simulated here and
#                        to simulation_control. NULL draws the
#                        derivation here.
# -------------------------------------------------------------
# Outputs
#   A named list with the following elements (in this order):
#   piece        : List. The piece with the plan of each asset in its
#                  table, and in the table of the system the
#                  flexibility itineraries, their phases,
#                  Standing_commitment_held_legs_plan and the
#                  'Reward' column of the best flexibility scenario
#                  found (for "flexibility" mode), or of the plan
#                  itself (for "energy" mode). 'Reward' holds the
#                  per-row reward values as set by reward_function().
#   reward       : Numeric scalar. Sum of per-row reward values in
#                  the 'Reward' column. Best reward found over all
#                  flexibility candidate market slots (for "flexibility"
#                  mode), or the direct reward from the plan (for
#                  "energy" mode).
# -------------------------------------------------------------
# Code outline
# 1. Simulate the plan of each asset in its view
# 2. Derive the *_plan_flex_down and *_plan_flex_up itineraries from
#    *_plan and the standing commitment, on the piece
# 3. Compute reward function on the piece
# 4. Evaluate flexibility scenarios (if optimization_aim is flexibility):
#    phase A downward, then phase B upward; the views of the assets
#    are laid out once before the search
# 5. Return the piece
# -------------------------------------------------------------
# Usage instructions
# result <- evaluate_control(piece, controls, parameters,
#                            simulation_control, marginal_context,
#                            derivation)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - Simulation results are stored under execution column names (no suffix)
#     and then aliased to *_plan columns before reward_function() is called,
#     so that reward_function() can read Comfort_plan, Elec_total_plan, etc.
#   - For "flexibility" mode, evaluate_control() always initializes the
#     *_plan_flex_down and *_plan_flex_up columns before searching.
#   - Value of a slot: both loops skip a start slot, and stop growing a
#     window at a slot, where the flexibility of the leg is worth
#     nothing to the reward. That value is the effective sell price of
#     the leg, the commitment price plus the execution price times the
#     activation probability, read from marginal_context: the prices
#     resolve_marginal_context() gives the market, published inside the
#     control horizon and estimated beyond it, which are the ones the
#     reward values the window with. A slot with only an execution
#     price is worth something, and is searched. A slot that is not
#     one of the target intervals of marginal_context is not valued by
#     the reward, and is worth nothing.
#   - Accepted flexibility windows never overlap WITHIN a leg, and the
#     window that is skipped over is the WHOLE one: Commitment, Neutral
#     and Recovery. When a window whose Commitment Phase is n slots is
#     accepted at slot i, the outer loop resumes past slot i + n + the
#     slots the Neutral and Recovery Phases take, so a later window can
#     neither rewrite the columns of a stretch already committed nor
#     start while the building is still recovering. When nothing is
#     accepted at slot i, the outer loop resumes at slot i + 1, so
#     every start slot is tested. The outer loop is a while loop for
#     this reason.
#   - Windows of DIFFERENT legs may overlap, and that is intended. The
#     two searches run one after the other over their own set of
#     columns, so a slot can carry a downward commitment and an upward
#     one at the same time; physically they are two different
#     itineraries and neither is flown unless the operator calls it.
#   - The two searches share one algorithm, written once and told which
#     leg it works on. The legs differ only in two filters:
#       - The value of a slot, a rule of the system: the prices that
#         give a slot its value.
#       - The offer of the assets, through the operation slot_offer of
#         each asset. Downward, a slot is searched when some asset
#         consumes in it, whatever the net of the system. Upward, when
#         some asset can raise its electricity from it.
#   - A candidate window may close on the last market slot of
#     the piece, but it is never accepted: system_flex_window()
#     returns the piece untouched when the time left
#     from i_flex to the close of the control horizon does not cover the
#     Commitment, Neutral and Recovery Phases, and a window closing that
#     late never does. The
#     reward then comes back unchanged and the inner loop breaks.
#   - A candidate window never grows past commitment_phase_length_max.
#     The Commitment Phase is assembled from whole market slots, so the
#     bound is applied as floor(commitment_phase_length_max /
#     market_slot_h) slots. When commitment_phase_length_max is shorter
#     than one market slot no window is admissible and no flexibility is
#     committed, because a maximum below the resolution of the market
#     the commitment is sold on cannot be expressed on that market's grid.
#   - If all market slots are skipped in "flexibility" mode, the returned
#     reward is the baseline reward without flexibility.
#   - commitment_phase_length and flexibility are set in
#     simulation_control$flexibility and passed through to the flexibility
#     evaluation functions via a cloned simulation_control_2 object.
#   - COMPUTATIONAL COST: for "flexibility"/"operationflex" mode, the outer
#     loop visits each of the L unique market slots of the piece at most
#     once (accepted windows are skipped over, not re-entered), and for each
#     starting slot the inner while loop keeps expanding the candidate
#     flexibility window as long as the reward keeps improving, calling
#     system_flex_window() + reward_function() once per expansion step.
#     With an asset that offers alternatives for the Recovery Phase,
#     each call of system_flex_window() also draws the window with the
#     other alternatives and values them.
#     The expansion stops at M = floor(commitment_phase_length_max /
#     market_slot_h) slots, so the inner loop is bounded by M rather than
#     by the horizon: worst case is O(M) calls per starting slot and
#     O(L * M) overall, each itself proportional to the flexibility
#     window size via period_calculation(). This function is in turn
#     evaluated once per GA individual per generation by
#     optimize_control_step()/fitness_funct_optimize_mode(), so a longer
#     optimization horizon (larger L) or a larger GA population/generation
#     count multiplies this cost accordingly. Keep the Piloting optimization
#     horizon and GA population/generation settings conservative for long
#     horizons.
# -------------------------------------------------------------
evaluate_control <- function(piece,
                             controls = NULL,
                             parameters,
                             simulation_control,
                             marginal_context = NULL,
                             derivation = NULL) {

  # -------------------------------------------------------------
  # 1. The plan of each asset, in its view
  # Each asset simulates its plan over the setpoints of this
  # candidate in its own view of the piece, and the plan goes back
  # into its table.
  # -------------------------------------------------------------
  {
    column_order <- parameters$joined_cols

    # asset_simulation_order is called to order the assets: those that
    # read the net electricity of the rest of the system are simulated
    # after the others.
    simulation_order <- asset_simulation_order(parameters)
    simulated        <- character(0)

    for (CONT_005 in simulation_order) {
      # Every operation of the type of model of an asset receives its
      # parameters, its entry of parameters$assets.
      asset <- parameters$assets[[CONT_005]]

      # model_type_contract is called to take the operations of the type
      # of model of the asset, through which this function simulates
      # its plan.
      model <- model_type_contract(asset$asset_type)

      # piece_asset_view is called to take the view of the asset: the
      # table that its operations work on.
      view <- piece_asset_view(
        piece        = piece,
        asset_id     = CONT_005,
        column_order = column_order
      )

      # The operation reads_rest_net of the model says whether the
      # asset works over the net electricity of the rest of the
      # system. If it does, write_rest_net is called to write in its
      # view the electricity of the plan of the assets simulated
      # before it.
      if (model$reads_rest_net(asset)) {
        view <- write_rest_net(
          view      = view,
          assets    = piece$assets,
          asset_ids = simulated,
          itinerary = "plan",
          rows      = seq_len(nrow(view))
        )
      }

      # The operation simulate_itinerary of the model is called to
      # simulate the asset over the setpoints of this candidate, its
      # entry of controls, in the plan context. Without controls, the
      # asset keeps the setpoints its view holds.
      view <- model$simulate_itinerary(
        period_chunk        = view,
        asset               = asset,
        calculation_mode    = 1,
        calculation_context = "plan",
        set_point_df        = controls[[asset$asset_id]]
      )

      # piece_absorb_asset is called to take the simulated plan back
      # into the table of the asset, and to sum the net electricity of
      # the system again.
      piece <- piece_absorb_asset(
        piece    = piece,
        asset_id = CONT_005,
        view     = view
      )
      simulated <- c(simulated, CONT_005)
      rm(list = c("asset", "model", "view"))
    }
    rm(list = c("CONT_005", "simulation_order", "simulated"))
  }

  # Build both flexibility itineraries from the plan AND the flexibility
  # already committed by earlier markets, so that every market starts
  # its search from what is already sold: see
  # derive_flex_itineraries().
  # build_recovery_valuation is called to resolve, once for the whole
  # evaluation, what the system needs to choose how an asset draws the
  # Recovery Phase of a window: the alternatives it offers and the
  # terms of the reward of the plan. It is NULL when no asset offers
  # any, and the windows are then built as they are with a single
  # alternative.
  recovery_valuation <- if (is.null(marginal_context)) {
    NULL
  } else {
    build_recovery_valuation(
      piece            = piece,
      parameters       = parameters,
      marginal_context = marginal_context
    )
  }

  # A derivation drawn over the same plan with the same control is
  # the one derive_flex_itineraries would draw here, so it is taken
  # as it is.
  if (!is.null(derivation) &&
      identical(derivation$piece, piece) &&
      identical(derivation$simulation_control, simulation_control)) {
    derived <- derivation$derived
  } else {
    # derive_flex_itineraries is called to draw both itineraries over
    # the plan of this candidate.
    derived <- derive_flex_itineraries(
      piece              = piece,
      parameters         = parameters,
      simulation_control = simulation_control,
      recovery_valuation = recovery_valuation
    )
  }
  rm(list = "derivation")
  piece   <- derived$piece

  # How many assets and legs hold a standing window of the guard zone
  # over this candidate's plan travels with the piece, because it is
  # reward_function() that has to price it: an asset that cannot
  # rebuild an already-sold window keeps it only within the limits of
  # its equipment, and may not deliver it as sold.
  piece$system$Standing_commitment_held_legs_plan <- nrow(derived$held)
  rm(list = "derived")

  # Rows each leg already occupies with a window committed by an earlier
  # market: its Commitment, Neutral and Recovery Phases, including the
  # tail of a window that started before this piece. A new window of
  # the same leg may not touch them, so that it never starts before an
  # earlier window of that leg has finished its Recovery Phase.
  # The phases are taken both from the itineraries just derived and from
  # the committed energy itself (reconstruct_flex_phases()), because a
  # window that could not be redrawn over this plan is held with its
  # Commitment Phase alone, and its Neutral and Recovery Phases still
  # belong to it.
  occupied_rows <- list(
    down = piece$system$Flex_phase_down_plan > 0 |
      reconstruct_flex_phases(piece$system, "down", parameters) > 0,
    up   = piece$system$Flex_phase_up_plan > 0 |
      reconstruct_flex_phases(piece$system, "up", parameters) > 0
  )

  # The aim of the market this evaluation belongs to decides whether
  # flexibility windows are searched, and how the reward is valued.
  optimization_aim <- simulation_control$evaluation$optimization_aim

  # Compute the reward for this flexibility scenario
  piece <- reward_function(
    piece              = piece,
    parameters         = parameters,
    optimization_aim   = optimization_aim,
    marginal_context   = marginal_context
  )
  reward <- sum(piece$system$Reward)

  # For flexibility mode, search for flexibility windows, in two chained
  # phases: first downward, then upward over the piece the downward
  # phase leaves behind.
  # -----------------------------------------------------------
  # The two phases share one search algorithm, so it is written once, as
  # search_flexibility_windows() below, and told which leg it is working
  # on. What differs between the legs is only the three filters and the
  # evaluation function; the loop structure, the acceptance test and the
  # non-overlap rule are the same.
  # The two phases can overlap each other: an upward window may fall on
  # slots a downward window already occupies. Physically they are two
  # different itineraries, each living in its own set of columns, so
  # they do not interfere; economically that interval simply carries a
  # downward commitment and an upward one at the same time. Within each
  # phase, windows still never overlap.
  # The reward is always evaluated over the three itineraries at once,
  # so the upward phase sees the revenue of the downward phase as a
  # constant it cannot improve on by undoing it.
  # -----------------------------------------------------------
  if (optimization_aim == "flexibility" ||
      optimization_aim == "operationflex" ) {

      # piece_layout is called to lay out the views of the assets again,
      # now that the derivation and the reward have created the columns
      # of the system the search writes: no column is added during the
      # search.
      piece <- piece_layout(
        piece        = piece,
        column_order = column_order
      )

      # 1 MarketUTC slot expressed in hours
      market_slot_h <- parameters$market$market_resolution / 60

      # Longest candidate window, in market slots. The Commitment Phase
      # is built by adding whole market slots, so the bound that
      # commitment_phase_length_max sets in hours becomes a bound on the
      # number of slots the inner loop may reach. It is rounded down: a
      # window of the next slot up would already exceed the maximum.
      # system_flex_window() declares
      # commitment_phase_length <= commitment_phase_length_max as a
      # precondition, and this is where the candidates that would break
      # it stop being generated.
      # A commitment_phase_length_max shorter than one market slot
      # leaves no admissible window, and no flexibility is committed:
      # a maximum below the resolution of the market the commitment is
      # sold on cannot be expressed on that market's grid.
      max_commitment_slots <- floor(parameters$control$commitment_phase_length_max /
                                      market_slot_h)

      # The slots an accepted window occupies AFTER its Commitment
      # Phase: the Neutral and Recovery Phases, which belong to the
      # window just as much and over which no new commitment may start.
      # Rounded up, so a tail that does not fill a whole market slot
      # still blocks the slot it falls in.
      tail_slots <- ceiling((parameters$control$neutral_phase_timespan +
                               parameters$control$recovery_phase_timespan) /
                              market_slot_h)

      # The contract of the type of model of every asset of the
      # registry, looked up once for the whole search. The search asks
      # each of them, through the operation slot_offer, whether the
      # asset has anything to offer in a market slot.
      asset_models <- lapply(
        parameters$assets,
        function(CONT_004) {
          model_type_contract(CONT_004$asset_type)
        }
      )

      # Get unique market slots in the piece. The first row is the
      # initial condition of the piece: its time step belongs to the
      # interval before the horizon, so it is in no slot of the search
      # and starts no window.
      unique_market_slots <- unique(piece$system$MarketUTC[-1])

      # The rows of each market slot, and the time of every row, are
      # looked up once here rather than for every candidate window:
      # neither changes during the search, which only rewrites the
      # flexibility columns. The rows are in time order, so the rows
      # a window spans are the stretch from its first row to the last
      # row that does not pass its end.
      if (is.unsorted(as.numeric(piece$system$time), strictly = TRUE)) {
        stop("evaluate_control: the time of the piece must be strictly ",
             "increasing")
      }
      rows_by_slot <- split(seq_len(nrow(piece$system))[-1],
                            factor(match(piece$system$MarketUTC[-1], unique_market_slots),
                                   levels = seq_along(unique_market_slots)))
      row_time_sec <- as.numeric(piece$system$time)

      search_flexibility_windows <- function(piece, reward, leg) {

        fixed_leg <- if (leg == "down") "up" else "down"

        # The search asks each asset, in its view, whether it has
        # something to offer. The views are taken here, and again each
        # time a window is accepted, so that they follow the piece.
        asset_views <- lapply(
          setNames(names(parameters$assets), names(parameters$assets)),
          function(one_id) {
            # piece_asset_view is called to take the table of the asset
            # joined with that of the system.
            piece_asset_view(
              piece        = piece,
              asset_id     = one_id,
              column_order = column_order
            )
          }
        )

        # The value per kWh the reward gives a new commitment of this
        # leg in each market slot: the commitment price, paid whether
        # or not the service is called, plus the execution price
        # weighted by the activation probability. Both halves are read
        # from marginal_context, so the search sees the same prices as
        # the reward, estimated beyond the control horizon. A slot that
        # is not a target interval of the context is not valued by the
        # reward, and is worth nothing here.
        slot_target <- match(unique_market_slots, marginal_context$market_utc)
        slot_value  <- marginal_context[[paste0("p_", leg, "_com_sell_by_market")]][slot_target] +
          marginal_context[[paste0("p_", leg, "_exec_sell_by_market")]][slot_target] *
          marginal_context[[paste0("flex_probab_", leg, "_by_market")]][slot_target]
        slot_value[is.na(slot_value)] <- 0
        rm(list = "slot_target")

        # A candidate window only rewrites the itinerary of this leg,
        # so every candidate of this search shares the plan and the
        # other leg as they are now. build_reward_cache is called to
        # resolve their terms once, for the whole search of the leg.
        reward_cache <- build_reward_cache(
          piece            = piece,
          parameters       = parameters,
          marginal_context = marginal_context,
          fixed_leg        = fixed_leg
        )

        # Loop 1: Iterate through each market_slot
        # -----------------------------------------------------------
        # Written as a while loop, not a for loop, because the index has
        # to advance by the length of an accepted flexibility window
        # rather than always by one: a window of n slots accepted at
        # CONT_002 occupies slots CONT_002 .. CONT_002 + n - 1, and
        # restarting the search inside it would let a second window
        # overwrite the columns of a stretch already committed by the
        # first.
        # -----------------------------------------------------------
        CONT_002 <- 1

        while (CONT_002 <= length(unique_market_slots)) {

          # Get all rows belonging to this market_slot
          market_slot_rows <- rows_by_slot[[CONT_002]]

          # 1.0.1 Skip if this leg's flexibility is worth nothing in
          # this slot
          if (slot_value[CONT_002] == 0) {
            CONT_002 <- CONT_002 + 1
            next
          }

          # 1.0.2 Skip if no asset has anything to offer on this leg in
          # this slot. Downward, a slot is searched when some asset
          # consumes in it (for a building, planned electricity in the
          # slot), whatever the net of the system: with an asset that
          # exports, a net of zero or below can still hold a load to
          # switch off. Upward, a slot is searched when some asset can
          # raise its electricity from it (for a building, the prudence
          # rule names a system). An asset that cannot still declines
          # the window inside system_flex_window(), and the others
          # contribute. Asking is far cheaper than a simulation, so
          # this saves the whole inner loop for every start slot where
          # nothing can be offered.
          slot_offered <- FALSE
          for (CONT_004 in names(parameters$assets)) {

            # The operation slot_offer of the asset is called to know
            # whether it may offer on this leg in this slot.
            if (asset_models[[CONT_004]]$slot_offer(
              period_chunk = asset_views[[CONT_004]],
              leg          = leg,
              slot_rows    = market_slot_rows,
              parameters   = parameters,
              asset        = parameters$assets[[CONT_004]]
            )) {
              slot_offered <- TRUE
              break
            }
          }
          if (!slot_offered) {
            CONT_002 <- CONT_002 + 1
            next
          }

          # 1.1 Keep the piece of this start slot, piece_test. The
          # candidates of this start slot are all built on it, as the
          # window grows: system_flex_window() hands back a new piece
          # with the window and never modifies the piece it receives, so
          # piece_test keeps nothing of a candidate that is not accepted.
          piece_test <- piece

          # 1.2 Test flexibility by market slot
          # 1.2.1 Start with a single market_slot
          n_slots_to_test <- 1

          # Length of the longest window accepted from this starting
          # slot; 0 while none has been accepted. It is what the outer
          # index advances by once the search from this slot is over.
          accepted_slots <- 0

          # Continue testing until we reach the end or stop condition.
          # The bound is the last slot itself, with no margin: whether a
          # window is too close to the end of the period is decided in one
          # place only, system_flex_window(), which
          # returns the chunk untouched when the control horizon has not
          # enough room for the Commitment, Neutral and Recovery Phases.
          # A margin
          # here would be a second, weaker definition of the same thing -
          # a window closing on the last slot leaves at most its own event
          # length before the end of the period, always less than the full
          # window, so it is rejected there anyway - and two definitions
          # of one rule drift apart.
          # The second bound is a different rule and belongs here: it is
          # not about where the window sits in the period but about how
          # long the Commitment Phase itself may grow, and the candidate
          # length is only known at this point.
          while ((CONT_002 + n_slots_to_test - 1) <= length(unique_market_slots) &&
                 n_slots_to_test <= max_commitment_slots) {

            # Get the last market_slot in the current test range
            last_market_slot_idx <- CONT_002 + n_slots_to_test - 1

            # 1.2.2 If this leg's flexibility is worth nothing in the
            # last market_slot, terminate the test
            if (slot_value[last_market_slot_idx] == 0) break

            # Calculate the commitment_phase_length for this test
            # (number of market slots * market slot duration in hours)
            commitment_phase_length <- n_slots_to_test * market_slot_h

            # Get the starting row index (first row of the first market slot)
            i_flex <- market_slot_rows[1]

            # A candidate whose whole window (Commitment, Neutral and
            # Recovery Phases) touches a row this leg already occupies
            # is not tested, and neither is any longer one from here.
            # The rows of the window are those from i_flex whose instant
            # is before its end, as system_flex_window() takes them.
            window_end_time <- piece$system$time[i_flex] +
              (commitment_phase_length +
                 parameters$control$neutral_phase_timespan +
                 parameters$control$recovery_phase_timespan) * 3600
            window_rows <- i_flex:findInterval(as.numeric(window_end_time),
                                               row_time_sec,
                                               left.open = TRUE)
            blocked <- any(occupied_rows[[leg]][window_rows])
            rm(list = c("window_end_time", "window_rows"))
            if (blocked) break
            rm(list = "blocked")

            # 1.2.3 Generate piece_test_inner with system_flex_window()
            # on this leg (flexibility <- 1) and reward_function.
            # Set flexibility parameters in simulation_control_2.
            simulation_control_2 <- simulation_control
            simulation_control_2$indexes_local$i_flex                  <- i_flex
            simulation_control_2$flexibility$commitment_phase_length  <- commitment_phase_length
            simulation_control_2$flexibility$flexibility               <- 1

            # system_flex_window is called to build this candidate
            # window of the system (starting at i_flex, spanning
            # commitment_phase_length): it fixes the phases, has each
            # asset draw its contribution on the columns of this
            # leg, Neutral and Recovery Phases included, and checks the
            # commitment of the net, so its reward can be compared
            # against the current best. It returns the piece with the
            # window, drawn with the alternative of the Recovery Phase
            # that has the best reward when an asset offers several.
            built_window <- system_flex_window(
              leg                = leg,
              piece              = piece_test,
              parameters         = parameters,
              simulation_control = simulation_control_2,
              recovery_valuation = recovery_valuation
            )
            piece_test_inner <- built_window$piece
            rm(list = "built_window")

            # Compute the reward for this flexibility scenario
            piece_test_inner <- reward_function(piece              = piece_test_inner,
                                                parameters         = parameters,
                                                optimization_aim   = optimization_aim,
                                                marginal_context   = marginal_context,
                                                reward_cache       = reward_cache)

            # 1.2.4 Calculate reward_flex
            reward_flex <- sum(piece_test_inner$system$Reward)

            # 1.2.5 If reward_flex is superior to reward
            if (reward_flex > reward) {
              # Overwrite reward
              reward <- reward_flex
              # Overwrite piece, and take the views of the assets again
              # on the piece accepted
              piece <- piece_test_inner
              asset_views <- lapply(
                setNames(names(parameters$assets), names(parameters$assets)),
                function(one_id) {
                  # piece_asset_view is called to take the table of the
                  # asset joined with that of the accepted piece.
                  piece_asset_view(
                    piece        = piece,
                    asset_id     = one_id,
                    column_order = column_order
                  )
                }
              )
              # Record the window just accepted, so the outer loop can
              # resume past it instead of inside it
              accepted_slots <- n_slots_to_test
              # Continue to next iteration: incorporate the next market_slot
              n_slots_to_test <- n_slots_to_test + 1
            } else {
              # 1.2.6 If reward_flex is equal or inferior to reward,
              # go back to point 1 at the next market_slot
              break
            }
          }

          # 1.3 Resume past the WHOLE accepted window, or at the next
          # slot when nothing was accepted from this one.
          # Past the whole window and not past its Commitment Phase: a
          # window owns its Neutral and Recovery Phases too, and a new
          # commitment cannot start while the building is still
          # recovering from the last one - the Recovery Phase is flown
          # under calculation mode 3 with the power caps of
          # build_hvac_lock_caps(), so there is nothing free to
          # commit there. Resuming at the end of the Commitment Phase
          # would let a second window start inside the Neutral Phase of
          # the first, and leave the two indistinguishable in the
          # committed energy written to Main_df.
          # A start slot from which nothing was accepted moves the
          # search on by one slot only: no window was placed there,
          # so the next slot is as free as it was, and skipping the
          # length of a window's tail would leave every start slot in
          # between untested.
          CONT_002 <- CONT_002 + if (accepted_slots > 0) accepted_slots + tail_slots else 1
          rm(list = intersect(c("piece_test", "piece_test_inner"), ls()))
        }

        rm(list = "asset_views")
        return(list(piece = piece, reward = reward))
      }

      # Phase A, downward search, and phase B, upward search, over the
      # piece phase A leaves behind.
      for (CONT_003 in c("down", "up")) {
        search_result <- search_flexibility_windows(piece, reward, CONT_003)
        piece         <- search_result$piece
        reward        <- search_result$reward
      }

      rm(list = intersect(
        c("CONT_003", "search_result", "search_flexibility_windows",
          "market_slot_h", "max_commitment_slots", "asset_models", "slot_offered",
          "unique_market_slots", "rows_by_slot", "row_time_sec"),
        ls()
      ))

  } else {

    # For energy mode the reward was already computed above; nothing more to do.

  }

  rm(list = intersect(c("recovery_valuation", "occupied_rows",
                        "optimization_aim", "column_order"), ls()))

  return(list(piece = piece, reward = reward))
}
