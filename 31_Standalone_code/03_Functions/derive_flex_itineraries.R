# -------------------------------------------------------------
# Function: derive_flex_itineraries.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the two flexibility itineraries of a candidate from its own
# _plan itinerary AND the flexibility already committed by earlier
# markets, instead of throwing that commitment away.
# -------------------------------------------------------------
# Why the standing commitment is the starting point
# If both flexibility itineraries started as a copy of _plan with the
# commitment set to zero, every market would begin its search as if
# nothing had ever been sold. The reward does know about the standing
# commitment, because resolve_marginal_context() reads it from the
# input before optimizing, so undoing it costs money. But the ITINERARY
# the search works on would start at zero, so the optimizer would have
# to pay its way back to where it already was. On a flat optimum that
# is enough for the answer to flip from one market to the next, selling
# and rebuying the same commitment again and again.
# Here the standing commitment is the starting point instead.
# -------------------------------------------------------------
# How a standing window is held over a new plan
# The commitment is stored in kilowatt hours of electricity, and what
# the window builder takes is a thermal profile. Rather than invert the
# electrical model - which is piecewise and underdetermined, since one
# electricity figure does not say how much came from each machine -
# this function solves for the one number the window was built from.
# The window builder of the system, system_flex_window(), is
# parameterised, on both legs, by a flexibility fraction in (0, 1],
# and the electricity a window commits, on the net, grows
# monotonically with it. So for each standing window the fraction is
# found by bisection, calling the repository's own builder at each
# step, until the electricity it commits matches what was sold.
# The Neutral and Recovery Phases then come out built by the same code
# that built them originally, with the same power caps, and over the
# NEW plan.
# -------------------------------------------------------------
# Projection and guard zone
# Every row of a Commitment Phase is restated in one of two ways,
# depending on where it falls, whatever the aim of the market:
#   - Guard zone: rows inside the market interval, from the start of
#     the piece to i_end_control, when the restatement mode is "guard".
#     This market trades those rows, so the commitment margin is
#     demanded of them. When the new plan cannot hold what was sold
#     with the margin, the window is restated at the most the margin
#     allows, and the difference shows up as a smaller commitment,
#     which the economic chain books as a re-purchase. This is the only
#     flexibility a market whose aim is operation alone ever trades.
#   - Projection: every other row, and every row when the restatement
#     mode is "projection". No market trades those rows here: earlier
#     markets did, and later markets will. The window
#     is drawn as the new plan allows, with no margin and no judgement
#     of its feasibility, and the commitment sold there is not changed.
#     The reward values it at most at that commitment: what the plan
#     can no longer hold there is the re-purchase a later market will
#     have to make.
# A window whose Commitment Phase crosses a limit of the market
# interval is split: each part takes its own fraction.
# The minimum flexibility does not apply to a restated window: it is a
# rule on what a market sells, and a restatement sells nothing new. A
# market interval of the guard zone that the new plan can only hold
# below the minimum keeps what it holds, and only the shortfall is
# re-purchased.
# -------------------------------------------------------------
# The system of a standing upward window
# Which system serves a standing upward window is not stored: only its
# energy is. Each building finds it again over the new plan, through
# the operation restate_systems of its type of model
# (building_restate_systems()). When the prudence rule of
# resolve_flex_up_hvac() names a system, the window is rebuilt with
# it, as it would be sold. When the rule is undecided, the window is
# not refused for that: the rule decides whether a NEW window is
# sold, and this one was already sold. The window is then built with
# heating and with cooling, at the largest fractions, and the system
# kept is the one with which the building contributes and the window
# reaches what was sold (a window that would raise both systems of
# the building over the plan is refused by it). When both reach it,
# the one that uses more electricity in the plan over the long
# horizon of the rule (flex_up_horizon_long) is kept. When neither
# reaches it, the system kept is the one that, with the building
# contributing, commits more of what was sold: in the guard zone and
# in the projection, the electricity the window commits on the net up
# to what was sold there. The window is then restated with it as with
# a system the rule names: at the most it allows, with the shortfall
# of the guard zone re-purchased. When both systems are refused, the
# building refuses the window.
# With several buildings whose rule is undecided, their systems are
# chosen one building at a time, in the order of the asset registry,
# with the systems already chosen for the buildings before.
# -------------------------------------------------------------
# Assets that refuse a standing window
# How the assets shared a window is not stored, so a restated window
# is drawn by the system (system_flex_window()) with every asset of
# the registry, at one fraction for the set. An asset may refuse to
# redraw it (for a building, because it would raise both systems,
# because the plan leaves it no room, or because both systems are
# refused for an upward window whose system the rule leaves
# undecided). An asset may also accept it with no energy: a battery
# never refuses a window already sold, and when it has nothing to
# offer on it, what it does not reach is bought again. It does not
# refuse the window, so it holds none of it. Then:
#   - the assets that redraw it cover what was sold with their common
#     fraction, as far as they can;
#   - what they do not reach, in the guard zone or in the projection,
#     is held by the assets that refuse it, within the limits of their
#     equipment (system_hold_window());
#   - what is still missing is re-purchased.
# When no asset redraws the window, every asset that can hold it
# does. With a single asset, the window is either redrawn or held
# whole.
# Holding is a physical capability of the equipment: the operation
# can_hold of the model of each asset says whether the asset can
# keep its electricity apart from its plan (model_type_contract()).
# The holders, and the assets counted in the penalty, are chosen
# among the assets that can, in the order of the registry. When a
# commitment stands and no asset can hold, the run stops with a
# message.
# The Recovery Phase of an asset that stores energy
# A window restated over the new plan, the tail of a window and a
# window that is held are drawn with the alternative of the Recovery
# Phase that has the best reward, as a new window is (see
# system_flex_window()), when the valuation is given. The fractions
# of a restated window are found without the valuation, because the
# commitment does not depend on the Recovery Phase, and the window is
# then built once more with the fractions kept and the valuation,
# which chooses the alternative. The tail of a window is continued
# by every asset with the first alternative; each asset that offers
# alternatives and has a state in the tail continues it again with
# each of the others, and choose_recovery() keeps the piece with the
# best reward. The window held is chosen in system_hold_window().
# The window held is handed to the holders with the phase of each of
# its rows, rebuilt from the commitment that stands, and the row
# where the control horizon closes: an asset that stores energy, a
# battery, leaves its leg realizable until then, correcting the
# Recovery Phase of the window it holds (system_hold_window()).
# An asset that holds a window with rows in the guard zone cannot
# deliver it as sold, and it is reported, for that leg, as not
# technically feasible. Only the assets that actually hold energy in
# the window (more than flex_energy_tol, once it is held) are
# reported, with at least one asset per leg: when none of the
# holders keeps energy there, the first of them in the order of the
# registry is reported, so that a leg that cannot be delivered is
# never free.
# -------------------------------------------------------------
# Inputs
#   piece              : The piece of the market the derivation works on.
#                        The _plan itinerary of each asset is already
#                        simulated in its table. The standing commitment
#                        is in Elec_flex_down_plan / Elec_flex_up_plan of
#                        the table of the system, as it came from
#                        the input.
#                        The system side reads the table of the system:
#                        the standing commitment, the phases, the
#                        reconstruction of the standing windows,
#                        MarketUTC, and the commitment written in
#                        block 3. The asset side works on each asset: its
#                        plan copy in its own table, the state of its
#                        tail on row 1 of its table, restate_systems and
#                        continue_window_tail in its view. The window
#                        builder and the holding of a window
#                        (system_flex_window() and system_hold_window())
#                        work on the piece: the window builder draws on
#                        it and returns a piece, and the holding of a
#                        window returns the piece with the share held.
#   parameters         : Named list. Model and control parameters. Its
#                        asset registry (parameters$assets) gives the
#                        type of model of each asset, whose operations
#                        (model_type_contract()) choose the system of
#                        a restated window (restate_systems) and
#                        continue the tail of a window
#                        (continue_window_tail). The windows are drawn
#                        by system_flex_window(), and held by
#                        system_hold_window().
#   simulation_control : Named list, as system_flex_window() expects.
#                        Reads:
#                        indexes_local$i_end_control - last row of the
#                          market interval in this piece.
#                        flexibility$restatement_mode - "guard"
#                          (default) or "projection", see above.
#                        flexibility$pre_horizon_tail - when present,
#                          one entry per leg (down, up) for a window
#                          whose Commitment Phase started before this
#                          piece, as run_market_process() builds it:
#                            rows   - rows of this piece it occupies.
#                            phases - its phase code on those rows.
#                            state  - list named by asset_id, each a
#                                     one-row data frame. The state of
#                                     the flexibility itinerary of the
#                                     asset on row 1 of its table.
#                            system - list named by asset_id. The
#                                     system of each asset that
#                                     provides it.
#   recovery_valuation : Named list or NULL (default NULL).
#                        build_recovery_valuation() gives it: the
#                        alternatives with which the assets that store
#                        energy may draw the Recovery Phase of a
#                        window, and what is needed to value them.
#                        With NULL, or with no asset of the window that
#                        offers alternatives, nothing changes.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     piece        : the piece with both flexibility itineraries built in
#                    the table of each asset, and their phases marked and
#                    the commitment they carry written in
#                    Flex_phase_<leg>_plan and Elec_flex_<leg>_plan of
#                    the table of the system.
#     held         : Data frame, one row per asset and leg that holds
#                    energy of a window with rows in the guard zone (see
#                    "Assets that refuse a standing window" above), with the
#                    columns asset_id and leg. The caller reports each
#                    of them as not technically feasible.
#     feasible     : Logical. TRUE when held has no row.
# -------------------------------------------------------------
# Code outline
# 1. Take the standing commitment and lay the baseline
# 2. Restate each standing window over the new plan
# 3. Write the commitment the itineraries carry
# -------------------------------------------------------------
# Usage instructions
# derived <- derive_flex_itineraries(piece, parameters,
# simulation_control)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - With no standing commitment both itineraries are equal to _plan,
#     with phases and commitment at zero.
#   - The commitment is written here, from the itineraries just drawn,
#     with the definition reward_function() uses: the difference
#     between the net electricity of the system in the itinerary and
#     in the plan (system_flex_commitment()), over the Commitment
#     Phase. A market that places no new window, or whose aim does not
#     value flexibility, therefore keeps the commitment it restated
#     instead of losing it.
#   - Row 1 of every table of the piece is the initial state of the
#     simulation and is never simulated, so it carries no commitment
#     of its own and is left out of every window: a window starts at
#     row 2 at the earliest, and system_flex_window() takes the row
#     before its start as its initial condition.
#   - A window whose Commitment Phase ended before this piece has only
#     its Neutral and Recovery Phases left in it. They are continued
#     over the plan of this piece by the operation continue_window_tail
#     of each asset (continue_standing_tail() for a building), from the
#     state handed over on row 1. Each asset continues the tail with its
#     own state and system. It is also given the row where the control
#     horizon closes, and the halvings and the tolerance of a
#     bisection, so that a battery corrects the Recovery Phase of the
#     tail and leaves its leg realizable until that row.
#   - A window whose Commitment Phase started before this piece and
#     runs into it is rebuilt from row 2, with row 1, where the state of
#     its itinerary is handed over, as its initial condition, so it
#     continues the part the earlier stretch projected.
#   - An asset may refuse a window: it would raise both systems, or
#     the new plan leaves no room to draw it, for instance because it
#     already runs the system at its bound. A refusal is no reason to
#     throw away energy already sold: the commitment is held within the
#     limits of the equipment, and the next market rebuilds it. A
#     window with rows in the guard zone held by an asset is also
#     reported through held, because the plan cannot deliver that
#     window as sold.
#   - The bisection is bounded to flex_restatement_bisection_steps
#     halvings. It is solving one monotone scalar equation, so a few
#     tens of steps take it far below the energy tolerance of the
#     model.
# -------------------------------------------------------------

