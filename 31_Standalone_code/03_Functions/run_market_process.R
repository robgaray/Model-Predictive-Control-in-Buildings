# -------------------------------------------------------------
# Function: run_market_process.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Runs one market over the piece of the call, from i0 to
# i_end_horizon. The piece (expand_to_steps()) holds the table of the
# system and one table per asset. Every function the process calls
# works on the piece, and the plan of each asset is simulated asset
# by asset, in the view of each one (piece_asset_view()), through the
# operations of its type of model (model_type_contract()). Whenever
# the plan is simulated, the assets that read the net electricity of
# the rest of the system (a battery) are simulated after the others
# (asset_simulation_order()), over the electricity of the plan of the
# assets simulated before them (write_rest_net()):
#   1. Aim of the market.
#   2. Initial state. The control that no market has determined yet
#      takes the default of each asset, and each asset starts its
#      plan from the state the call gave it at i0: the three
#      itineraries start from the state of the plan.
#   3. Initialization stretch, from i0 to i_begin_horizon. The plan is
#      flown with the control it already carries, from the state of
#      the plan at i0, and both flexibility itineraries are projected
#      over it: the windows committed from i0 onwards are drawn as the
#      new plan allows, without judging them and without changing any
#      commitment. The state reached at i_begin_horizon is written
#      into the piece. When a window whose Commitment Phase starts in
#      this stretch runs into the horizon, the stretch is extended to
#      the end of its Recovery Phase. The optimization continues its
#      tail over the plan of each candidate, from the state the window
#      left at i_begin_horizon, and starts no window of that leg on
#      it.
#   4. Optimization, from i_begin_horizon to i_end_horizon, according
#      to the aim of the market:
#        - "energy", "flexibility": the controls are optimized
#        - "operation": the plan is simulated as it is and its
#          itineraries rebuilt; an asset that offers more than one
#          way to draw the Recovery Phase of a window chooses one
#          with the valuation of build_recovery_valuation()
#        - "operationflex": the plan is simulated as it is and
#          flexibility is searched over it
#      The valuation of the committed recovery draws the committed
#      flexibility over the committed plan. The "operation" and
#      "operationflex" aims take that derivation when the plan they
#      simulate and their control are identical to the ones it was
#      drawn with, instead of drawing it a second time.
#      Whatever the aim, the commitments of the market interval are
#      kept inside the commitment margin: the part the new plan no
#      longer holds is given back (see derive_flex_itineraries()).
#      That is the only flexibility a market with the "operation" aim
#      trades. An asset with no control to choose, such as a
#      photovoltaic installation, is simulated as it is by every aim.
#   5. The result is written into the piece over the control horizon,
#      from i_begin_horizon to i_end_control: the plan, the
#      flexibility itineraries and the commitments, whatever the aim.
#      With the "operation" and "operationflex" aims the plan keeps its
#      control and is the one simulated with the latest forecast, so
#      its energy is renominated.
# -------------------------------------------------------------
# The first row of each stretch
# The first row of a stretch is its initial condition. Its time step
# falls in the market interval before the stretch, so it is left out
# of the valuation, and it is never the start of a flexibility window:
# its commitments are set to 0 inside the stretch.
# -------------------------------------------------------------
# Inputs
#   piece            : List. The piece of the call, as built by
#                      expand_to_steps().
#   aim_raw          : Character. Aim of the market: "E", "E+F", "O"
#                      or "O+F".
#   row_index        : Named list of row positions in the piece:
#                      i_begin_horizon, i_end_control, i_end_horizon.
#   parameters       : Named list. Simulation parameters. Its asset
#                      registry (parameters$assets, the assets of the
#                      call) gives the type of model of each asset,
#                      whose operations simulate it, and joined_cols
#                      the columns of the view of an asset.
#   marginal_context : Named list. As returned by
#                      resolve_marginal_context().
#   worker_cluster   : Cluster of worker processes of the R session,
#                      as returned by start_worker_cluster(), when
#                      parallel = 1; NULL otherwise. Passed through to
#                      optimize_control_step().
# -------------------------------------------------------------
# Outputs
#   List. The piece with the plan, the flexibility itineraries and the
#   commitments written over the control horizon, and the state
#   written at i_begin_horizon.
# -------------------------------------------------------------
# Code outline
# 1. Aim of the market
# 2. Initial state at i0
# 3. Initialization stretch
# 4. Optimization
# 5. Injection
# -------------------------------------------------------------
# Usage instructions
# piece <- run_market_process(piece, "E+F", row_index, parameters,
#                             marginal_context, worker_cluster)
# -------------------------------------------------------------

