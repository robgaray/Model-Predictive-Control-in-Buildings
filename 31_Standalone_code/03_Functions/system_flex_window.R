# -------------------------------------------------------------
# Function: system_flex_window.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds one flexibility window of the system, on one leg, downward or
# upward, over a planning period. The window is of the set of assets:
#   - the system fixes the window: its rows, its three phases, the
#     rows of its Commitment Phase in the guard zone and the fraction
#     of flexibility of each of them;
#   - each asset drafts its contribution to it, through the operation
#     window_draft of its type of model (model_type_contract());
#   - the system applies the commitment margin to the set of assets
#     that contribute (system_commitment_margin()): one margin, kept by
#     their net electricity;
#   - each asset draws its contribution with what the margin left,
#     through the operation window_contribution of its type of model,
#     and applies the technical rules of its type;
#   - the commitment is that of the net: what the window sells in each
#     market interval is the difference between the net electricity of
#     the system in the itinerary of the leg and in the plan
#     (system_flex_commitment()), and the rules on what a window sells
#     are checked on it.
# The window is accepted when at least one asset contributes to it and
# its net commitment keeps those rules. Otherwise the piece is returned
# as it came in.
# An asset may draw the Recovery Phase of the window in more than one
# way (operation recovery_choices). The window is first built with the
# first alternative of each of them. When the caller gives a valuation
# of the Recovery Phase (build_recovery_valuation()), the assets that
# contribute and offer alternatives draw their contribution again with
# each of the others, with the same draft and the same margin, and the
# system keeps the window with the best reward (choose_recovery()).
# The alternatives differ only in the Recovery Phase, so the
# commitment of the window is the same in all of them, and the rules
# on it are checked once.
# The rows and phases of the window, the piece with the phases
# written and the operations and view of each asset do not depend on
# the fraction of flexibility: they are the frame of the window
# (system_flex_frame()), which a caller that builds the same window
# with several fractions prepares once and hands over.
# The window is built on the piece of a market. The phases are written
# in the table of the system. Each asset drafts and draws in its view
# of the piece (piece_asset_view()), and what it draws comes back into
# its table, with the net electricity of the system summed again
# (piece_absorb_asset()). The piece received is never modified: every
# write goes to a new piece.
# The window lives only within this call and within the market that
# builds it. What leaves the market is the energy each itinerary
# commits, from which the next market reconstructs the phases
# (reconstruct_flex_phases()).
# -------------------------------------------------------------
# Rows and instants
# A row holds the state of each asset at its instant and the energy of
# the time step that ends there. The window starts at the instant its
# first market interval starts, so the row of that instant, the last
# row of the interval before, is its initial condition: it is
# simulated as the first row of the window, but it is not recomputed
# and it belongs to no phase. i_flex is the first row of the
# Commitment Phase, the first row of that interval. Every phase is a
# span of instants after the start, so each of them holds whole time
# steps:
#   Commitment - rows in [t(i_flex), t(i_flex) + L)
#   Neutral    - rows in [t(i_flex) + L, t(i_flex) + L + R)
#   Recovery   - rows in [t(i_flex) + L + R, t(i_flex) + L + R + S)
# with L, R and S the lengths of the three phases. The lengths of the
# Neutral and Recovery Phases are of the system, the same for every
# asset, so the next market can reconstruct the phases from the net
# commitment alone. These are the rows reconstruct_flex_phases() reads
# back.
# -------------------------------------------------------------
# The contribution of the assets
# Every asset contributes with the same fraction of flexibility, row
# by row. An asset may contribute nothing:
#   - it has nothing to offer on the leg (for a building, an upward
#     window with no dominant system, or one that raises nothing);
#   - its contribution breaks the technical rules of its type (for a
#     building, the recovery does not converge by the close of the
#     control horizon, or the window raises both thermal systems).
# The rules are applied within each asset, and an asset that breaks
# them contributes nothing; the others contribute what they can.
# When no asset contributes, the window is not built, and the reason
# of the first asset that refused it, if any, is returned.
# An asset may accept a restated window with no energy: it has
# nothing to offer on it, but it does not refuse it (for a battery,
# what it does not reach of a window already sold is bought again).
# It does not contribute, and it is returned apart from those that
# refuse the window.
# -------------------------------------------------------------
# The margin of the set
# The commitment margin is one, of the set of assets that contribute
# to the window, and it is applied before they simulate it, because
# the heat it leaves in the Commitment Phase drives the Neutral and
# Recovery Phases:
#   1. every asset drafts its contribution: what it would draw in the
#      Commitment Phase before the margin, and its margin data;
#   2. on the rows of the guard zone, the system keeps
#      flexibility_commitment_margin of net electricity unused against
#      the limit of the set, scaling the departure of every asset from
#      its plan by one same factor in each market interval, and brings
#      back to the plan the intervals of a new window that would sell
#      less than their minimum (system_commitment_margin());
#   3. every asset draws its contribution with the heat the margin
#      left.
# An asset that then contributes nothing leaves the set, and the
# margin is applied again to the assets that remain, so that the net
# of the assets that finally contribute keeps it. With a single asset
# there is nothing to apply again: the window is either built or
# refused.
# -------------------------------------------------------------
# The net commitment
# Two rules on what a new window sells are checked on the net, once
# the assets have contributed:
#   - an upward window has to raise the net electricity of the system
#     over its Commitment Phase. A window that consumes less than the
#     plan would sell a load reduction at upward prices;
#   - each market interval of the Commitment Phase sells nothing or at
#     least minimum_flexibility times the length of the interval, in
#     electricity ("below_minimum"), and the first and the last sell
#     something ("empty_edge"). The window one interval shorter is
#     another candidate of the search, and the next market, which
#     rebuilds the windows from the committed energy, would not see
#     those intervals as part of this one. An interval inside the
#     window that sells nothing is a gap of the window.
# The upward rule is checked on every window. The minimum and the
# edges are rules on what a market sells, and a restated window sells
# nothing new, so they do not apply to it.
# -------------------------------------------------------------
# Inputs
#   leg                : Character scalar, "down" or "up". The leg the
#                        window belongs to.
#   piece              : List. The piece of the planning period, as
#                        build_market_piece() gives it. It must hold the
#                        _plan itinerary of every asset simulated in its
#                        table, the *_plan_flex_<leg> baseline columns
#                        initialized by derive_flex_itineraries(), and
#                        the phases in the table of the system.
#   parameters         : Named list. Model and control parameters.
#                        Reads:
#                          - parameters$assets, the asset registry,
#                            whose entries are handed to the operations
#                            of their types of model
#                          - parameters$control$neutral_phase_timespan
#                            and recovery_phase_timespan (h)
#                          - parameters$computing$main_resolution_sec
#                            (s), the time step
#                          - parameters$computing$flex_energy_tol (kWh)
#                          - parameters$joined_cols, the order of the
#                            columns of the view of an asset
#                          - what commitment_margin_bound() and
#                            system_commitment_margin() read
#   simulation_control : Named list. Simulation control object. Reads:
#                          - indexes_local$i_flex: integer scalar, the
#                            first row of the Commitment Phase in
#                            the piece, at least 2: the row before
#                            it is the initial condition of the window
#                          - indexes_local$i_end_control: integer
#                            scalar, the last row of the control
#                            horizon in the piece
#                          - flexibility$commitment_phase_length:
#                            numeric scalar, the duration of the
#                            Commitment Phase (h), at most
#                            commitment_phase_length_max
#                          - flexibility$flexibility: numeric scalar in
#                            (0, 1], the fraction of flexibility of the
#                            rows of the guard zone (1 = full
#                            flexibility)
#                          - flexibility$restating,
#                            flexibility$restatement_mode,
#                            flexibility$flexibility_projected and
#                            flexibility$hvac_up, optional, for a
#                            window that is restated (see
#                            derive_flex_itineraries()). hvac_up is a
#                            list named by asset_id: for a building
#                            named there, "heat" or "cool", the system
#                            it uses for a restated upward window. It
#                            is only read when restating
#   recovery_valuation : Named list or NULL (default NULL). The
#                        valuation of the Recovery Phase, as
#                        build_recovery_valuation() gives it. With NULL
#                        every asset draws the Recovery Phase with its
#                        first alternative, and no economic function is
#                        called.
#   frame              : Named list or NULL (default NULL). The frame of
#                        the window, as system_flex_frame() gives it for
#                        the same leg, piece, parameters and
#                        simulation_control (whatever its fractions of
#                        flexibility and hvac_up). With NULL the frame
#                        is prepared here. A caller that builds the same
#                        window with several fractions prepares it once
#                        and hands it to every call.
# -------------------------------------------------------------
# Outputs
#   A named list with:
#   piece   : List. The piece with the *_plan_flex_<leg> columns of the
#             assets that contribute drawn in their tables over the rows
#             of the window after its initial condition, the net
#             electricity of the system summed again, and
#             Flex_phase_<leg>_plan of the table of the system set to
#             the phase code of each of them (1 Commitment, 2 Neutral,
#             3 Recovery; 0 elsewhere, as left by
#             derive_flex_itineraries()). A window that is not built
#             returns the piece received.
#   refusal : Character scalar or NULL. The reason the window is
#             refused, one of those of flex_refused(), when the window
#             is not built for one of them. NULL when the window is
#             built. A window to which no asset contributes, with no
#             asset refusing it, and an upward window that does not
#             raise the net electricity of its Commitment Phase, are
#             returned as they came in with a NULL refusal.
#   contributors : Character vector. The asset_id of each asset that
#             contributes to the window built; empty when the window
#             is returned as it came in. The others refused it, or
#             had nothing to offer on it.
#   empty_contributors : Character vector, only when the window is
#             built and some asset accepts it with no energy. The
#             asset_id of each asset that has nothing to offer on a
#             restated window and accepts it with no energy (accepted,
#             from its operation window_draft or window_contribution):
#             it does not refuse the window, and what it does not
#             reach of it is bought again.
# -------------------------------------------------------------
# Code outline
# 1. The frame of the window: its rows and phases, the piece with the
#    phases written, and the operations and view of each asset
#    (system_flex_frame(), unless the caller hands it over)
# 2. The fraction of flexibility of each row
# 3. The contribution of each asset
#   3.1. The draft of each asset
#   3.2. The margin of the set and the contributions
# 4. Check the net electricity of an upward window
# 5. Check the net commitment of every market interval
# 6. Choose the Recovery Phase of the assets that offer alternatives
#   6.1. The window drawn with each alternative
#   6.2. The choice
# -------------------------------------------------------------
# Usage instructions
# built <- system_flex_window(leg                = "down",
#                             piece              = piece,
#                             parameters         = parameters,
#                             simulation_control = simulation_control)
# With a frame prepared once for several fractions:
# frame <- system_flex_frame(leg                = "down",
#                            piece              = piece,
#                            parameters         = parameters,
#                            simulation_control = simulation_control)
# built <- system_flex_window(leg                = "down",
#                             piece              = piece,
#                             parameters         = parameters,
#                             simulation_control = simulation_control,
#                             frame              = frame)
# built$piece
# built$refusal
# built$contributors
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - simulation_control$indexes_local$i_flex must be a single row index
#     within the piece, from 2 on: row 1 of a piece is its own
#     initial condition, and the window needs the row before i_flex.
#   - simulation_control$flexibility$commitment_phase_length must be <=
#     commitment_phase_length_max.
#   - simulation_control$flexibility$flexibility must be in (0, 1].
#   - A new window (not restated) whose Commitment, Neutral and Recovery
#     Phases do not fit by i_end_control is refused ("no_room"). The
#     window may end on that row: its last time step ends there.
#   - A restated window (simulation_control$flexibility$restating) is
#     drawn wherever it falls. Only the rows of its Commitment Phase in
#     the guard zone take simulation_control$flexibility$flexibility and
#     the commitment margin; the other rows take
#     simulation_control$flexibility$flexibility_projected and no margin
#     (see derive_flex_itineraries()). It is not checked for
#     convergence at the close of the control horizon.
#   - An upward window with no row in its Commitment Phase has nothing
#     to offer, and is returned as it came in with a NULL refusal.
#   - COMPUTATIONAL COST: each call simulates every asset once over a
#     bounded window (commitment_phase_length + neutral_phase_timespan
#     + recovery_phase_timespan), and once more each time an asset
#     leaves the set and the margin is applied again to the others.
#     It takes one view per asset, in its frame, and does one absorb
#     per contributing asset per call.
#     With a valuation of the Recovery Phase, each asset that
#     contributes and offers alternatives draws its contribution once
#     more for each alternative but the first, and each alternative that
#     changes the electricity is valued (choose_recovery()).
#     The cost of one call does not grow with the optimization
#     horizon. However, evaluate_control()'s nested market-slot loop
#     can call this function O(L^2) times per evaluation (L = number
#     of market slots in the horizon) - see the COMPUTATIONAL COST
#     note in evaluate_control.R's header for the aggregate cost.
# -------------------------------------------------------------