derive_flex_itineraries <- function(piece,
                                    parameters,
                                    simulation_control,
                                    recovery_valuation = NULL) {

  # 1. Take the standing commitment and lay the baseline
  # -------------------------------------------------------------
  {
    column_order <- parameters$joined_cols
    standing     <- list(
      down = piece$system$Elec_flex_down_plan,
      up   = piece$system$Elec_flex_up_plan
    )

    # Every column of the plan itinerary is copied to both flexibility
    # itineraries, by each asset in its own table. itinerary_columns is
    # called to name them: the commitments and the phase codes also end
    # in "_plan", but they belong to the plan alone and have no
    # flexibility counterpart.
    plan_cols   <- itinerary_columns("plan", parameters)
    copied_cols <- character(0)
    for (CONT_011 in names(piece$assets)) {
      asset_df   <- piece$assets[[CONT_011]]$df
      asset_plan <- intersect(plan_cols, names(asset_df))
      for (CONT_001 in asset_plan) {
        asset_df[[paste0(CONT_001, "_flex_down")]] <- asset_df[[CONT_001]]
        asset_df[[paste0(CONT_001, "_flex_up")]]   <- asset_df[[CONT_001]]
      }
      piece$assets[[CONT_011]]$df <- asset_df

      # The columns of the net are the copies of the plan columns that
      # the table of the system holds too: the net electricity.
      net_plan    <- intersect(asset_plan, names(piece$system))
      copied_cols <- union(copied_cols,
                           as.vector(rbind(paste0(net_plan, "_flex_down"),
                                           paste0(net_plan, "_flex_up"))))
    }
    rm(list = intersect(c("plan_cols", "CONT_001", "CONT_011", "asset_df",
                          "asset_plan", "net_plan"), ls()))

    # The net electricity of the itineraries just copied is the sum of
    # that of the assets, and it is written in the table of the system.
    net_cols <- copied_cols
    if (length(net_cols) > 0) {
      # sum_asset_energy is called to add the copied columns of every
      # asset, so that the net of each itinerary is written in the
      # table of the system.
      net <- sum_asset_energy(
        assets  = piece$assets,
        columns = net_cols,
        rows    = seq_len(nrow(piece$system))
      )
      for (CONT_012 in net_cols) {
        piece$system[[CONT_012]] <- net[[CONT_012]]
      }
      rm(list = c("net", "CONT_012"))
    }
    rm(list = c("copied_cols", "net_cols"))

    # The phases and the commitments of the itineraries belong to the
    # table of the system.
    piece$system$Flex_phase_down_plan <- 0
    piece$system$Flex_phase_up_plan   <- 0
    piece$system$Elec_flex_down_plan  <- 0
    piece$system$Elec_flex_up_plan    <- 0

    restatement_mode <- simulation_control$flexibility$restatement_mode
    if (is.null(restatement_mode)) {
      restatement_mode <- "guard"
    }
    if (!restatement_mode %in% c("guard", "projection")) {
      stop("derive_flex_itineraries: restatement_mode must be 'guard' or ",
           "'projection'")
    }

    # A window whose Commitment Phase started before this piece left its
    # itinerary in some state at row 1. That state is written on row 1,
    # the initial condition, of the table of its asset, so that whatever
    # is simulated of the window in this piece starts from it and not
    # from the plan's, and each asset continues its own tail from its
    # own state.
    held_tail <- simulation_control$flexibility$pre_horizon_tail
    for (CONT_004 in names(held_tail)) {
      for (CONT_009 in names(held_tail[[CONT_004]]$state)) {
        tail_state <- held_tail[[CONT_004]]$state[[CONT_009]]
        if (!all(names(tail_state) %in%
                 names(piece$assets[[CONT_009]]$df))) {
          stop("derive_flex_itineraries: the state of the tail of ",
               CONT_009, " holds columns that are not in the table of ",
               "the asset")
        }
        # piece_asset_view is called to take the table of the asset
        # joined with that of the system, on which the state is written.
        view <- piece_asset_view(
          piece        = piece,
          asset_id     = CONT_009,
          column_order = column_order
        )
        view[1, names(tail_state)] <- tail_state
        # piece_absorb_asset is called to take the state written on row 1
        # back into the table of the asset.
        piece <- piece_absorb_asset(
          piece    = piece,
          asset_id = CONT_009,
          view     = view
        )
        rm(list = c("tail_state", "view"))
      }
    }
    rm(list = intersect(c("CONT_004", "CONT_009"), ls()))

    nothing_standing <- all(vapply(standing, function(one_leg) {
      is.null(one_leg) || all(is.na(one_leg)) ||
        all(abs(one_leg[!is.na(one_leg)]) <= parameters$computing$flex_energy_tol)
    }, logical(1)))

    # One row per asset and leg that holds a window of the guard zone.
    held <- data.frame(asset_id         = character(0),
                       leg              = character(0),
                       stringsAsFactors = FALSE)

    if (nothing_standing && length(held_tail) == 0) {
      return(list(piece = piece, feasible = TRUE, held = held))
    }
    rm(list = "nothing_standing")
  }

  # 2. Restate each standing window over the new plan
  # -------------------------------------------------------------
  {
    i_end_control <- simulation_control$indexes_local$i_end_control
    if (is.null(i_end_control) || !is.numeric(i_end_control)) {
      stop("derive_flex_itineraries: simulation_control$indexes_local$",
           "i_end_control is mandatory when there is a commitment to restate")
    }

    # piece_layout is called to lay out the views of the assets once the
    # derivation has created the columns of the system it writes, so that
    # the views and absorbs of the restatement reuse the positions.
    piece <- piece_layout(
      piece        = piece,
      column_order = column_order
    )

    # model_type_contract is called for each asset of the registry,
    # to take the operations of its type of model, through which it
    # chooses the system of a restated window and continues the tail
    # of a window.
    asset_ids <- names(parameters$assets)
    models    <- lapply(parameters$assets, function(one_asset) {
      model_type_contract(one_asset$asset_type)
    })

    # The operation can_hold of the model of each asset is called to
    # tell which assets can keep their electricity apart from their
    # plan in a flexibility itinerary. Only those can hold a window
    # already sold, and only those are counted in its penalty. They
    # keep the order of the asset registry.
    can_hold <- vapply(asset_ids, function(one_asset) {
      models[[one_asset]]$can_hold(parameters$assets[[one_asset]])
    }, logical(1))
    hold_ids <- asset_ids[can_hold]
    rm(list = "can_hold")

    if (length(hold_ids) == 0) {
      stop("derive_flex_itineraries: a flexibility commitment is ",
           "standing, but no asset of the registry can hold ",
           "electricity apart from its plan, so nobody can keep it")
    }

    market_slot_h   <- parameters$market$market_resolution / 60
    tol_energy      <- parameters$computing$flex_energy_tol
    tol_restate     <- parameters$control$flex_restatement_tol
    bisection_steps <- parameters$control$flex_restatement_bisection_steps

    # The assets that count in the infeasibility penalty of a window held
    # over rows: those among the candidates that hold more than
    # flex_energy_tol there, in the order of the registry. When none of
    # them does, the first candidate counts, so that a leg that cannot be
    # delivered is never free.
    counted_holders <- function(held_piece, leg, rows, candidates) {
      energy <- vapply(candidates, function(one_asset) {
        asset_df <- held_piece$assets[[one_asset]]$df
        sum(abs(asset_df[[paste0("Elec_total_plan_flex_", leg)]][rows] -
                  asset_df$Elec_total_plan[rows]), na.rm = TRUE)
      }, numeric(1))
      holding <- candidates[energy > tol_energy]
      if (length(holding) == 0) candidates[1] else holding
    }

    # committed_by, bisect, the two parts bisect searches and the view
    # of an asset are defined once, before the loops over the legs and
    # the windows.
    # They read the objects of the window being restated (the leg, its
    # rows, the systems in hvac_choice, the control, the fractions and
    # the builds kept) when they are called, from the frame of this
    # function, where the loops write them.
    #
    # committed_by returns the electricity the window commits, over
    # the NEW plan, in its guard rows and in its projected rows, for
    # a fraction of each part and the systems in hvac_choice, with
    # the assets that contribute to it; or NA when the window is
    # not built, with the reason given. The reason is read from the
    # refusal field the builder returns, never from the rebuilt
    # phase: from the second window of a leg onwards the piece
    # already carries the phases of the earlier ones, so a refusal
    # does not show up as a phase of zeros. The builds are kept,
    # because the final pair of fractions has always been tried
    # during the search.
    # The rows, the phases and the views of the window do not depend
    # on the fractions nor on the systems in hvac_choice, so
    # committed_by prepares them once per window, at its first build
    # (system_flex_frame()), keeps them in window_frame and hands
    # them to every build of the same window.
    committed_by <- function(fraction_guard, fraction_projected,
                             valuation = NULL) {
      key <- paste(c(names(hvac_choice), unlist(hvac_choice),
                     fraction_guard, fraction_projected,
                     if (!is.null(valuation)) "valued"),
                   collapse = " ")
      if (!is.null(builds[[key]])) return(builds[[key]])

      control_here$flexibility$flexibility           <- fraction_guard
      control_here$flexibility$flexibility_projected <- fraction_projected
      control_here$flexibility$hvac_up <-
        if (length(hvac_choice) == 0) NULL else hvac_choice
      if (is.null(window_frame)) {
        # system_flex_frame is called to prepare, once for this
        # window, its rows and phases, the piece with the phases
        # written, and the operations and view of each asset.
        window_frame <<- system_flex_frame(
          leg                = one_leg,
          piece              = piece,
          parameters         = parameters,
          simulation_control = control_here
        )
      }
      # system_flex_window is called to rebuild the window of the
      # system on this leg with this pair of fractions, each asset
      # drawing its contribution, on the frame of the window.
      built_window <- system_flex_window(
        leg                = one_leg,
        piece              = piece,
        parameters         = parameters,
        simulation_control = control_here,
        recovery_valuation = valuation,
        frame              = window_frame
      )
      built        <- built_window$piece
      refusal      <- built_window$refusal
      contributors <- built_window$contributors
      empty        <- built_window$empty_contributors
      rm(list = "built_window")
      rebuilt_phase <- built$system[[paste0("Flex_phase_", one_leg, "_plan")]]
      if (is.null(refusal) && !any(rebuilt_phase[window_rows] == 1L)) {
        refusal <- "not_built"
      }

      answer <- if (!is.null(refusal)) {
        list(guard = NA_real_, projected = NA_real_, piece = built,
             refusal = refusal, contributors = character(0),
             empty_contributors = character(0))
      } else {
        # Only THIS window's rows count. The piece carries the phases
        # of the windows already restated on this leg, so summing
        # over every row marked 1 would add their commitment to this
        # one. The window is the stretch of phase 1 that contains
        # the row it starts at.
        own        <- rebuilt_phase == 1L
        runs       <- rle(own)
        run_ends   <- cumsum(runs$lengths)
        run_starts <- run_ends - runs$lengths + 1
        this_run   <- which(run_starts <= window_rows[1] & run_ends >= window_rows[1])
        own_rows   <- run_starts[this_run]:run_ends[this_run]

        # system_flex_commitment is called to read the commitment
        # of the net on this leg, row by row.
        difference <- system_flex_commitment(
          period_chunk = built$system,
          leg          = one_leg
        )
        list(guard        = sum(difference[intersect(own_rows, guard_rows)], na.rm = TRUE),
             projected    = sum(difference[intersect(own_rows, projected_rows)], na.rm = TRUE),
             piece        = built,
             refusal      = NULL,
             contributors = contributors,
             empty_contributors = if (is.null(empty)) {
               character(0)
             } else {
               empty
             })
      }
      builds[[key]] <<- answer
      answer
    }

    # bisect returns the smallest fraction of one part whose
    # electricity reaches what was sold there. The convergence test
    # is against flex_restatement_tol, the energy the restatement is
    # allowed to miss by: a few halvings of a fraction cannot reach
    # flex_energy_tol, so such a test would never stop the loop
    # early. Stopping early must not make the restatement worse than
    # it already was: of the two fractions in hand, the one closer
    # to what was sold is kept.
    bisect <- function(energy_of, target_part, value_at_one) {
      low <- 0
      high <- 1
      best_fraction <- 1
      best_value    <- value_at_one
      for (CONT_003 in seq_len(bisection_steps)) {
        middle <- (low + high) / 2
        value  <- energy_of(middle)
        if (is.na(value) || value < target_part) {
          low <- middle
        } else {
          high <- middle
          best_fraction <- middle
          best_value    <- value
        }
        if (!is.na(value) && abs(value - target_part) <= tol_restate) {
          if (abs(value - target_part) < abs(best_value - target_part)) {
            best_fraction <- middle
          }
          break
        }
      }
      best_fraction
    }

    # projected_part and guard_part give the electricity the window
    # commits in each part for a fraction of that part, which bisect
    # searches.
    projected_part <- function(fraction) {
      committed_by(1, fraction)$projected
    }
    guard_part <- function(fraction) {
      committed_by(fraction, fraction_projected)$guard
    }

    # view_of_asset gives the view of one asset of the piece as it
    # stands when it is called.
    view_of_asset <- function(one_id) {
      # piece_asset_view is called to take the table of the asset
      # joined with that of the system.
      piece_asset_view(
        piece        = piece,
        asset_id     = one_id,
        column_order = column_order
      )
    }

    for (one_leg in c("down", "up")) {

      committed_col <- paste0("Elec_flex_", one_leg, "_plan")
      tail          <- held_tail[[one_leg]]
      tail_commits  <- !is.null(tail) && any(tail$phases == 1L)

      # The operation continue_window_tail of the model of each asset
      # (continue_standing_tail() for a building) is called when the
      # window that started before this piece has only its Neutral and
      # Recovery Phases left here. The phases of a window belong to the
      # table of the system, so they are written there first. Each asset
      # then continues the tail in its view, with its own state and
      # system. With the valuation, the view and the tail of each asset
      # that offers alternatives for the Recovery Phase and has a state
      # in the tail are kept, to continue the tail again with each
      # alternative.
      if (!is.null(tail) && !tail_commits) {
        phase_col <- paste0("Flex_phase_", one_leg, "_plan")
        tail_keep <- tail$rows <= nrow(piece$system)
        piece$system[[phase_col]][tail$rows[tail_keep]] <-
          tail$phases[tail_keep]
        tail_choosers <- list()
        for (CONT_010 in asset_ids) {
          asset_tail <- list(
            rows            = tail$rows,
            phases          = tail$phases,
            state           = tail$state[[CONT_010]],
            system          = tail$system[[CONT_010]],
            i_end_control   = i_end_control,
            bisection_steps =
              parameters$control$flexibility_commitment_bisection_steps,
            tolerance       = tol_energy
          )
          # piece_asset_view is called to take the table of the asset
          # joined with that of the system, which the operation of the
          # model continues.
          view <- piece_asset_view(
            piece        = piece,
            asset_id     = CONT_010,
            column_order = column_order
          )
          if (!is.null(recovery_valuation) &&
              CONT_010 %in% recovery_valuation$choosers &&
              !is.null(tail$state[[CONT_010]])) {
            tail_choosers[[CONT_010]] <- list(view = view,
                                              tail = asset_tail)
          }
          view <- models[[CONT_010]]$continue_window_tail(
            period_chunk = view,
            leg          = one_leg,
            tail         = asset_tail,
            asset        = parameters$assets[[CONT_010]]
          )
          # piece_absorb_asset is called to take the columns of the
          # asset back into its table. The phases it wrote in its view
          # do not come back: they are those the system holds.
          piece <- piece_absorb_asset(
            piece    = piece,
            asset_id = CONT_010,
            view     = view
          )
          rm(list = c("asset_tail", "view"))
        }

        # The Recovery Phase of the tail. Each asset kept continues the
        # tail again with each alternative, from the view it had before,
        # on a copy of the piece. An alternative that draws the same
        # electricity as the first is not valued. The piece with the best
        # reward on this leg is kept.
        if (length(tail_choosers) > 0) {
          leg_electricity <- paste0("Elec_total_plan_flex_", one_leg)
          alternatives    <- list()
          for (CONT_013 in recovery_valuation$choices[-1]) {
            piece_alternative <- piece
            changed           <- FALSE
            for (CONT_014 in names(tail_choosers)) {
              tail_alternative          <- tail_choosers[[CONT_014]]$tail
              tail_alternative$recovery <- CONT_013

              # The operation continue_window_tail of the model is
              # called to continue the tail again, with this
              # alternative of the Recovery Phase.
              view <- models[[CONT_014]]$continue_window_tail(
                period_chunk = tail_choosers[[CONT_014]]$view,
                leg          = one_leg,
                tail         = tail_alternative,
                asset        = parameters$assets[[CONT_014]]
              )
              changed <- changed ||
                max(abs(view[[leg_electricity]] -
                          piece$assets[[CONT_014]]$df[[leg_electricity]]),
                    na.rm = TRUE) > tol_energy

              # piece_absorb_asset is called to take the tail continued
              # with this alternative into the table of the asset, and
              # to sum the net electricity of the system again.
              piece_alternative <- piece_absorb_asset(
                piece    = piece_alternative,
                asset_id = CONT_014,
                view     = view
              )
              rm(list = c("tail_alternative", "view"))
            }
            if (changed) {
              alternatives[[length(alternatives) + 1]] <- piece_alternative
            }
            rm(list = c("piece_alternative", "changed", "CONT_014"))
          }

          if (length(alternatives) > 0) {
            # choose_recovery is called to choose, among the tail
            # continued with the first alternative and with the others,
            # the one with the best reward on this leg.
            chosen <- choose_recovery(
              pieces             = c(list(piece), alternatives),
              leg                = one_leg,
              parameters         = parameters,
              recovery_valuation = recovery_valuation
            )
            if (chosen$index > 1) {
              piece <- alternatives[[chosen$index - 1]]
            }
            rm(list = "chosen")
          }
          rm(list = c("leg_electricity", "alternatives", "CONT_013"))
        }
        rm(list = c("CONT_010", "phase_col", "tail_keep", "tail_choosers"))
      }

      # reconstruct_flex_phases is called on a copy of the table of the
      # system carrying the standing commitment, because the baseline
      # above has already zeroed the column it reads.
      standing_chunk <- piece$system
      standing_chunk[[committed_col]] <- standing[[one_leg]]
      phase <- reconstruct_flex_phases(standing_chunk, one_leg, parameters)
      rm(list = "standing_chunk")

      if (!any(phase == 1L)) next

      stretches <- rle(phase == 1L)
      ends      <- cumsum(stretches$lengths)
      starts    <- ends - stretches$lengths + 1

      for (CONT_002 in which(stretches$values)) {

        window_rows <- starts[CONT_002]:ends[CONT_002]

        # The Commitment Phase that runs on from before this piece is
        # rebuilt from the start of the piece, where the state of its
        # itinerary is.
        if (tail_commits && window_rows[1] <= min(tail$rows)) {
          window_rows <- seq_len(ends[CONT_002])
        }

        # Row 1 is never simulated, so it counts for no window: it is
        # the initial condition system_flex_window() puts in front of a
        # window that starts on row 2. The rest of the Commitment Phase
        # is split between the guard zone and the projection.
        window_rows <- window_rows[window_rows > 1]
        if (length(window_rows) == 0) next
        counted_rows   <- window_rows
        guard_rows     <- if (restatement_mode == "guard") {
          counted_rows[counted_rows <= i_end_control]
        } else {
          integer(0)
        }
        projected_rows <- setdiff(counted_rows, guard_rows)

        target <- c(guard     = sum(standing[[one_leg]][guard_rows], na.rm = TRUE),
                    projected = sum(standing[[one_leg]][projected_rows], na.rm = TRUE))
        if (any(!is.finite(target)) || sum(abs(target)) <= tol_energy) next

        # The window as it is held, if it is: the phase of each row from
        # the start of its Commitment Phase to the end of its Recovery
        # Phase, which runs on while the rows carry a Neutral or Recovery
        # Phase of the window (as pre_horizon_window_tails() ends it).
        window_end <- ends[CONT_002]
        while (window_end < length(phase) &&
               phase[window_end + 1] %in% c(2L, 3L)) {
          window_end <- window_end + 1L
        }
        held_phase <- integer(length(phase))
        held_range <- min(window_rows):window_end
        held_phase[held_range] <- phase[held_range]
        held_window <- list(phase         = held_phase,
                            i_end_control = i_end_control)
        rm(list = c("window_end", "held_phase", "held_range"))

        control_here <- simulation_control
        control_here$indexes_local$i_flex <- window_rows[1]
        control_here$flexibility$commitment_phase_length <-
          length(unique(piece$system$MarketUTC[window_rows])) * market_slot_h

        # This is a RE-STATEMENT of a commitment already sold, not a new
        # sale, and the builder is told so, together with the mode that
        # decides which of its rows are in the guard zone.
        control_here$flexibility$restating        <- TRUE
        control_here$flexibility$restatement_mode <- restatement_mode

        # The views of this window are taken once, each asset in its own
        # view. The piece does not change while the fractions of this
        # window are searched.
        asset_views <- lapply(setNames(asset_ids, asset_ids),
                              view_of_asset)

        # The system of each building for an upward window: a building
        # with no entry in hvac_choice lets the builder ask
        # resolve_flex_up_hvac(), as for a window it sells. A building
        # whose rule is undecided has both systems as candidates (see
        # "The system of a standing upward window" above).
        choices <- list()
        for (CONT_006 in asset_ids) {
          # The operation restate_systems of the model
          # (building_restate_systems() for a building) is called to
          # know whether the asset has a system to choose for this
          # window.
          options <- models[[CONT_006]]$restate_systems(
            period_chunk = asset_views[[CONT_006]],
            leg          = one_leg,
            i_flex       = window_rows[1],
            parameters   = parameters,
            asset        = parameters$assets[[CONT_006]]
          )
          if (!is.null(options)) {
            choices[[CONT_006]] <- options
          }
          rm(list = "options")
        }
        rm(list = "CONT_006")
        hvac_choice <- list()

        # The builds of this window, which committed_by keeps: a window
        # starts with none.
        builds       <- list()
        window_frame <- NULL

        # A building whose rule is undecided takes the system with which
        # it contributes and the window reaches what was sold at the
        # largest fractions. When neither reaches it, it takes the
        # system with which it contributes and the window commits more
        # of what was sold, counting in each part no more than was sold
        # there. When it contributes with neither, it has no system:
        # it is left out of hvac_choice, and refuses the window.
        no_system <- character(0)
        for (CONT_005 in names(choices)) {
          candidates <- choices[[CONT_005]]$candidates
          reaching   <- character(0)
          covered    <- setNames(rep(NA_real_, length(candidates)),
                                 candidates)
          for (CONT_007 in candidates) {
            hvac_choice[[CONT_005]] <- CONT_007
            trial <- committed_by(1, 1)
            if (is.null(trial$refusal) && CONT_005 %in% trial$contributors) {
              covered[[CONT_007]] <- min(trial$guard, target[["guard"]]) +
                min(trial$projected, target[["projected"]])
              if (trial$guard     >= target[["guard"]]     - tol_restate &&
                  trial$projected >= target[["projected"]] - tol_restate) {
                reaching <- c(reaching, CONT_007)
              }
            }
            rm(list = "trial")
          }
          chosen <- if (length(reaching) > 0) {
            reaching[1]
          } else if (any(!is.na(covered))) {
            names(covered)[which.max(covered)]
          } else {
            "none"
          }
          if (length(reaching) > 1 &&
              choices[[CONT_005]]$preferred %in% reaching) {
            chosen <- choices[[CONT_005]]$preferred
          }
          if (chosen == "none") {
            hvac_choice[[CONT_005]] <- NULL
            no_system <- c(no_system, CONT_005)
          } else {
            hvac_choice[[CONT_005]] <- chosen
          }
          rm(list = c("candidates", "reaching", "covered", "chosen",
                      "CONT_007"))
        }
        rm(list = "CONT_005")

        # The largest fractions are tried first: they say whether the new
        # plan can reach what was sold at all. When no asset has a
        # system, there is nothing to build.
        highest <- if (all(hold_ids %in% no_system)) {
          list(refusal = "no_system", contributors = character(0))
        } else {
          committed_by(1, 1)
        }

        if (!is.null(highest$refusal)) {
          # system_hold_window is called to carry the whole commitment
          # forward, held by every asset as far as its equipment allows.
          piece <- system_hold_window(
            piece       = piece,
            leg         = one_leg,
            window_rows = counted_rows,
            need        = standing[[one_leg]],
            holders     = hold_ids,
            parameters  = parameters,
            hold        = held_window,
            recovery_valuation = recovery_valuation
          )
          if (length(guard_rows) > 0) {
            held <- rbind(held, data.frame(
              asset_id         = counted_holders(piece, one_leg, counted_rows,
                                                 hold_ids),
              leg              = one_leg,
              stringsAsFactors = FALSE))
          }
          rm(list = c("builds", "window_frame", "highest", "choices", "hvac_choice", "no_system", "asset_views",
                      "held_window"))
          next
        }

        # Projection: the fraction that reaches what was sold, or the
        # largest one when even that falls short. The commitment there
        # is not changed: it is drawn as the new plan allows.
        fraction_projected <- 1
        if (length(projected_rows) > 0 &&
            highest$projected >= target[["projected"]] - tol_restate) {
          fraction_projected <- bisect(projected_part,
                                       target[["projected"]], highest$projected)
        }

        # Guard zone: the fraction that reaches what was sold. When even
        # the largest one falls short, once the margin has been taken
        # out of the new plan, the window is restated at the most the
        # margin allows: the shortfall is RE-SOLD, and shows up as a
        # smaller commitment that the economic chain books as a
        # re-purchase against the earlier sale.
        fraction_guard <- 1
        if (length(guard_rows) > 0) {
          at_one <- committed_by(1, fraction_projected)$guard
          if (!is.na(at_one) && at_one >= target[["guard"]] - tol_restate) {
            fraction_guard <- bisect(guard_part,
                                     target[["guard"]], at_one)
          }
          rm(list = "at_one")
        }

        restated     <- committed_by(fraction_guard, fraction_projected)
        kept         <- if (is.null(restated$refusal)) restated else highest

        # When an asset of the window kept offers alternatives for the
        # Recovery Phase, the window is built once more with the
        # fractions kept and the valuation, which draws it with the
        # alternative that has the best reward. The fractions are the
        # same, so the window commits the same.
        if (!is.null(recovery_valuation) &&
            any(kept$contributors %in% recovery_valuation$choosers)) {
          valued <- if (is.null(restated$refusal)) {
            committed_by(fraction_guard, fraction_projected,
                         recovery_valuation)
          } else {
            committed_by(1, 1, recovery_valuation)
          }
          if (!is.null(valued$refusal) ||
              (length(guard_rows) > 0 &&
               abs(valued$guard - kept$guard) > tol_restate) ||
              (length(projected_rows) > 0 &&
               abs(valued$projected - kept$projected) > tol_restate)) {
            stop("derive_flex_itineraries: the choice of the Recovery ",
                 "Phase changed the commitment of the window")
          }
          kept <- valued
          rm(list = "valued")
        }

        # The window kept was built on the piece, and the piece it
        # returned, with the window drawn, takes its place.
        piece <- kept$piece

        # The assets that refuse the window kept hold what it does not
        # reach of what was sold, part by part (see "Assets that refuse
        # a standing window" above). An asset that accepts it with no
        # energy does not refuse it. On each row of a part that falls
        # short, they hold what the window commits there below what
        # was sold, scaled down so that the part does not hold more
        # than it misses.
        refusers    <- setdiff(hold_ids, c(kept$contributors,
                                           kept$empty_contributors))
        short_parts <- c(
          guard     = length(guard_rows) > 0 &&
            kept$guard < target[["guard"]] - tol_restate,
          projected = length(projected_rows) > 0 &&
            kept$projected < target[["projected"]] - tol_restate
        )
        if (length(refusers) > 0 && any(short_parts)) {
          # system_flex_commitment is called to read what the window
          # kept commits on the net, row by row.
          committed_now <- system_flex_commitment(
            period_chunk = piece$system,
            leg          = one_leg
          )
          need <- numeric(nrow(piece$system))
          for (CONT_008 in names(short_parts)[short_parts]) {
            part_rows <- if (CONT_008 == "guard") guard_rows else projected_rows
            sold      <- standing[[one_leg]][part_rows]
            sold[is.na(sold)] <- 0
            row_need  <- pmax(sold - committed_now[part_rows], 0)
            missing   <- target[[CONT_008]] - kept[[CONT_008]]
            if (sum(row_need) > missing) {
              row_need <- row_need * (missing / sum(row_need))
            }
            need[part_rows] <- row_need
            rm(list = c("part_rows", "sold", "row_need", "missing"))
          }
          hold_rows <- counted_rows[need[counted_rows] > 0]
          if (length(hold_rows) > 0) {
            # system_hold_window is called to carry what the window does
            # not reach forward, held by the assets that refuse it as far
            # as their equipment allows.
            piece <- system_hold_window(
              piece       = piece,
              leg         = one_leg,
              window_rows = hold_rows,
              need        = need,
              holders     = refusers,
              parameters  = parameters,
              hold        = held_window,
              recovery_valuation = recovery_valuation
            )
            if (short_parts[["guard"]]) {
              held <- rbind(held, data.frame(
                asset_id         = counted_holders(piece, one_leg, hold_rows,
                                                   refusers),
                leg              = one_leg,
                stringsAsFactors = FALSE))
            }
          }
          rm(list = c("CONT_008", "committed_now", "need", "hold_rows"))
        }

        rm(list = c("builds", "window_frame", "highest", "restated",
                    "kept", "refusers", "short_parts", "fraction_guard",
                    "fraction_projected", "choices", "hvac_choice",
                    "no_system", "asset_views", "held_window"))
      }
    }
  }

  # 3. Write the commitment the itineraries carry
  # -------------------------------------------------------------
  # The same definition as reward_function(), on the net electricity
  # of the system: downward, what the itinerary spends below the
  # plan; upward, what it spends above it; both over the Commitment
  # Phase alone.
  # -------------------------------------------------------------
  {
    # system_flex_commitment is called once per leg to read the
    # commitment of the net, which is then kept on the rows of the
    # Commitment Phase.
    piece$system$Elec_flex_down_plan <-
      system_flex_commitment(period_chunk = piece$system, leg = "down") *
      (piece$system$Flex_phase_down_plan == 1)
    piece$system$Elec_flex_up_plan <-
      system_flex_commitment(period_chunk = piece$system, leg = "up") *
      (piece$system$Flex_phase_up_plan == 1)
  }

  rm(list = c("standing", "market_slot_h", "tol_energy", "counted_holders",
              "committed_by", "bisect", "projected_part", "guard_part",
              "view_of_asset",
              "tol_restate", "bisection_steps", "held_tail", "restatement_mode",
              "i_end_control", "models", "asset_ids", "hold_ids",
              "column_order"))

  held <- unique(held)
  rownames(held) <- NULL

  return(list(piece = piece, feasible = nrow(held) == 0, held = held))
}
