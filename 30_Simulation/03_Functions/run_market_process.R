# -------------------------------------------------------------
# Function: run_market_process.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Executes one market optimization process (Scheduling or
# Piloting) over a sliced simulation period. The market works on a
# piece (build_market_piece()): the table of the system and one table
# per asset. Each asset starts its plan from the state it has
# actually reached at i0, its executed state, and the plan is then
# simulated with the forecast of this market, asset by asset, on the
# view of each one (piece_asset_view()). Between i0 and
# i_begin_horizon the plan is simulated as it stands, and
# both flexibility itineraries are projected over it: the windows
# committed from i0 onwards are drawn as the new plan allows, without
# judging them and without changing any commitment. When a window
# whose Commitment Phase starts there runs into the optimization
# horizon, that period is extended to the end of its Recovery Phase,
# and what the optimization needs to continue the tail is handed over
# in simulation_control$flexibility$pre_horizon_tail (the rows and the
# phases of the tail, and the state and the system of every asset):
# the optimization continues it over the plan of each candidate and
# starts no window of the same leg on it.
# Every function this process calls works on the piece: the
# valuation of the committed recovery, the projection and the
# derivation of the itineraries, the hand-over of the tail, the
# reward, the optimization and the evaluation of a candidate. The
# plan of each asset is simulated in its view, the assets that read
# the net electricity of the rest of the system (operation
# reads_rest_net of their type of model) after the others
# (asset_simulation_order()), with the electricity of the plan of
# those in their view (write_rest_net()).
# The aim of the market is read from the market parameters and travels
# down the call chain with the control metadata and as an argument:
# parameters is only read during the simulation.
# Whatever the aim, the optimization keeps the commitments of the
# market interval inside the commitment margin: the part the new plan
# no longer holds is given back (see derive_flex_itineraries()). That
# is the only flexibility a market with the "operation" aim trades.
# When an asset offers alternatives for the Recovery Phase of a window
# (a battery), the windows it restates are drawn with the one that has
# the best reward (build_recovery_valuation()).
# The valuation of the committed recovery draws the committed
# flexibility over the committed plan. The "operation" and
# "operationflex" aims keep that plan, so they take that derivation
# when the plan they simulate and their control are identical to the
# ones it was drawn with, instead of drawing it a second time.
# -------------------------------------------------------------
# Inputs
# prefix             : Character. "Sched" or "Pilot".
# row_index          : Integer. Current simulation row index.
# piece              : List. The period to process, as
#                      build_market_piece() returns it: the rows of
#                      Main_df as the table of the system, and the
#                      rows of the table of each asset.
# market_parameters  : List. Market fields for the current row.
# simulation_control : List. Control metadata (indexes, evaluation,
#                      flexibility, calculation_mode).
# timestamps         : List. Timestamp metadata for the piece.
# parameters         : List. Simulation parameters. Its asset registry
#                      (parameters$assets) gives the type of model of
#                      each asset, whose operations simulate it
#                      (model_type_contract()), and joined_cols the
#                      columns of the view of an asset.
# marginal_context   : Named list or NULL (default NULL). As returned
#                      by resolve_marginal_context(), computed by
#                      run_market_role() from Main_df before this market's
#                      optimization. Passed through to
#                      optimize_control_step() (for "energy"/
#                      "flexibility" aims) and evaluate_control() (for
#                      "operationflex"); unused for "operation".
# worker_cluster     : Cluster of worker processes of the simulation
#                      (start_worker_cluster()) when parallel = 1, NULL
#                      otherwise. Passed through to
#                      optimize_control_step().
# market_name_width  : Integer. Width the name of the market is padded
#                      to in the console line of the market, the
#                      width of the longest market name.
# Callers must guard the call with is_market_active() on the
# relevant *_Market_Name field; this function assumes the market is
# active and does not re-check it.
# -------------------------------------------------------------
# Outputs
# List. The piece with the plan, the flexibility itineraries and the
# commitments injected over the control horizon, and Reward over the
# optimization horizon.
# -------------------------------------------------------------
# Usage instructions
# run_market_process(prefix, row_index, piece, ...)
# -------------------------------------------------------------
# Code outline
# 0. Error management
# 1. Ranges of the market
# 2. Aim of the market
# 3. Start of the plan
# 4. Initialization period
#    4.1. Subset
#    4.2. Fill the setpoints
#    4.3. Simulation
#    4.4. Injection
#    4.5. Windows that run into the horizon
# 5. Optimization
#    5.1. Subset, missing control and committed recovery
#    5.2. Optimization
#    5.3. Injection
# -------------------------------------------------------------

