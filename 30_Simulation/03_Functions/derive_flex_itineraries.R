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
# commitment, because resolve_marginal_context() reads it from Main_df
# before optimizing, so undoing it costs money. But the ITINERARY
# the search works on would start at zero, so the optimizer would have
# to pay its way back to where it already was. On a flat optimum that
# is enough for the answer to flip from one market to the next, selling
# and rebuying the same commitment again and again.
# Here the standing commitment is the starting point instead.
# -------------------------------------------------------------
# How a standing window is held over a new plan
# The commitment is stored in kilowatt hours of electricity, and what
# the window builders take is a thermal profile. Rather than invert the
# electrical model - which is piecewise and underdetermined, since one
# electricity figure does not say how much came from each machine -
# this function solves for the one number the window was built from.
# Both flex_evaluation_down() and flex_evaluation_up() are parameterised
# by a flexibility fraction in (0, 1], and the electricity a window
# commits grows monotonically with it. So for each standing window the
# fraction is found by bisection, calling the repository's own builder
# at each step, until the electricity it commits matches what was sold.
# The Neutral and Recovery Phases then come out built by the same code
# that built them originally, with the same power caps, and over the
# NEW plan.
# -------------------------------------------------------------
# Projection and guard zone
# Every row of a Commitment Phase is restated in one of two ways,
# depending on where it falls, whatever the aim of the market:
#   - Guard zone: rows inside the market interval, from the start of
#     the chunk to i_end_control, when the restatement mode is "guard".
#     This market trades those rows, so the commitment margin is
#     demanded of them. When the new plan cannot hold what was sold
#     with the margin, the window is restated at the most the margin
#     allows, and the difference shows up as a smaller commitment,
#     which the economic chain books as a re-purchase. This is the only
#     flexibility a market whose aim is operation alone ever trades.
#   - Projection: every other row, and every row when the restatement
#     mode is "projection". No market trades those rows here: earlier
#     markets did, and later markets or the execution will. The window
#     is drawn as the new plan allows, with no margin and no judgement
#     of its feasibility, and the commitment sold there is not changed.
# A window whose Commitment Phase crosses a limit of the market
# interval is split: each part takes its own fraction.
# -------------------------------------------------------------
# Inputs
#   period_chunk       : Data frame with the _plan itinerary already
#                        simulated, and carrying the standing commitment
#                        in Elec_flex_down_plan / Elec_flex_up_plan as
#                        it came from Main_df.
#   parameters         : Named list. Model and control parameters.
#   simulation_control : Named list, as the window builders expect.
#                        Reads:
#                        indexes_local$i_end_control - last row of the
#                          market interval in this chunk.
#                        flexibility$restatement_mode - "guard"
#                          (default) or "projection", see above.
#                        flexibility$pre_horizon_tail - when present,
#                          one entry per leg (down, up) for a window
#                          whose Commitment Phase started before this
#                          chunk, as run_market_process() builds it:
#                            rows   - rows of this chunk it occupies.
#                            phases - its phase code on those rows.
#                            state  - one-row data frame. The state of
#                                     its flexibility itinerary on row 1.
#                            system - the system that provides it.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     period_chunk : the chunk with both flexibility itineraries built,
#                    their phases marked and the commitment they carry
#                    written in Elec_flex_down_plan / Elec_flex_up_plan.
#     feasible     : Logical. FALSE when a window with rows in the guard
#                    zone could not be drawn because it would raise both
#                    thermal systems. The window is then held as it
#                    stands (hold_standing_window()), nothing is
#                    re-purchased, and the caller reports it.
# -------------------------------------------------------------
# Code outline
# 1. Take the standing commitment and lay the baseline
# 2. Restate each standing window over the new plan
# 3. Write the commitment the itineraries carry
# -------------------------------------------------------------
# Usage instructions
# derived <- derive_flex_itineraries(period_chunk, parameters, simulation_control)
# -------------------------------------------------------------
# Where this function/script is used
#   - evaluate_control()
#   - run_market_process()
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - With no standing commitment both itineraries are equal to _plan,
#     with phases and commitment at zero.
#   - The commitment is written here, from the itineraries just drawn,
#     with the definition reward_function() uses: the difference with
#     the plan over the Commitment Phase. A market that places no new
#     window, or whose aim does not value flexibility, therefore keeps
#     the commitment it restated instead of losing it.
#   - Row 1 of the chunk is the initial state of the simulation and is
#     never simulated, so it carries no commitment of its own and is
#     left out of what each window has to reach.
#   - A window whose Commitment Phase ended before this chunk has only
#     its Neutral and Recovery Phases left in it. They are continued
#     over the plan of this chunk by continue_standing_tail(), from the
#     state handed over on row 1.
#   - A window whose Commitment Phase started before this chunk and
#     runs into it is rebuilt from row 1, where the state of its
#     itinerary is handed over, so it continues the part the earlier
#     stretch projected.
#   - The builder may refuse a window. A refusal says the builder would
#     not draw the window here, which is no reason to throw away energy
#     already sold: the commitment is held as it stands and the next
#     market rebuilds it. A refusal because the window would raise both
#     systems is also reported through feasible when the window has
#     rows in the guard zone.
#   - The bisection is bounded to a fixed number of steps. It is solving
#     one monotone scalar equation, so a few tens of steps take it far
#     below the energy tolerance of the model.
# -------------------------------------------------------------
# functions/scripts called
#   reconstruct_flex_phases() - finds the standing windows in the
#     committed energy, on the market-slot grid
#   continue_standing_tail() - continues the Neutral and Recovery
#     Phases of a window that started before this chunk
#   flex_evaluation_down(), flex_evaluation_up() - build a window from
#     its flexibility fractions, with their phases and caps
#   hold_standing_window() - carries a window forward unchanged when
#     the builder refuses to draw it here
# -------------------------------------------------------------