system_flex_window <- function(leg,
                               piece,
                               parameters,
                               simulation_control,
                               recovery_valuation = NULL,
                               frame              = NULL
                               ) {

  # -------------------------------------------------------------
  # 1. The frame of the window
  # The rows, the phases, the piece with the phases written and the
  # operations and view of each asset do not depend on the fraction
  # of flexibility (system_flex_frame()). A caller that builds the
  # same window with several fractions prepares them once and hands
  # them over; otherwise they are prepared here.
  # -------------------------------------------------------------
  {
    if (is.null(frame)) {
      # system_flex_frame is called to prepare the rows and phases of
      # the window, the piece with the phases written, and the
      # operations and view of each asset.
      frame <- system_flex_frame(
        leg                = leg,
        piece              = piece,
        parameters         = parameters,
        simulation_control = simulation_control
      )
    }

    # A window that cannot be built whatever its fraction is answered
    # as the frame says.
    if (!is.null(frame$done)) {
      return(frame$done)
    }

    restating    <- frame$window$restating
    window_piece <- frame$window_piece
  }

  # -------------------------------------------------------------
  # 2. The fraction of flexibility of each row
  # Every row of the Commitment Phase in the guard zone takes the
  # fraction flexibility, and every other row of it takes
  # flexibility_projected, which is flexibility unless the window is
  # restated with a fraction of its own for the rows out of the guard
  # zone (see derive_flex_itineraries()). A restated upward window
  # also says which thermal system each building uses (hvac_up).
  # -------------------------------------------------------------
  {
    flexibility           <- simulation_control$flexibility$flexibility
    flexibility_projected <- simulation_control$flexibility$flexibility_projected
    if (is.null(flexibility_projected)) {
      flexibility_projected <- flexibility
    }

    # What the system hands each asset: the rows and phases of the
    # window, and the time step, guard zone and fraction of each row
    # of its Commitment Phase.
    window <- list(
      i_flex        = frame$window$i_flex,
      rows          = frame$window$rows,
      phase         = frame$window$phase,
      commitment    = frame$window$commitment,
      delta_t_h     = frame$window$delta_t_h,
      guard_row     = frame$window$guard_row,
      fraction_row  = ifelse(frame$window$guard_row, flexibility,
                             flexibility_projected),
      restating     = restating,
      hvac_up       = if (restating) {
        simulation_control$flexibility$hvac_up
      } else {
        NULL
      },
      i_end_control = frame$window$i_end_control
    )

    rm(list = c("flexibility", "flexibility_projected"))
  }

  # -------------------------------------------------------------
  # 3. The contribution of each asset
  # Each asset of the registry drafts its contribution, the system
  # applies the margin of the set to the drafts, and each asset draws
  # its contribution in its own view of the piece (see "The
  # contribution of the assets" and "The margin of the set" above).
  # Sub-blocks:
  #   3.1. The draft of each asset
  #   3.2. The margin of the set and the contributions
  # -------------------------------------------------------------

  # -------------------------------------------------------------
  # 3.1. The draft of each asset
  # An asset that has nothing to offer on the window is left out, and
  # kept apart when it accepts a restated window with no energy.
  # Each asset drafts in its view of the piece, with the phases of the
  # window, taken from the frame. The view is reused for the draft,
  # the contribution and every new application of the margin: what
  # another asset draws changes only the table of that asset and the
  # net of the system, and a view takes the net columns from the table
  # of its own asset, so the view of an asset is the same before and
  # after the others draw.
  # -------------------------------------------------------------
  {
    drafts    <- list()
    models    <- list()
    views     <- list()
    accepting <- character(0)
    for (CONT_001 in names(parameters$assets)) {
      asset <- parameters$assets[[CONT_001]]
      model <- frame$models[[CONT_001]]
      view  <- frame$views[[CONT_001]]

      # The operation window_draft of the model (flex_window_draft()
      # for a building) is called to draft the contribution of the
      # asset to this window, before the margin.
      draft <- model$window_draft(
        leg          = leg,
        period_chunk = view,
        window       = window,
        parameters   = parameters,
        asset        = asset
      )

      if (isTRUE(draft$drawn)) {
        drafts[[CONT_001]] <- draft
        models[[CONT_001]] <- model
        views[[CONT_001]]  <- view
      } else if (isTRUE(draft$accepted)) {
        accepting <- c(accepting, CONT_001)
      }
      rm(list = c("asset", "model", "draft", "view"))
    }
    rm(list = c("CONT_001", "frame"))

    # The rows of the piece in the Commitment Phase, on which the
    # margin is kept and the net commitment is checked.
    commitment_rows <- window$rows[window$commitment]
  }

  # -------------------------------------------------------------
  # 3.2. The margin of the set and the contributions
  # The margin is applied to the assets that remain, and each of them
  # draws its contribution with what it left. When an asset
  # contributes nothing, it leaves the set and the margin is applied
  # again to the others; when none remains, the window is not built.
  # -------------------------------------------------------------
  {
    refusal <- NULL
    repeat {
      if (length(drafts) == 0) {
        return(list(piece = piece, refusal = refusal,
                    contributors = character(0)))
      }

      margined <- list()
      if (any(window$guard_row)) {
        # system_commitment_margin is called to keep the commitment
        # margin of the set on the rows of the guard zone, and, on a
        # new window, the minimum of every market interval.
        margined <- system_commitment_margin(
          margins         = lapply(drafts, `[[`, "margin"),
          market_slot     = window_piece$system$MarketUTC[commitment_rows][window$guard_row],
          delta_t_h       = window$delta_t_h[window$guard_row],
          leg             = leg,
          enforce_minimum = !window$restating,
          parameters      = parameters
        )
      }

      drawn_piece <- window_piece
      left_out    <- character(0)
      for (CONT_002 in names(drafts)) {
        # The operation window_contribution of the model
        # (flex_evaluation() for a building) is called to draw the
        # contribution of the asset to this window in its view, with
        # the rows, phases and fractions the system fixed and the heat
        # the margin left.
        contribution <- models[[CONT_002]]$window_contribution(
          leg          = leg,
          period_chunk = views[[CONT_002]],
          window       = window,
          draft        = drafts[[CONT_002]],
          margined     = margined[[CONT_002]],
          parameters   = parameters,
          asset        = parameters$assets[[CONT_002]]
        )

        if (is.null(contribution$refusal) && isTRUE(contribution$drawn)) {
          # piece_absorb_asset is called to take the contribution drawn
          # in the view back into the table of the asset, and to sum
          # the net electricity of the system again.
          drawn_piece <- piece_absorb_asset(
            piece    = drawn_piece,
            asset_id = CONT_002,
            view     = contribution$chunk
          )
        } else {
          left_out <- c(left_out, CONT_002)
          if (is.null(refusal)) {
            refusal <- contribution$refusal
          }
          if (is.null(contribution$refusal) &&
              isTRUE(contribution$accepted)) {
            accepting <- c(accepting, CONT_002)
          }
        }
        rm(list = "contribution")
      }
      rm(list = "CONT_002")

      if (length(left_out) == 0) {
        break
      }
      rm(list = "margined")
      drafts <- drafts[setdiff(names(drafts), left_out)]
      models <- models[names(drafts)]
    }

    window_piece <- drawn_piece
    contributors <- names(drafts)
    rm(list = c("refusal", "drawn_piece", "left_out"))
  }

  # -------------------------------------------------------------
  # 4. Check the net electricity of an upward window
  # An upward window is an offer only if it actually raises the net
  # electricity of the system during the Commitment Phase. The
  # thermal check of a building looks at the system it raises alone,
  # and that is not enough: the window also switches the other system
  # off, and when the plan was running that other system on backup
  # resistances, at COP 1, the electricity of the Commitment Phase
  # can come out lower than the plan's even though the selected
  # system went to full power. Selling that as upward flexibility
  # would be selling a load reduction at upward prices.
  # -------------------------------------------------------------
  {
    if (leg == "up") {
      # system_net_energy is called for the upward itinerary and for
      # the plan, to compare the net electricity of the system over
      # the Commitment Phase.
      net_up   <- system_net_energy(window_piece$system, "plan_flex_up")
      net_plan <- system_net_energy(window_piece$system, "plan")

      if (sum(net_up[commitment_rows] - net_plan[commitment_rows]) <= 0) {
        return(list(piece = piece, refusal = NULL,
                    contributors = character(0)))
      }

      rm(list = c("net_up", "net_plan"))
    }
  }

  # -------------------------------------------------------------
  # 5. Check the net commitment of every market interval
  # Only for a new window. What each market interval of the
  # Commitment Phase sells is measured as the economic chain measures
  # it, on the net (system_flex_commitment()), added over the rows of
  # the interval. Each interval sells nothing or at least its
  # minimum, and the first and the last sell something (see "The net
  # commitment" above). An energy within flex_energy_tol of zero, or
  # of the minimum, counts as that value.
  # -------------------------------------------------------------
  {
    if (!window$restating) {
      # system_flex_commitment is called to read, row by row, the
      # commitment of the net on this leg.
      committed_row <- system_flex_commitment(
        period_chunk = window_piece$system,
        leg          = leg
      )[commitment_rows]

      # commitment_margin_bound is called to number the market
      # intervals of the Commitment Phase and to give the minimum each
      # of them may sell. Its band is not read here, so it is asked as
      # for the downward leg, with no limit.
      intervals <- commitment_margin_bound(
        limit_energy = numeric(length(commitment_rows)),
        market_slot  = window_piece$system$MarketUTC[commitment_rows],
        delta_t_h    = window$delta_t_h,
        leg          = "down",
        parameters   = parameters
      )
      committed_slot <- vapply(seq_along(intervals$minimum), function(one_slot) {
        sum(committed_row[intervals$slot_id == one_slot], na.rm = TRUE)
      }, numeric(1))

      tol_energy <- parameters$computing$flex_energy_tol
      below      <- committed_slot > tol_energy &
        committed_slot < intervals$minimum - tol_energy
      if (any(below)) {
        # flex_refused is called to check the reason the window is
        # refused and to pair it with the piece, handed back as it came
        # in.
        refused <- flex_refused(
          period_chunk = piece,
          reason       = "below_minimum"
        )
        return(list(piece        = refused$chunk,
                    refusal      = refused$refusal,
                    contributors = character(0)))
      }
      if (length(committed_slot) == 0 ||
          committed_slot[1] <= tol_energy ||
          committed_slot[length(committed_slot)] <= tol_energy) {
        # flex_refused is called to check the reason the window is
        # refused and to pair it with the piece, handed back as it came
        # in.
        refused <- flex_refused(
          period_chunk = piece,
          reason       = "empty_edge"
        )
        return(list(piece        = refused$chunk,
                    refusal      = refused$refusal,
                    contributors = character(0)))
      }
      rm(list = c("committed_row", "intervals", "committed_slot", "tol_energy",
                  "below"))
    }
  }

  # -------------------------------------------------------------
  # 6. Choose the Recovery Phase of the assets that offer alternatives
  # Only when the caller gives a valuation, and only for the assets
  # that contribute and offer alternatives. They drew the window with
  # the first alternative. The alternatives only change the Recovery
  # Phase, so the checks above hold for all of them.
  # Sub-blocks:
  #   6.1. The window drawn with each alternative
  #   6.2. The choice
  # -------------------------------------------------------------

  # -------------------------------------------------------------
  # 6.1. The window drawn with each alternative
  # Each asset draws again from its own view, with its draft and the
  # margin of the last round, and its table replaces the one of the
  # window built. The same alternative is drawn by every one of them.
  # An alternative whose electricity is the one of the first, for
  # every asset, changes nothing that the reward values on the net,
  # and is not valued.
  # -------------------------------------------------------------
  {
    choosing     <- character(0)
    alternatives <- list()
    if (!is.null(recovery_valuation)) {
      choosing <- intersect(contributors, recovery_valuation$choosers)
    }

    if (length(choosing) > 0) {
      leg_electricity <- paste0("Elec_total_plan_flex_", leg)
      tol_energy      <- parameters$computing$flex_energy_tol

      for (CONT_003 in recovery_valuation$choices[-1]) {
        window_alternative          <- window
        window_alternative$recovery <- CONT_003
        piece_alternative           <- window_piece
        changed                     <- FALSE

        for (CONT_004 in choosing) {
          # The operation window_contribution of the model is called
          # to draw the contribution of the asset with this
          # alternative of the Recovery Phase.
          contribution <- models[[CONT_004]]$window_contribution(
            leg          = leg,
            period_chunk = views[[CONT_004]],
            window       = window_alternative,
            draft        = drafts[[CONT_004]],
            margined     = margined[[CONT_004]],
            parameters   = parameters,
            asset        = parameters$assets[[CONT_004]]
          )
          if (!is.null(contribution$refusal) ||
              !isTRUE(contribution$drawn)) {
            stop("system_flex_window: ", CONT_004, " contributed to the ",
                 "window and does not contribute to it with the ",
                 "alternative ", CONT_003, " of the Recovery Phase")
          }

          changed <- changed ||
            max(abs(contribution$chunk[[leg_electricity]] -
                      window_piece$assets[[CONT_004]]$df[[leg_electricity]])
            ) > tol_energy

          # piece_absorb_asset is called to take the contribution
          # drawn with the alternative into the table of the asset,
          # and to sum the net electricity of the system again.
          piece_alternative <- piece_absorb_asset(
            piece    = piece_alternative,
            asset_id = CONT_004,
            view     = contribution$chunk
          )
          rm(list = "contribution")
        }

        if (changed) {
          alternatives[[length(alternatives) + 1]] <- piece_alternative
        }
        rm(list = c("window_alternative", "piece_alternative", "changed",
                    "CONT_004"))
      }
      rm(list = c("leg_electricity", "tol_energy", "CONT_003"))
    }
  }

  # -------------------------------------------------------------
  # 6.2. The choice
  # The piece with the best reward is kept, the first one in a tie.
  # Its commitment has to be the one of the window built, because the
  # alternatives only differ in the Recovery Phase.
  # -------------------------------------------------------------
  {
    if (length(alternatives) > 0) {
      # choose_recovery is called to choose, among the window built and
      # the windows drawn with the other alternatives, the one with the
      # best reward on this leg.
      chosen <- choose_recovery(
        pieces             = c(list(window_piece), alternatives),
        leg                = leg,
        parameters         = parameters,
        recovery_valuation = recovery_valuation
      )

      if (chosen$index > 1) {
        # system_flex_commitment is called to read, row by row, the
        # commitment of the net on this leg in the window built and in
        # the window chosen.
        committed_built <- system_flex_commitment(
          period_chunk = window_piece$system,
          leg          = leg
        )[commitment_rows]
        committed_chosen <- system_flex_commitment(
          period_chunk = alternatives[[chosen$index - 1]]$system,
          leg          = leg
        )[commitment_rows]
        if (any(abs(committed_chosen - committed_built) >
                parameters$computing$flex_energy_tol)) {
          stop("system_flex_window: the choice of the Recovery Phase ",
               "changed the commitment of the window")
        }

        window_piece <- alternatives[[chosen$index - 1]]
        rm(list = c("committed_built", "committed_chosen"))
      }
      rm(list = "chosen")
    }

    rm(list = c("choosing", "alternatives", "drafts", "models", "views",
                "margined"))
  }

  rm(list = c("window", "commitment_rows", "restating"))

  built <- list(piece        = window_piece,
                refusal      = NULL,
                contributors = contributors)
  accepting <- setdiff(accepting, contributors)
  if (length(accepting) > 0) {
    built$empty_contributors <- accepting
  }

  return(built)
}