run_market_process <- function(piece,
                               aim_raw,
                               row_index,
                               parameters,
                               marginal_context,
                               worker_cluster
                               ) {

  # -------------------------------------------------------------
  # 1. Aim of the market
  # -------------------------------------------------------------
  {
    # map_optimization_aim is called to turn the aim code into the
    # internal name that selects the optimization branch below.
    aim <- map_optimization_aim(aim_raw = aim_raw)

    contexts     <- c("plan", "plan_flex_down", "plan_flex_up")
    column_order <- parameters$joined_cols

    # Builds the simulation_control object the reward and the
    # flexibility functions read, for a stretch of the piece that
    # starts at its row 1:
    #   - indexes_local$i_end_control: last row a window may reach
    #   - indexes_local$i_flex: row where a flexibility window starts
    #   - flexibility$commitment_phase_length: 0, no window is being
    #     evaluated yet
    # The callers add the rest of the flexibility fields when they
    # evaluate a window.
    stretch_control <- function(i_end_control) {
      list(
        indexes_local = list(
          i_end_control = i_end_control,
          i_flex        = 1
        ),
        flexibility   = list(commitment_phase_length = 0)
      )
    }

    # Leaves the first row of a stretch out of any flexibility window.
    neutralize_first_row <- function(stretch) {
      stretch$system$Elec_flex_down_plan[1] <- 0
      stretch$system$Elec_flex_up_plan[1]   <- 0
      return(stretch)
    }

    # Gives the control that is missing (NA) in the rows asked, in the
    # three itineraries of every asset, the default of the asset. Those
    # rows belong to rows no market has planned yet.
    fill_missing_control <- function(stretch, rows) {
      for (CONT_001 in names(parameters$assets)) {
        asset <- parameters$assets[[CONT_001]]

        # model_type_contract is called to take the operations of the
        # type of model of the asset.
        model <- model_type_contract(asset$asset_type)

        # piece_asset_view is called to take the table the operations
        # of the asset work on: the system and the asset joined.
        view <- piece_asset_view(
          piece        = stretch,
          asset_id     = CONT_001,
          column_order = column_order
        )

        # The operation default_control of the model
        # (lowest_mode_setpoints() for a building) is called to obtain
        # the control of the lowest-numbered mode.
        defaults <- model$default_control(parameters, asset)
        for (CONT_002 in contexts) {
          for (CONT_003 in names(defaults)) {
            column     <- paste0(CONT_003, "_", CONT_002)
            needs_fill <- rows[is.na(view[[column]][rows])]
            view[[column]][needs_fill] <- defaults[[CONT_003]]
          }
        }

        # piece_absorb_asset is called to take the control of the
        # asset back into its table.
        stretch <- piece_absorb_asset(
          piece    = stretch,
          asset_id = CONT_001,
          view     = view
        )
        rm(list = intersect(c("asset", "model", "view", "defaults",
                              "CONT_002", "CONT_003", "column",
                              "needs_fill"), ls()))
      }
      return(stretch)
    }

    # Simulates the plan of every asset over a stretch of the piece,
    # with the control it already carries. The assets that read the
    # net electricity of the rest of the system are simulated after
    # the others, over the electricity of the plan of the assets
    # simulated before them.
    simulate_plan <- function(stretch) {
      # asset_simulation_order is called to order the assets: those
      # that read the net electricity of the rest of the system are
      # simulated after the others.
      simulation_order <- asset_simulation_order(parameters)
      simulated        <- character(0)

      for (CONT_004 in simulation_order) {
        asset <- parameters$assets[[CONT_004]]

        # model_type_contract is called to take the operations of the
        # type of model of the asset.
        model <- model_type_contract(asset$asset_type)

        # piece_asset_view is called to take the view of the asset.
        view <- piece_asset_view(
          piece        = stretch,
          asset_id     = CONT_004,
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
            assets    = stretch$assets,
            asset_ids = simulated,
            itinerary = "plan",
            rows      = seq_len(nrow(view))
          )
        }

        # The operation simulate_itinerary of the model
        # (period_calculation() for a building) is called to simulate
        # the asset under the control already present in its table.
        view <- model$simulate_itinerary(
          period_chunk        = view,
          asset               = asset,
          calculation_mode    = 1,
          calculation_context = "plan"
        )

        # piece_absorb_asset is called to take the simulated asset
        # back into its table.
        stretch <- piece_absorb_asset(
          piece    = stretch,
          asset_id = CONT_004,
          view     = view
        )
        simulated <- c(simulated, CONT_004)
        rm(list = c("asset", "model", "view"))
      }
      rm(list = c("CONT_004", "simulation_order", "simulated"))
      return(stretch)
    }
  }

  # -------------------------------------------------------------
  # 2. Initial state at i0
  # -------------------------------------------------------------
  # Control missing over the initialization stretch belongs to rows
  # no market has planned yet, so it takes the default of each asset
  # (for a building, the setpoints of the lowest-numbered mode). Each
  # asset then starts its plan from its state at i0, through the
  # operation plan_start_state of its type of model: for a building,
  # the heat pump powers of the previous step are 0.
  # -------------------------------------------------------------
  {
    # fill_missing_control is called to give the rows from i0 to
    # i_begin_horizon the default control where none was given.
    piece <- fill_missing_control(
      stretch = piece,
      rows    = seq_len(row_index$i_begin_horizon)
    )

    for (CONT_005 in names(parameters$assets)) {
      asset <- parameters$assets[[CONT_005]]

      # model_type_contract is called to take the operations of the
      # type of model of the asset.
      model <- model_type_contract(asset$asset_type)

      # piece_asset_view is called to take the view of the asset.
      view <- piece_asset_view(
        piece        = piece,
        asset_id     = CONT_005,
        column_order = column_order
      )

      # The operation plan_start_state of the model
      # (building_plan_start_state() for a building) is called to
      # start the three itineraries of the asset from its state at i0.
      view <- model$plan_start_state(
        period_chunk = view,
        asset        = asset
      )

      # piece_absorb_asset is called to take the state of the asset
      # back into its table.
      piece <- piece_absorb_asset(
        piece    = piece,
        asset_id = CONT_005,
        view     = view
      )
      rm(list = c("asset", "model", "view"))
    }
    rm(list = "CONT_005")
  }

  # -------------------------------------------------------------
  # 3. Initialization stretch
  # -------------------------------------------------------------
  # A window whose Commitment Phase starts in this stretch may run its
  # Neutral and Recovery Phases into the optimization horizon. The
  # stretch is then extended to the end of the last of those Recovery
  # Phases, so that the window is projected whole, over the plan the
  # earlier markets left there. The optimization continues its tail
  # and starts no window of the same leg on it.
  # -------------------------------------------------------------
  {
    pre_horizon_tail <- list()

    if (row_index$i_begin_horizon > 1) {
      # pre_horizon_window_tails is called to find where the windows
      # that start in this stretch end, for each leg. It reads the
      # commitments, which the table of the system holds.
      tails    <- pre_horizon_window_tails(piece$system,
                                           row_index$i_begin_horizon,
                                           parameters)
      init_end <- min(max(row_index$i_begin_horizon, tails$down, tails$up),
                      row_index$i_end_horizon)

      # piece_rows is called to cut the piece to the stretch.
      init_piece <- neutralize_first_row(piece_rows(
        piece = piece,
        rows  = seq_len(init_end)
      ))

      # Past i_begin_horizon the plan may carry no control (a market
      # that trades energy decides it). There it takes the default
      # control of each asset, as the stretch before i_begin_horizon
      # does.
      if (init_end > row_index$i_begin_horizon) {
        # fill_missing_control is called to give the rows past
        # i_begin_horizon the default control where none was given.
        init_piece <- fill_missing_control(
          stretch = init_piece,
          rows    = (row_index$i_begin_horizon + 1):init_end
        )
      }

      init_control <- stretch_control(init_end)
      init_control$flexibility$restatement_mode <- "projection"

      # simulate_plan is called to fly the plan of every asset over
      # the stretch with the control it already carries.
      init_piece <- simulate_plan(stretch = init_piece)
      committed_system <- init_piece$system

      # derive_flex_itineraries is called to project both flexibility
      # itineraries over the plan just flown. No market trades this
      # stretch any more: the windows that fall in it are drawn as the
      # new plan allows, without judging them, and no commitment is
      # changed.
      init_piece <- derive_flex_itineraries(
        piece              = init_piece,
        parameters         = parameters,
        simulation_control = init_control
      )$piece

      # itinerary_columns is called to name the columns of the three
      # itineraries, whose state at i_begin_horizon, the initial
      # condition of the optimization, goes into the piece.
      state_columns <- unlist(lapply(contexts, function(CONT_006) {
        itinerary_columns(CONT_006, parameters)
      }))

      # piece_write_rows is called to write those columns into the
      # table that holds each one.
      piece <- piece_write_rows(
        piece       = piece,
        rows        = row_index$i_begin_horizon,
        source      = init_piece,
        source_rows = row_index$i_begin_horizon,
        columns     = state_columns
      )

      # hand_over_window_tail is called for each leg whose window runs
      # into the horizon, so that the optimization continues it over the
      # plan of each candidate.
      for (CONT_007 in c("down", "up")) {
        if (tails[[CONT_007]] > row_index$i_begin_horizon) {
          pre_horizon_tail[[CONT_007]] <- hand_over_window_tail(
            stretch_piece    = init_piece,
            committed_system = committed_system,
            i_begin_horizon  = row_index$i_begin_horizon,
            tail_end         = min(tails[[CONT_007]], init_end),
            leg              = CONT_007,
            parameters       = parameters)
        }
      }

      rm(list = c("init_piece", "committed_system", "init_control",
                  "state_columns", "tails", "init_end", "CONT_007"))
    }
  }

  # -------------------------------------------------------------
  # 4. Optimization
  # -------------------------------------------------------------
  {
    horizon_rows      <- row_index$i_begin_horizon:row_index$i_end_horizon
    ctrl_end_in_chunk <- row_index$i_end_control - row_index$i_begin_horizon + 1

    # piece_rows is called to cut the piece to the optimization
    # horizon, which starts at i_begin_horizon, the initial condition
    # of the optimization.
    optimization_piece   <- neutralize_first_row(piece_rows(
      piece = piece,
      rows  = horizon_rows
    ))
    optimization_control <- stretch_control(ctrl_end_in_chunk)
    optimization_control$flexibility$pre_horizon_tail <- pre_horizon_tail

    # The aim travels with the control metadata, which evaluate_control()
    # reads. parameters is only read.
    optimization_control$evaluation <- list(optimization_aim = aim)

    # The first row is the initial condition: its time step belongs
    # to the interval before the horizon, which this market does not
    # decide.
    timestamps <- list(
      target_periods = sort(unique(optimization_piece$system$MarketUTC[-1]))
    )

    # piece_working_columns is called to add to the table of the system
    # the working columns the evaluations of the market write.
    optimization_piece <- piece_working_columns(piece = optimization_piece)

    # committed_recovery_cost is called to value, once per market, the
    # Recovery Phase of the itineraries already committed. Every
    # candidate's Recovery Phase is valued as the change against it.
    # It hands back too the derivation of the committed flexibility
    # over the committed plan, which the "operation" and
    # "operationflex" aims take instead of drawing it again over the
    # same plan.
    committed <- committed_recovery_cost(
      piece              = optimization_piece,
      parameters         = parameters,
      simulation_control = optimization_control,
      marginal_context   = marginal_context
    )
    marginal_context     <- committed$marginal_context
    committed_derivation <- committed$derivation
    rm(list = "committed")

    # fill_missing_control is called to give the rows of the horizon
    # that carry no control (NA) the default control of each asset: the
    # "operation" and "operationflex" aims simulate the plan with the
    # control it holds, and the other aims replace it on the rows they
    # decide.
    optimization_piece <- fill_missing_control(
      stretch = optimization_piece,
      rows    = seq_len(nrow(optimization_piece$system))
    )

    if (aim %in% c("energy", "flexibility")) {
      # optimize_control_step is called to search the controls of the
      # horizon with the genetic algorithm.
      optimization_piece <- optimize_control_step(
        piece              = optimization_piece,
        timestamps         = timestamps,
        parameters         = parameters,
        simulation_control = optimization_control,
        marginal_context   = marginal_context,
        worker_cluster     = worker_cluster
      )$piece
    } else if (aim == "operation") {
      # simulate_plan is called to simulate the plan as it is, since
      # this aim optimizes nothing.
      optimization_piece <- simulate_plan(stretch = optimization_piece)

      # derive_flex_itineraries is called to rebuild the itineraries of
      # the commitments already held over the plan just recomputed. The
      # guard zone is the only flexibility this aim trades: the part of
      # a commitment the new plan no longer holds is given back.
      # When the plan just recomputed and the control are identical
      # to those committed_recovery_cost() drew the committed
      # flexibility over, the derivation is the one it handed back.
      if (identical(committed_derivation$piece, optimization_piece) &&
          identical(committed_derivation$simulation_control,
                    optimization_control)) {
        derived <- committed_derivation$derived
      } else {
        # build_recovery_valuation is called first to resolve what the
        # derivation needs to choose how an asset draws the Recovery
        # Phase of the windows it restates: it is NULL when no asset
        # offers alternatives.
        recovery_valuation <- build_recovery_valuation(
          piece            = optimization_piece,
          parameters       = parameters,
          marginal_context = marginal_context
        )

        # derive_flex_itineraries is called to draw the itineraries of
        # the commitments already held over the plan.
        derived <- derive_flex_itineraries(
          piece              = optimization_piece,
          parameters         = parameters,
          simulation_control = optimization_control,
          recovery_valuation = recovery_valuation
        )
        rm(list = "recovery_valuation")
      }
      optimization_piece <- derived$piece
      optimization_piece$system$Standing_commitment_held_legs_plan <-
        nrow(derived$held)
      rm(list = "derived")
    } else {
      # evaluate_control is called to simulate the plan as it is and
      # search flexibility over it, without optimizing the plan. The
      # derivation of the committed flexibility is handed over, so
      # that it is not drawn again over the same plan.
      optimization_piece <- evaluate_control(
        piece              = optimization_piece,
        parameters         = parameters,
        simulation_control = optimization_control,
        marginal_context   = marginal_context,
        derivation         = committed_derivation
      )$piece
    }

    # A window of the guard zone that an asset cannot rebuild over the
    # plan of this market, because it would raise both thermal systems
    # or the plan leaves it no room, is held within the limits of the
    # equipment of the asset and reported, because the plan cannot
    # deliver it as it was sold.
    if (any(optimization_piece$system$Standing_commitment_held_legs_plan > 0L,
            na.rm = TRUE)) {
      warning("A flexibility commitment of the market interval cannot be rebuilt ",
              "over the plan: it is held within the limits of the equipment, ",
              "and the part that does not fit is bought back.",
              call. = FALSE)
    }
  }

  # -------------------------------------------------------------
  # 5. Injection
  # -------------------------------------------------------------
  # Only the control horizon is written. Rows of the piece past
  # i_end_control keep their input values. Every aim writes the plan it
  # ends up with: the control of the operational aims is the one they
  # were given, and their plan is that one simulated with the latest
  # forecast, so the flexibility they restate or sell is measured
  # against the plan written.
  # -------------------------------------------------------------
  {
    # itinerary_columns is called to name the columns of the plan and
    # of the two flexibility itineraries; the commitments of the two
    # legs are written with them. The phase codes are the optimizer's
    # own labels, scratch state of the search, and are not written
    # back.
    inject_columns <- c(itinerary_columns("plan", parameters),
                        itinerary_columns("plan_flex_down", parameters),
                        itinerary_columns("plan_flex_up", parameters),
                        "Elec_flex_down_plan", "Elec_flex_up_plan")

    # piece_write_rows is called to write the plan, the itineraries
    # and the commitments over the control rows, each into the table
    # that holds it.
    piece <- piece_write_rows(
      piece       = piece,
      rows        = row_index$i_begin_horizon:row_index$i_end_control,
      source      = optimization_piece,
      source_rows = seq_len(ctrl_end_in_chunk),
      columns     = inject_columns
    )

    rm(list = c("inject_columns", "optimization_piece", "optimization_control",
                "horizon_rows", "ctrl_end_in_chunk", "timestamps",
                "pre_horizon_tail", "committed_derivation"))
  }

  rm(list = c("aim", "contexts", "column_order", "stretch_control",
              "neutralize_first_row", "fill_missing_control", "simulate_plan"))

  return(piece)
}