derive_flex_itineraries <- function(period_chunk, parameters, simulation_control) {

  # 1. Take the standing commitment and lay the baseline
  # -------------------------------------------------------------
  {
    standing <- list(
      down = period_chunk$Elec_flex_down_plan,
      up   = period_chunk$Elec_flex_up_plan
    )

    plan_cols <- grep("_plan$", names(period_chunk), value = TRUE)
    for (CONT_001 in plan_cols) {
      period_chunk[[paste0(CONT_001, "_flex_down")]] <- period_chunk[[CONT_001]]
      period_chunk[[paste0(CONT_001, "_flex_up")]]   <- period_chunk[[CONT_001]]
    }
    rm(plan_cols, CONT_001)

    period_chunk$Flex_phase_down_plan <- 0
    period_chunk$Flex_phase_up_plan   <- 0
    period_chunk$Elec_flex_down_plan  <- 0
    period_chunk$Elec_flex_up_plan    <- 0

    restatement_mode <- simulation_control$flexibility$restatement_mode
    if (is.null(restatement_mode)) {
      restatement_mode <- "guard"
    }
    if (!restatement_mode %in% c("guard", "projection")) {
      stop("derive_flex_itineraries: restatement_mode must be 'guard' or ",
           "'projection'")
    }

    # A window whose Commitment Phase started before this chunk left its
    # itinerary in some state at row 1. That state is written there, so
    # that whatever is simulated of the window in this chunk starts from
    # it and not from the plan's.
    held_tail <- simulation_control$flexibility$pre_horizon_tail
    for (CONT_004 in names(held_tail)) {
      tail_state <- held_tail[[CONT_004]]$state
      period_chunk[1, names(tail_state)] <- tail_state
      rm(tail_state)
    }

    feasible <- TRUE

    nothing_standing <- all(vapply(standing, function(one_leg) {
      is.null(one_leg) || all(is.na(one_leg)) ||
        all(abs(one_leg[!is.na(one_leg)]) <= parameters$computing$flex_energy_tol)
    }, logical(1)))

    if (nothing_standing && length(held_tail) == 0) {
      return(list(period_chunk = period_chunk, feasible = TRUE))
    }
    rm(nothing_standing)
  }

  # 2. Restate each standing window over the new plan
  # -------------------------------------------------------------
  {
    i_end_control <- simulation_control$indexes_local$i_end_control
    if (is.null(i_end_control) || !is.numeric(i_end_control)) {
      stop("derive_flex_itineraries: simulation_control$indexes_local$",
           "i_end_control is mandatory when there is a commitment to restate")
    }

    market_slot_h   <- parameters$market$market_resolution / 60
    tol_energy      <- parameters$computing$flex_energy_tol
    tol_restate     <- parameters$control$flex_restatement_tol
    bisection_steps <- 12

    for (one_leg in c("down", "up")) {

      committed_col <- paste0("Elec_flex_", one_leg, "_plan")
      evaluate_leg  <- if (one_leg == "down") flex_evaluation_down else flex_evaluation_up
      tail          <- held_tail[[one_leg]]
      tail_commits  <- !is.null(tail) && any(tail$phases == 1L)

      # continue_standing_tail is called when the window that started
      # before this chunk has only its Neutral and Recovery Phases left
      # here.
      if (!is.null(tail) && !tail_commits) {
        period_chunk <- continue_standing_tail(period_chunk, one_leg, tail, parameters)
      }

      # reconstruct_flex_phases is called on a copy carrying the
      # standing commitment, because the baseline above has already
      # zeroed the column it reads.
      standing_chunk <- period_chunk
      standing_chunk[[committed_col]] <- standing[[one_leg]]
      phase <- reconstruct_flex_phases(standing_chunk, one_leg, parameters)
      rm(standing_chunk)

      if (!any(phase == 1L)) next

      stretches <- rle(phase == 1L)
      ends      <- cumsum(stretches$lengths)
      starts    <- ends - stretches$lengths + 1

      for (CONT_002 in which(stretches$values)) {

        window_rows <- starts[CONT_002]:ends[CONT_002]

        # The Commitment Phase that runs on from before this chunk is
        # rebuilt from row 1, where the state of its itinerary is.
        if (tail_commits && window_rows[1] <= min(tail$rows)) {
          window_rows <- seq_len(ends[CONT_002])
        }

        # Row 1 is never simulated, so it counts for no window. The rest
        # of the Commitment Phase is split between the guard zone and
        # the projection.
        counted_rows   <- window_rows[window_rows > 1]
        guard_rows     <- if (restatement_mode == "guard") {
          counted_rows[counted_rows <= i_end_control]
        } else {
          integer(0)
        }
        projected_rows <- setdiff(counted_rows, guard_rows)

        target <- c(guard     = sum(standing[[one_leg]][guard_rows], na.rm = TRUE),
                    projected = sum(standing[[one_leg]][projected_rows], na.rm = TRUE))
        if (any(!is.finite(target)) || sum(abs(target)) <= tol_energy) next

        control_here <- simulation_control
        control_here$indexes_local$i_flex <- window_rows[1]
        control_here$flexibility$commitment_phase_length <-
          length(unique(period_chunk$MarketUTC[window_rows])) * market_slot_h

        # This is a RE-STATEMENT of a commitment already sold, not a new
        # sale, and the builder is told so, together with the mode that
        # decides which of its rows are in the guard zone.
        control_here$flexibility$restating        <- TRUE
        control_here$flexibility$restatement_mode <- restatement_mode

        # committed_by returns the electricity the window commits, over
        # the NEW plan, in its guard rows and in its projected rows, for
        # a fraction of each part; or NA when the builder refuses the
        # window, with the reason it gave. The reason is read from the
        # tag flex_refused() leaves, never from the rebuilt phase: from
        # the second window of a leg onwards the chunk already carries
        # the phases of the earlier ones, so a refusal does not show up
        # as a phase of zeros. The builds are kept, because the final
        # pair of fractions has always been tried during the search.
        builds <- list()
        committed_by <- function(fraction_guard, fraction_projected) {
          key <- paste(fraction_guard, fraction_projected)
          if (!is.null(builds[[key]])) return(builds[[key]])

          control_here$flexibility$flexibility           <- fraction_guard
          control_here$flexibility$flexibility_projected <- fraction_projected
          built <- evaluate_leg(period_chunk       = period_chunk,
                                parameters         = parameters,
                                simulation_control = control_here)
          refusal <- attr(built, "flex_refusal")
          rebuilt_phase <- built[[paste0("Flex_phase_", one_leg, "_plan")]]
          if (is.null(refusal) && !any(rebuilt_phase[window_rows] == 1L)) {
            refusal <- "not_built"
          }

          answer <- if (!is.null(refusal)) {
            list(guard = NA_real_, projected = NA_real_, chunk = built, refusal = refusal)
          } else {
            # Only THIS window's rows count. The chunk carries the phases
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

            difference <- if (one_leg == "down") {
              built$Elec_total_plan - built$Elec_total_plan_flex_down
            } else {
              pmax(built$Elec_total_plan_flex_up - built$Elec_total_plan, 0)
            }
            list(guard     = sum(difference[intersect(own_rows, guard_rows)], na.rm = TRUE),
                 projected = sum(difference[intersect(own_rows, projected_rows)], na.rm = TRUE),
                 chunk     = built,
                 refusal   = NULL)
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

        # The largest fractions are tried first: they say whether the new
        # plan can reach what was sold at all.
        highest <- committed_by(1, 1)

        if (!is.null(highest$refusal)) {
          if (identical(highest$refusal, "opposed_systems") && length(guard_rows) > 0) {
            feasible <- FALSE
          }
          # hold_standing_window is called to carry the commitment
          # forward as it stands.
          period_chunk <- hold_standing_window(period_chunk, one_leg,
                                               counted_rows, standing[[one_leg]])
          rm(builds, committed_by, bisect, highest)
          next
        }

        # Projection: the fraction that reaches what was sold, or the
        # largest one when even that falls short. The commitment there
        # is not changed: it is drawn as the new plan allows.
        fraction_projected <- 1
        if (length(projected_rows) > 0 &&
            highest$projected >= target[["projected"]] - tol_restate) {
          fraction_projected <- bisect(function(fraction) committed_by(1, fraction)$projected,
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
            fraction_guard <- bisect(function(fraction) committed_by(fraction, fraction_projected)$guard,
                                     target[["guard"]], at_one)
          }
          rm(at_one)
        }

        restated     <- committed_by(fraction_guard, fraction_projected)
        period_chunk <- if (is.null(restated$refusal)) restated$chunk else highest$chunk

        rm(builds, committed_by, bisect, highest, restated,
           fraction_guard, fraction_projected)
      }
    }
  }

  # 3. Write the commitment the itineraries carry
  # -------------------------------------------------------------
  # The same definition as reward_function(): downward, what the
  # itinerary spends below the plan; upward, what it spends above it;
  # both over the Commitment Phase alone.
  # -------------------------------------------------------------
  {
    period_chunk$Elec_flex_down_plan <-
      (period_chunk$Elec_total_plan - period_chunk$Elec_total_plan_flex_down) *
      (period_chunk$Flex_phase_down_plan == 1)
    period_chunk$Elec_flex_up_plan <-
      pmax(period_chunk$Elec_total_plan_flex_up - period_chunk$Elec_total_plan, 0) *
      (period_chunk$Flex_phase_up_plan == 1)
  }

  rm(standing, market_slot_h, tol_energy, tol_restate, bisection_steps,
     held_tail, restatement_mode, i_end_control)

  return(list(period_chunk = period_chunk, feasible = feasible))
}