run_market_process <- function(prefix,
                               row_index,
                               piece,
                               market_parameters,
                               simulation_control,
                               timestamps,
                               parameters,
                               marginal_context = NULL,
                               worker_cluster,
                               market_name_width) {

  # -------------------------------------------------------------
  # 0. Error management
  # The ranges of the market shall be ordered.
  # -------------------------------------------------------------
  {
    if (simulation_control$indexes_local$i0 > simulation_control$indexes_local$i_begin_horizon) {
      stop("Invalid market range at row ", row_index,
           ": i0 > i_begin_horizon for ", prefix)
    }
    if (simulation_control$indexes_local$i_begin_horizon > simulation_control$indexes_local$i_end_horizon) {
      stop("Invalid market range at row ", row_index,
           ": i_begin_horizon > i_end_horizon for ", prefix)
    }
  }

  # -------------------------------------------------------------
  # 1. Ranges of the market
  # The names of the market columns of this role, and the order of
  # the columns of the view of an asset.
  # -------------------------------------------------------------
  {
    market_name_col   <- paste0(prefix, "_Market_Name")
    bid_time_col      <- paste0(prefix, "_Market_Bid_time")
    period_begin_col  <- paste0(prefix, "_Market_Period_Begin")
    period_end_col    <- paste0(prefix, "_Market_Period_End")
    market_aim_col    <- paste0(prefix, "_Market_Aim")
    column_order      <- parameters$joined_cols
  }

  # -------------------------------------------------------------
  # 2. Aim of the market
  # The aim of the market, in its internal name.
  # -------------------------------------------------------------
  {
    # map_optimization_aim is called to translate this market's raw aim
    # code (market_parameters[[market_aim_col]]) into the internal aim
    # label that drives which optimization branch runs below.
    optimization_aim <- map_optimization_aim(
      aim_raw      = market_parameters[[market_aim_col]],
      column_name  = market_aim_col,
      row_index    = row_index
    )

    # The aim travels with the control metadata of this market, which
    # evaluate_control() reads, and as an argument to reward_function().
    # parameters is only read.
    simulation_control$evaluation$optimization_aim <- optimization_aim
  }

  # -------------------------------------------------------------
  # 3. Start of the plan
  # Row 1 of the piece is i0, the row the market clears on. The
  # execution step of the row before has already written the state
  # each asset actually reached there, under the real weather. The
  # plan of this market starts from that state and not from the one
  # an earlier market planned for i0, so the forecast errors those
  # markets made do not carry over: from i0 on, the plan only follows
  # the forecast of this market. The flexibility itineraries are
  # copies of the plan, so they start from the same state. Each asset
  # does it on its own view, through its type of model.
  # -------------------------------------------------------------
  {
    for (CONT_001 in names(parameters$assets)) {
      # Every operation of the type of model of the asset receives its
      # parameters, its entry of parameters$assets.
      asset <- parameters$assets[[CONT_001]]

      # model_type_contract is called to take the operations of the
      # type of model of the asset.
      model <- model_type_contract(asset$asset_type)

      # piece_asset_view is called to take the table the operations of
      # the asset work on: the system and the asset joined.
      view <- piece_asset_view(
        piece        = piece,
        asset_id     = CONT_001,
        column_order = column_order
      )

      # The operation plan_start_state of the model
      # (building_plan_start_state() for a building) is called to start
      # the plan of the asset from its executed state.
      view <- model$plan_start_state(
        period_chunk = view,
        asset        = asset
      )

      # piece_absorb_asset is called to take the plan of the asset back
      # into its table.
      piece <- piece_absorb_asset(
        piece    = piece,
        asset_id = CONT_001,
        view     = view
      )
      rm(list = c("asset", "model", "view"))
    }
    rm(list = "CONT_001")
  }

  # -------------------------------------------------------------
  # 4. Initialization period
  # The plan is simulated from i0, from the executed state of
  # block 3, with the forecast of this market.
  # A window whose Commitment Phase starts in this period may run its
  # Neutral and Recovery Phases into the optimization horizon. The
  # period is then extended to the end of the last of those Recovery
  # Phases, so that the window is projected whole, over the plan the
  # earlier markets left there. The optimization continues its tail
  # and starts no window of the same leg on it.
  # 4.1. Subset
  # 4.2. Fill the setpoints
  # 4.3. Simulation
  # 4.4. Injection
  # 4.5. Windows that run into the horizon
  # -------------------------------------------------------------
  {
    pre_horizon_tail <- list()

    if (simulation_control$indexes_local$i0 < simulation_control$indexes_local$i_begin_horizon) {

      # ---------------------------------------------------------
      # 4.1. Subset
      # The rows from i0 to the end of the initialization period, in
      # every table of the piece.
      # ---------------------------------------------------------
      {
        i_begin_horizon <- simulation_control$indexes_local$i_begin_horizon

        # pre_horizon_window_tails is called to find where the windows
        # that start in this period end, for each leg. It reads the
        # commitments, which the table of the system holds.
        tails    <- pre_horizon_window_tails(piece$system, i_begin_horizon, parameters)
        init_end <- min(max(i_begin_horizon, tails$down, tails$up),
                        simulation_control$indexes_local$i_end_horizon)

        # piece_rows is called to cut the piece to the initialization
        # period.
        init_piece <- piece_rows(
          piece = piece,
          rows  = seq_len(init_end)
        )
      }

      # ---------------------------------------------------------
      # 4.2. Fill the setpoints that no market has determined
      # A control that is missing (NA) belongs to a row no market has
      # planned yet: the control columns start at NA. Such a row
      # takes the default control of its asset (for a building, the
      # setpoints of the lowest-numbered mode). A setpoint of 0 degC
      # is a valid setpoint and is kept.
      # ---------------------------------------------------------
      {
        for (CONT_002 in names(parameters$assets)) {
          asset <- parameters$assets[[CONT_002]]

          # model_type_contract is called to take the operations of the
          # type of model of the asset.
          model <- model_type_contract(asset$asset_type)

          # piece_asset_view is called to take the view of the asset.
          view <- piece_asset_view(
            piece        = init_piece,
            asset_id     = CONT_002,
            column_order = column_order
          )

          # The operation default_control of the model
          # (lowest_mode_setpoints() for a building) is called to obtain
          # the setpoints of the lowest-numbered mode.
          fill <- model$default_control(parameters, asset)
          for (CONT_004 in names(fill)) {
            fill_col <- paste0(CONT_004, "_plan")
            if (fill_col %in% colnames(view)) {
              needs_fill <- is.na(view[[fill_col]])
              view[[fill_col]][needs_fill] <- fill[[CONT_004]]
              rm(list = "needs_fill")
            }
          }

          # piece_absorb_asset is called to take the setpoints of the
          # asset back into its table.
          init_piece <- piece_absorb_asset(
            piece    = init_piece,
            asset_id = CONT_002,
            view     = view
          )
          rm(list = intersect(c("asset", "model", "view", "fill",
                                "fill_col", "CONT_004"), ls()))
        }
        rm(list = "CONT_002")
      }

      # ---------------------------------------------------------
      # 4.3. Simulation
      # Each asset runs the setpoints of the period through its own
      # physics, with the forecast of this market, so init_piece
      # holds the states and the comfort of the plan before any of it
      # is injected back into piece below. The assets that read the
      # net electricity of the rest of the system run after the
      # others.
      # ---------------------------------------------------------
      {
        # asset_simulation_order is called to order the assets: those
        # that read the net electricity of the rest of the system are
        # simulated after the others.
        simulation_order <- asset_simulation_order(parameters)
        simulated        <- character(0)

        for (CONT_005 in simulation_order) {
          asset <- parameters$assets[[CONT_005]]

          # model_type_contract is called to take the operations of the
          # type of model of the asset.
          model <- model_type_contract(asset$asset_type)

          # piece_asset_view is called to take the view of the asset.
          view <- piece_asset_view(
            piece        = init_piece,
            asset_id     = CONT_005,
            column_order = column_order
          )

          # The operation reads_rest_net of the model says whether the
          # asset works over the net electricity of the rest of the
          # system. If it does, write_rest_net is called to write in
          # its view the electricity of the plan of the assets
          # simulated before it.
          if (model$reads_rest_net(asset)) {
            view <- write_rest_net(
              view      = view,
              assets    = init_piece$assets,
              asset_ids = simulated,
              itinerary = "plan",
              rows      = seq_len(nrow(view))
            )
          }

          # The operation execute_step of the model
          # (implement_control_step() for a building) is called to run
          # the setpoints through the physics of the asset.
          view <- model$execute_step(
            period_chunk        = view,
            simulation_control  = simulation_control,
            timestamps          = timestamps,
            parameters          = parameters,
            asset               = asset,
            calculation_context = "plan"
          )

          # piece_absorb_asset is called to take the simulated asset
          # back into its table.
          init_piece <- piece_absorb_asset(
            piece    = init_piece,
            asset_id = CONT_005,
            view     = view
          )
          simulated <- c(simulated, CONT_005)
          rm(list = c("asset", "model", "view"))
        }
        rm(list = c("CONT_005", "simulation_order", "simulated"))
      }

      # ---------------------------------------------------------
      # 4.4. Injection
      # The plan of the row i_begin_horizon, the initial condition of
      # the optimization, goes into the piece.
      # ---------------------------------------------------------
      {
        # itinerary_columns is called to name the columns of the plan,
        # the itinerary this injection writes.
        plan_cols <- itinerary_columns("plan", parameters)

        # piece_write_rows is called to write those columns into the
        # table that holds each one.
        piece <- piece_write_rows(
          piece       = piece,
          rows        = i_begin_horizon,
          source      = init_piece,
          source_rows = i_begin_horizon,
          columns     = plan_cols
        )
      }

      # ---------------------------------------------------------
      # 4.5. Windows that run into the horizon
      # The flexibility itineraries are projected over the plan just
      # simulated. No market trades this period any more: the windows
      # that fall in it are drawn as the new plan allows, without
      # judging them, and no commitment is changed. For each leg whose
      # window runs into the horizon, what the optimization needs to
      # continue its tail is handed over.
      # ---------------------------------------------------------
      {
        if (init_end > i_begin_horizon) {
          init_control <- simulation_control
          init_control$indexes_local$i_end_control    <- init_end
          init_control$indexes_local$i_flex           <- 1
          init_control$flexibility$restatement_mode   <- "projection"

          # derive_flex_itineraries is called to project both
          # flexibility itineraries over the plan of this period, so the
          # windows that start in it are drawn whole.
          init_piece <- derive_flex_itineraries(
            piece              = init_piece,
            parameters         = parameters,
            simulation_control = init_control
          )$piece

          # hand_over_window_tail is called for each leg whose window
          # runs into the horizon, so that the optimization continues it
          # over the plan of each candidate. The period as projected is
          # init_piece, and the commitments as they stand are those of
          # the table of the system of the piece, on the same rows.
          for (CONT_006 in c("down", "up")) {
            if (tails[[CONT_006]] > i_begin_horizon) {
              pre_horizon_tail[[CONT_006]] <- hand_over_window_tail(
                stretch_piece    = init_piece,
                committed_system = piece_rows(
                  piece = piece,
                  rows  = seq_len(init_end)
                )$system,
                i_begin_horizon  = i_begin_horizon,
                tail_end         = min(tails[[CONT_006]], init_end),
                leg              = CONT_006,
                parameters       = parameters)
            }
          }
          rm(list = c("init_control", "CONT_006"))
        }
      }

      rm(list = c("init_piece", "plan_cols", "tails", "init_end",
                  "i_begin_horizon"))
    }

    simulation_control$flexibility$pre_horizon_tail <- pre_horizon_tail
    rm(list = "pre_horizon_tail")
  }

  # -------------------------------------------------------------
  # 5. Optimization
  # The market optimizes the plan over its optimization horizon, or
  # simulates the plan it was given when its aim is operation, and
  # injects the result over its control horizon.
  # 5.1. Subset, missing control and committed recovery
  # 5.2. Optimization
  # 5.3. Injection
  # -------------------------------------------------------------
  {
    # ---------------------------------------------------------
    # 5.1. Subset, missing control and committed recovery
    # ---------------------------------------------------------
    {
      # The piece starts at i_begin_horizon, the initial condition of
      # the optimization, and runs over the rows of idx_horizon, whose
      # time steps make up the optimization horizon.
      # piece_rows is called to cut it.
      optimization_piece <- piece_rows(
        piece = piece,
        rows  = simulation_control$indexes_local$i_begin_horizon:
          simulation_control$indexes_local$i_end_horizon
      )

      # A row of the horizon that no market has planned yet has no
      # control (NA). It takes the default control of its asset (for a
      # building, the setpoints of the lowest-numbered mode), as the
      # rows of the initialization period do: the "operation" and
      # "operationflex" aims simulate the plan with the control it
      # holds, and the other aims replace it on the rows they decide.
      for (CONT_008 in names(parameters$assets)) {
        asset <- parameters$assets[[CONT_008]]

        # model_type_contract is called to take the operations of the
        # type of model of the asset.
        model <- model_type_contract(asset$asset_type)

        # piece_asset_view is called to take the view of the asset.
        view <- piece_asset_view(
          piece        = optimization_piece,
          asset_id     = CONT_008,
          column_order = column_order
        )

        # The operation default_control of the model
        # (lowest_mode_setpoints() for a building) is called to obtain
        # the control of the rows that no market has determined.
        fill <- model$default_control(parameters, asset)
        for (CONT_009 in names(fill)) {
          fill_col <- paste0(CONT_009, "_plan")
          if (fill_col %in% colnames(view)) {
            needs_fill <- is.na(view[[fill_col]])
            view[[fill_col]][needs_fill] <- fill[[CONT_009]]
            rm(list = "needs_fill")
          }
        }

        # piece_absorb_asset is called to take the control of the
        # asset back into its table.
        optimization_piece <- piece_absorb_asset(
          piece    = optimization_piece,
          asset_id = CONT_008,
          view     = view
        )
        rm(list = intersect(c("asset", "model", "view", "fill",
                              "fill_col", "CONT_009"), ls()))
      }
      rm(list = "CONT_008")

      # The optimization works on a piece that starts at i_begin_horizon,
      # so the control horizon is handed to it as a row of that piece.
      # system_flex_window() reads it that way;
      # counted from i0, it would let a window reach past the period this
      # market commits.
      optimization_control <- simulation_control
      optimization_control$indexes_local$i_end_control <-
        simulation_control$indexes_local$i_end_control -
        simulation_control$indexes_local$i_begin_horizon + 1

      # The first row is the initial condition: its time step belongs
      # to the interval before the horizon, which this market does not
      # decide.
      timestamps$target_periods <- sort(unique(optimization_piece$system$MarketUTC[-1]))

      # committed_recovery_cost is called to value, once per market,
      # the Recovery Phase of the itineraries already committed. Every
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
    }

    # ---------------------------------------------------------
    # 5.2. Optimization
    # ---------------------------------------------------------
    {

      if (optimization_aim %in% c("energy", "flexibility")) {
        # optimize_control_step is called to run the GA-based search for
        # the setpoints/modes that maximise the reward over this
        # horizon. The "energy" aim values energy only, and the
        # "flexibility" aim additionally values explicit-flexibility
        # revenue in its reward; the search itself is the same.
        optimization_piece <- optimize_control_step(
          piece              = optimization_piece,
          timestamps         = timestamps,
          parameters         = parameters,
          simulation_control = optimization_control,
          marginal_context   = marginal_context,
          worker_cluster     = worker_cluster
        )$piece
      } else if (optimization_aim == "operation") {
        # The operation simulate_itinerary of each asset's model
        # (period_calculation() for a building) is called directly (no
        # GA search) to simulate the asset under the setpoints
        # already present in its table, since "operation" only
        # evaluates operation as scheduled, without optimizing it.
        #
        # asset_simulation_order is called to order the assets: those
        # that read the net electricity of the rest of the system are
        # simulated after the others.
        simulation_order <- asset_simulation_order(parameters)
        simulated        <- character(0)

        for (CONT_007 in simulation_order) {
          asset <- parameters$assets[[CONT_007]]

          # model_type_contract is called to take the operations of the
          # type of model of the asset.
          model <- model_type_contract(asset$asset_type)

          # piece_asset_view is called to take the view of the asset.
          view <- piece_asset_view(
            piece        = optimization_piece,
            asset_id     = CONT_007,
            column_order = column_order
          )

          # The operation reads_rest_net of the model says whether the
          # asset works over the net electricity of the rest of the
          # system. If it does, write_rest_net is called to write in
          # its view the electricity of the plan of the assets
          # simulated before it.
          if (model$reads_rest_net(asset)) {
            view <- write_rest_net(
              view      = view,
              assets    = optimization_piece$assets,
              asset_ids = simulated,
              itinerary = "plan",
              rows      = seq_len(nrow(view))
            )
          }
          view <- model$simulate_itinerary(
            period_chunk        = view,
            asset               = asset,
            calculation_mode    = 1,
            calculation_context = "plan"
          )

          # piece_absorb_asset is called to take the simulated asset
          # back into its table.
          optimization_piece <- piece_absorb_asset(
            piece    = optimization_piece,
            asset_id = CONT_007,
            view     = view
          )
          simulated <- c(simulated, CONT_007)
          rm(list = c("asset", "model", "view"))
        }
        rm(list = c("CONT_007", "simulation_order", "simulated"))

        # derive_flex_itineraries is called next because recomputing the
        # plan and leaving the two flexibility itineraries as they were
        # produces an incoherent pair: itineraries that belong to the
        # PREVIOUS plan, written back to Main_df beside the new one.
        # This aim optimizes nothing, so the derivation only holds what
        # is already committed over the plan it has just recomputed.
        # The guard zone is the only flexibility this aim trades: the
        # part of a commitment the new plan no longer holds is given
        # back.
        # When the plan just recomputed and the control are identical
        # to those committed_recovery_cost() drew the committed
        # flexibility over, the derivation is the one it handed back.
        if (identical(committed_derivation$piece, optimization_piece) &&
            identical(committed_derivation$simulation_control,
                      optimization_control)) {
          derived <- committed_derivation$derived
        } else {
          # build_recovery_valuation is called to resolve what the
          # derivation needs to choose how an asset draws the Recovery
          # Phase of the windows it restates: it is NULL when no asset
          # offers alternatives.
          recovery_valuation <- build_recovery_valuation(
            piece            = optimization_piece,
            parameters       = parameters,
            marginal_context = marginal_context
          )

          # derive_flex_itineraries is called to draw the itineraries
          # of the commitments already held over the plan.
          derived <- derive_flex_itineraries(
            piece              = optimization_piece,
            parameters         = parameters,
            simulation_control = optimization_control,
            recovery_valuation = recovery_valuation
          )
          rm(list = "recovery_valuation")
        }
        optimization_piece <- derived$piece
        optimization_piece$system$Standing_commitment_held_legs_plan <- nrow(derived$held)
        rm(list = "derived")

        # reward_function is called so that a market with this aim
        # reports a reward like any other. It decides nothing with it -
        # there is no search to steer - but a market that evaluates the
        # three itineraries and says nothing about them is a market
        # whose behaviour cannot be read afterwards.
        optimization_piece <- reward_function(
          piece              = optimization_piece,
          parameters         = parameters,
          optimization_aim   = optimization_aim,
          marginal_context   = marginal_context
        )
      } else  if (optimization_aim == "operationflex") {
        # evaluate_control is called directly (no GA search) to simulate
        # both the plan and the best flexibility scenario for the
        # already-scheduled setpoints, since "operationflex" evaluates
        # flexibility without optimizing the underlying schedule. The
        # derivation of the committed flexibility is handed over, so
        # that it is not drawn again over the same plan.
        optimization_piece <- evaluate_control(
          piece              = optimization_piece,
          parameters         = parameters,
          simulation_control = optimization_control,
          marginal_context   = marginal_context,
          derivation         = committed_derivation
        )$piece
      } else {
        stop("Invalid optimization aim: ", optimization_aim)
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

    # ---------------------------------------------------------
    # 5.3. Injection
    # Every aim writes the plan it ends up with, together with the two
    # flexibility itineraries and the commitment they carry. The
    # setpoints belong to the markets that trade energy: "operation"
    # and "operationflex" keep the ones they were given, and the plan
    # they write is that same plan re-simulated with the forecast of
    # the moment, from the state the building is in. Their energy is
    # thereby renominated, and the flexibility they restate or sell is
    # measured against the plan that is written, not against an
    # older one.
    # ---------------------------------------------------------
    {
      # itinerary_columns is called to name the columns of the plan
      # and of the two flexibility itineraries; the commitments of the
      # two legs are written with them. The phase codes are the
      # optimizer's own labels, scratch state of the search, and are
      # not written back: nothing outside the optimization piece reads
      # them.
      inject_cols    <- c(itinerary_columns("plan", parameters),
                          itinerary_columns("plan_flex_down", parameters),
                          itinerary_columns("plan_flex_up", parameters),
                          "Elec_flex_down_plan", "Elec_flex_up_plan")
      idx_inject     <- simulation_control$indexes_local$idx_ctrl - (simulation_control$indexes_local$i_begin_horizon - 1)

      # piece_write_rows is called to write the plan, the itineraries
      # and the commitments over the control rows, each into the table
      # that holds it.
      piece <- piece_write_rows(
        piece       = piece,
        rows        = simulation_control$indexes_local$idx_ctrl,
        source      = optimization_piece,
        source_rows = idx_inject,
        columns     = inject_cols
      )

      # The reward travels back per row, outside inject_cols, because it
      # is not a "_plan" column and because Main_df is not where it ends
      # up row by row: settle_market() adds it up and books
      # the total on the decision's own row, the same way it books the
      # lump-sum cost signals. Carrying it here is what gives that
      # function something to add up; without it the reward the optimizer
      # maximised was computed and then discarded.
      # It is carried over the whole OPTIMIZATION horizon, not just the
      # market's period, because that is the window reward_function()
      # evaluates and whose total the optimizer maximises. Summing only
      # the period would report a different number from the one the
      # search actually compared its candidates on.
      # Every aim calls reward_function() now, "operation" included, so
      # the number carried here is always the one its own evaluation
      # produced.
      # The first row of the optimization piece is its initial
      # condition, which is not a row of idx_horizon.
      # piece_write_rows is called to write it into the table of the
      # system.
      piece <- piece_write_rows(
        piece       = piece,
        rows        = simulation_control$indexes_local$idx_horizon,
        source      = optimization_piece,
        source_rows = seq_len(nrow(optimization_piece$system))[-1],
        columns     = "Reward"
      )
    }

    rm(list = c("optimization_piece", "optimization_control",
                "optimization_aim", "inject_cols", "idx_inject",
                "committed_derivation"))
  }

  # -------------------------------------------------------------
  # Report of the market
  # -------------------------------------------------------------
  if (parameters$debug_and_config$verbose) {
    process_name <- if (prefix == "Sched") "Scheduling" else "Piloting"

    # console_time is called to format the period of the market.
    # console_message is called to write the line of the market at its
    # bid time: its name, its role and its period.
    console_message(
      label = "MARKET",
      text  = paste0(
        formatC(as.character(market_parameters[[market_name_col]]),
                width = -market_name_width),
        " ",
        formatC(process_name,
                width = -max(nchar(c("Scheduling", "Piloting")))),
        " period ",
        console_time(market_parameters[[period_begin_col]]),
        " -> ",
        console_time(market_parameters[[period_end_col]])
      ),
      time  = market_parameters[[bid_time_col]]
    )
    rm(list = "process_name")
  }

  rm(list = c("market_name_col", "bid_time_col", "period_begin_col",
              "period_end_col", "market_aim_col", "column_order"))

  return(piece)
}
