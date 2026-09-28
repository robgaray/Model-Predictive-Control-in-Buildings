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
# See 01_Agent_Comments/20260918g_Plan_Compromiso_Vigente.md
# -------------------------------------------------------------
# What this replaces, and why
# initialize_plan_flex_columns() copied _plan over both flexibility
# itineraries and set the commitment to zero, on every candidate of
# every market. Every market therefore began its search as if nothing
# had ever been sold. The reward did know about the standing commitment,
# because resolve_marginal_context() reads it from Main_df before
# optimizing, so undoing it costs money. But the ITINERARY the search worked on
# started at zero, so the optimizer had to pay its way back to where it
# already was. On a flat optimum that is enough for the answer to flip
# from one market to the next, which is the compulsive rebuy measured at
# 91 per cent of the downward leg and -51.50 EUR.
# Here the standing commitment is the starting point instead.
# -------------------------------------------------------------
# How a standing window is held over a new plan
# The commitment is stored in kilowatt hours of electricity, and what
# the window builders take is a thermal profile. Rather than invert the
# electrical model - which is piecewise and underdetermined, since one
# electricity figure does not say how much came from each machine -
# this function solves for the one number the window was built from.
# Both flex_evaluation_down() and flex_evaluation_up() are parameterised
# by a single flexibility fraction in (0, 1], and the electricity a
# window commits grows monotonically with it. So for each standing
# window the fraction is found by bisection, calling the repository's
# own builder at each step, until the electricity it commits matches
# what was sold.
# That buys three things at once. The Neutral and Recovery Phases come
# out built by the same code that built them originally, with the same
# power caps and the same convergence check. The itinerary is derived
# from the NEW plan, as the criterion asks. And infeasibility falls out
# on its own: when even a fraction of one cannot reach the committed
# energy, the new plan cannot sustain what was sold.
# -------------------------------------------------------------
# Inputs
#   period_chunk       : Data frame with the _plan itinerary already
#                        simulated, and carrying the standing commitment
#                        in Elec_flex_down_plan / Elec_flex_up_plan as
#                        it came from Main_df.
#   parameters         : Named list. Model and control parameters.
#   simulation_control : Named list, as the window builders expect.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     period_chunk : the chunk with both flexibility itineraries built,
#                    their phases marked and their commitment set.
#     feasible     : Logical. FALSE when some standing window cannot be
#                    sustained over the new plan AND this market's aim
#                    is operation alone, so it has no way to give the
#                    part it cannot hold back to the market.
# -------------------------------------------------------------
# Code outline
# 1. Take the standing commitment and lay the baseline
# 2. Hold each standing window over the new plan
# -------------------------------------------------------------
# Usage instructions
# derived <- derive_flex_itineraries(period_chunk, parameters, simulation_control)
# -------------------------------------------------------------
# Where this function/script is used
# Called by evaluate_control(), in place of
# initialize_plan_flex_columns(), and by run_market_process(), which
# re-derives the itineraries of the accepted plan before valuing it.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - With no standing commitment the result is exactly what
#     initialize_plan_flex_columns() produced: both itineraries equal to
#     _plan, phases and commitment at zero. That is what makes the
#     change conservative wherever there is no flexibility.
#   - A window the builder refuses because it would raise both systems
#     is reported as infeasible rather than silently dropped. The
#     reward's feasibility term is what prices it. The other three
#     refusals say the builder would not draw the window here, which is
#     no reason to throw away energy already sold: the commitment is
#     held as it stands and the next market rebuilds it.
#   - A standing window that no longer fits, once the commitment margin
#     has been taken out of the new plan, is RE-SOLD: it is re-stated at
#     the most the margin allows and the difference is booked as a
#     re-purchase. Every aim may do this except the purely operational
#     one, which is the only one that still reports the window as
#     infeasible. See apply_commitment_margin() and
#     market_can_trade_flex().
#   - The bisection is bounded to a fixed number of steps. It is solving
#     one monotone scalar equation, so a few tens of steps take it far
#     below the energy tolerance of the model.
# -------------------------------------------------------------
# functions/scripts called
#   reconstruct_flex_phases() - finds the standing windows in the
#     committed energy, on the market-slot grid
#   flex_evaluation_down(), flex_evaluation_up() - build a window from a
#     flexibility fraction, with their phases, caps and convergence
#   market_can_trade_flex() - whether this market may trade flexibility
#     to keep its itineraries inside the commitment margin
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

    feasible <- TRUE

    if (all(vapply(standing, function(one_leg) {
      is.null(one_leg) || all(is.na(one_leg)) ||
        all(abs(one_leg[!is.na(one_leg)]) <= parameters$computing$flex_energy_tol)
    }, logical(1)))) {
      return(list(period_chunk = period_chunk, feasible = TRUE))
    }
  }

  # 2. Hold each standing window over the new plan
  # -------------------------------------------------------------
  {
    # Whether this market can give back part of a commitment it can no
    # longer hold. Every aim can except the purely operational one, so
    # an energy market, which is the family that moves the planned
    # itinerary and therefore the one that most often leaves a standing
    # window unsustainable, gives the part that no longer fits back to
    # the market instead of breaking it. The answer decides both
    # whether the commitment margin is demanded of the re-statement
    # (flex_evaluation_up/down ask the same question) and what happens
    # when the margin leaves the window short of what was sold.
    can_retrade_flex <- market_can_trade_flex(parameters$control$optimization_aim)

    market_slot_h <- parameters$market$market_resolution / 60
    tol_energy    <- parameters$computing$flex_energy_tol
    tol_restate   <- parameters$control$flex_restatement_tol
    bisection_steps <- 12

    for (one_leg in c("down", "up")) {

      committed_col <- paste0("Elec_flex_", one_leg, "_plan")
      evaluate_leg  <- if (one_leg == "down") flex_evaluation_down else flex_evaluation_up

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
        target      <- sum(standing[[one_leg]][window_rows], na.rm = TRUE)
        if (!is.finite(target) || abs(target) <= tol_energy) next

        control_here <- simulation_control
        control_here$indexes_local$i_flex <- window_rows[1]
        control_here$flexibility$commitment_phase_length <-
          length(unique(period_chunk$MarketUTC[window_rows])) * market_slot_h

        # This is a RE-STATEMENT of a commitment already sold, not a new
        # sale, and the builder is told so: it then asks only that the
        # Commitment Phase fit the control horizon, because the tail of
        # a standing window is meant to fall beyond it.
        control_here$flexibility$restating <- TRUE

        # committed_by returns the electricity a given fraction commits
        # on this window, over the NEW plan, or NA when the builder
        # refuses the window, with the reason it gave. The reason is
        # read from the tag flex_refused() leaves, never from the
        # rebuilt phase: from the second window of a leg onwards the
        # chunk already carries the phases of the earlier ones, so a
        # refusal does not show up as a phase of zeros and used to pass
        # unnoticed.
        committed_by <- function(fraction) {
          control_here$flexibility$flexibility <- fraction
          built <- evaluate_leg(period_chunk       = period_chunk,
                                parameters         = parameters,
                                simulation_control = control_here)
          refusal <- attr(built, "flex_refusal")
          if (!is.null(refusal)) {
            return(list(value = NA_real_, chunk = built, refusal = refusal))
          }
          rebuilt_phase <- built[[paste0("Flex_phase_", one_leg, "_plan")]]
          if (all(rebuilt_phase == 0L)) {
            return(list(value = NA_real_, chunk = built, refusal = "not_built"))
          }

          # Only THIS window's rows count. The chunk carries the phases
          # of the windows already re-stated on this leg, so summing over
          # every row marked 1 added their commitment to this one and the
          # bisection then drove the fraction down until the total, not
          # the window, matched the target. The window is the stretch of
          # phase 1 that contains the row it starts at.
          own <- rebuilt_phase == 1L
          if (!own[window_rows[1]]) {
            return(list(value = NA_real_, chunk = built, refusal = "not_built"))
          }
          runs        <- rle(own)
          run_ends    <- cumsum(runs$lengths)
          run_starts  <- run_ends - runs$lengths + 1
          this_run    <- which(run_starts <= window_rows[1] & run_ends >= window_rows[1])
          own_rows    <- run_starts[this_run]:run_ends[this_run]

          commitment <- if (one_leg == "down") {
            sum((built$Elec_total_plan - built$Elec_total_plan_flex_down)[own_rows],
                na.rm = TRUE)
          } else {
            sum(pmax(built$Elec_total_plan_flex_up - built$Elec_total_plan, 0)[own_rows],
                na.rm = TRUE)
          }
          list(value = commitment, chunk = built, refusal = NULL)
        }

        # The largest fraction is tried first: if even that one cannot
        # reach what was sold, the new plan does not sustain the
        # commitment and there is nothing to bisect.
        highest <- committed_by(1)

        # A refusal is not the same thing as an impossible commitment,
        # and only one of the four reasons is. Opposed systems is the
        # case the feasibility rule was written for, and it is declared
        # to the reward. The other three say the builder would not draw
        # the window here, which is no reason to throw away energy that
        # was already sold: the commitment is held as it stands and the
        # next market rebuilds it.
        if (!is.null(highest$refusal)) {
          if (identical(highest$refusal, "opposed_systems")) {
            feasible <- FALSE
          } else {
            period_chunk <- hold_standing_window(period_chunk, one_leg,
                                                 window_rows, standing[[one_leg]])
          }
          next
        }

        # The most the new plan can hold, once the commitment margin has
        # been taken out of it, is below what was sold. What to do about
        # it depends on whether this market can trade flexibility.
        #
        # It can: the shortfall is RE-SOLD rather than breached. The
        # window is re-stated at the most the margin allows, and the
        # difference shows up as a smaller Elec_flex_*_plan, which
        # integrate_market_process() books as a re-purchase against the
        # earlier sale. Giving back the part that no longer fits is an
        # ordinary market operation with a price; breaking it is not.
        #
        # It cannot, which now means only a market whose aim is
        # operation alone: there is no way to unwind anything there, so
        # the old reading stands and the commitment is declared broken.
        if (highest$value < target - tol_restate) {
          if (can_retrade_flex) {
            period_chunk <- highest$chunk
          } else {
            feasible <- FALSE
          }
          next
        }

        low  <- 0
        high <- 1
        best <- highest

        for (CONT_003 in seq_len(bisection_steps)) {
          middle  <- (low + high) / 2
          attempt <- committed_by(middle)
          if (is.na(attempt$value) || attempt$value < target) {
            low <- middle
          } else {
            high <- middle
            best <- attempt
          }
          # The convergence test is against flex_restatement_tol, the
          # energy the re-statement is allowed to miss by. It used to be
          # flex_energy_tol, 1e-9 kWh, which twelve halvings of a
          # fraction cannot reach, so the loop always ran its twelve
          # iterations and the test never did anything.
          if (!is.na(attempt$value) && abs(attempt$value - target) <= tol_restate) {
            # Stopping early must not make the re-statement worse than it
            # already was: of the two candidates in hand, the one closer
            # to what was sold is kept.
            if (is.na(best$value) ||
                abs(attempt$value - target) < abs(best$value - target)) {
              best <- attempt
            }
            break
          }
        }

        period_chunk <- best$chunk
      }
    }
  }

  rm(standing, market_slot_h, tol_energy, tol_restate, bisection_steps,
     can_retrade_flex)

  return(list(period_chunk = period_chunk, feasible = feasible))
}
