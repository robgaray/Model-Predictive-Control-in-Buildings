# -------------------------------------------------------------
# Function: flex_evaluation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Draws the contribution of a building to one flexibility window of
# the system, of one leg, downward or upward. It is the operation
# window_contribution of the type of model Building
# (model_type_contract()).
# The system fixes the window (system_flex_window()): its rows, its
# three phases, and the time step, guard zone and fraction of
# flexibility of each row of its Commitment Phase. The building drafts
# its profile of the Commitment Phase over them (flex_window_draft()),
# and the system applies to the drafts of all the assets the
# commitment margin of the set (system_commitment_margin()). With the
# heat the margin left, this function puts together the heating and
# cooling of the building during the Commitment Phase
# (flex_margined_profile()), simulates the Commitment, Neutral and
# Recovery Phases, writes the itinerary of the leg back into the
# period chunk, and keeps the contribution only if the building
# converges back to its plan and the window is a service the building
# can render. Whether the window is sold is decided by the system, on
# the net of the contributions of all the assets.
# -------------------------------------------------------------
# The two legs
# Both legs are drawn over the same window, with the same simulation
# and the same checks, so that their results are comparable. Two
# things differ, and each lives in its own function:
#   - The profile of the Commitment Phase, flex_commitment_profile()
#     and flex_margined_profile(). The downward leg reduces heating
#     and cooling towards zero; the upward leg raises one system
#     towards its maximum power and switches the other one off.
#   - The system that provides the contribution. The upward leg needs
#     it before it can draw anything, and the draft of the building
#     already holds it (flex_window_draft()). The downward leg
#     switches off whatever runs, so it only needs the system for the
#     lock of the Recovery Phase, and resolve_flex_down_hvac() reads
#     it from the Commitment Phase once it is drawn.
# -------------------------------------------------------------
# The technical rules of the building
# The building keeps its contribution only if it keeps the rules of
# its type, checked within the building:
#   - its itinerary converges back to its plan by the close of the
#     control horizon (check_recovery_convergence()), for a new
#     window ("no_convergence");
#   - the windows of the leg do not raise the electricity of both its
#     thermal systems over the plan (flex_window_is_feasible())
#     ("opposed_hvac");
#   - during the Recovery Phase, the system that did not provide the
#     service may only hold or reduce its power
#     (build_hvac_lock_caps()).
# -------------------------------------------------------------
# Inputs
#   leg          : Character scalar, "down" or "up". The leg the
#                  window belongs to.
#   period_chunk : Data frame. Planning-period data, with the phases
#                  of the window already written by the system. Must
#                  contain the *_plan columns produced by
#                  period_calculation() with calculation_context =
#                  "plan", and the *_plan_flex_<leg> baseline columns,
#                  initialized by derive_flex_itineraries().
#   window       : Named list. The window the system fixed, as
#                  system_flex_window() builds it:
#                    - i_flex: the first row of the Commitment Phase
#                    - rows: the rows of period_chunk the window
#                      spans, its initial condition first
#                    - phase: the phase code of each of those rows (0
#                      for the initial condition, 1 Commitment,
#                      2 Neutral, 3 Recovery)
#                    - commitment: the positions, within rows, of the
#                      rows of the Commitment Phase
#                    - delta_t_h: the time step of each of those rows,
#                      in hours
#                    - guard_row: TRUE for each of those rows in the
#                      guard zone
#                    - fraction_row: the fraction of flexibility of
#                      each of those rows, in (0, 1]
#                    - restating: TRUE when the window restates a
#                      commitment already sold
#                    - hvac_up: NULL, or a list named by asset_id
#                      with "heat" or "cool", the system of each
#                      building for a restated upward window, chosen
#                      by the caller
#                    - i_end_control: the last row of the control
#                      horizon in period_chunk
#   draft        : Named list. The draft of the building for this
#                  window, as flex_window_draft() gives it. Reads
#                  hvac_used, the system of an upward window, and
#                  profile, the profile of the Commitment Phase before
#                  the margin.
#   margined     : Named list or NULL. The heat of the rows of the
#                  guard zone after the commitment margin of the set,
#                  list(Q_heat, Q_cool), as system_commitment_margin()
#                  gives it for the building. NULL when no row is in
#                  the guard zone.
#   parameters   : Named list. Model and control parameters. Reads
#                  what check_recovery_convergence() and
#                  flex_window_is_feasible() read.
#   asset        : Named list. The parameters of the building, its
#                  entry of parameters$assets. Read by
#                  period_calculation(), and handed to
#                  flex_window_is_feasible().
# -------------------------------------------------------------
# Outputs
#   A named list with:
#   chunk   : Data frame. The input data frame with the
#             *_plan_flex_<leg> columns updated over the rows of the
#             window after its initial condition. A contribution that
#             is not drawn is returned as it came in.
#   refusal : Character scalar or NULL. The reason the building
#             refuses the window, one of those of flex_refused(), when
#             its contribution breaks a rule of the building. NULL
#             otherwise.
#   drawn   : Logical scalar. TRUE when the building contributes to
#             the window. FALSE when it has nothing to offer on it (a
#             new upward window that raises nothing) or refuses it.
# -------------------------------------------------------------
# Code outline
# 1. Read the window
# 2. The system of an upward window
# 3. Take the rows of the window
# 4. Draw the Commitment Phase
# 5. Write the phases fixed by the system
# 6. Select the system of a downward window
# 7. Simulate the window
# 8. Write the contribution back into period_chunk
# 9. Keep or refuse the contribution
# -------------------------------------------------------------
# Usage instructions
# Called by system_flex_window(), through the operation
# window_contribution of the model of the building:
# contribution <- flex_evaluation(leg          = "down",
#                                 period_chunk = view,
#                                 window       = window,
#                                 draft        = draft,
#                                 margined     = margined,
#                                 parameters   = parameters,
#                                 asset        = asset)
# contribution$chunk
# contribution$refusal
# contribution$drawn
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - A restated upward window is drawn with the system the caller
#     hands in, when it hands one in (see flex_window_draft()). The
#     prudence rule of resolve_flex_up_hvac() decides whether a NEW
#     upward window is sold; a window already sold is not dropped
#     because that rule is undecided.
#   - A restated window is not checked for convergence at the close of
#     the control horizon: its tail may run past it, and the next
#     market rebuilds it.
#   - During the Recovery Phase the system that did not provide the
#     flexibility service may only hold or reduce its power, never
#     increase it. The restriction is imposed step by step, through
#     calculation_mode 3, so that the bound of every step propagates to
#     the state the next step decides on. It corresponds to an
#     interpretation of the legal regulation of HVAC systems, which
#     does not allow energy management through the alternating use of
#     heating and cooling. See build_hvac_lock_caps().
# -------------------------------------------------------------
flex_evaluation <- function(leg,
                            period_chunk,
                            window,
                            draft,
                            margined,
                            parameters,
                            asset) {

  # -------------------------------------------------------------
  # 1. Read the window
  # The leg and the names of the columns of the leg.
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 || !leg %in% c("down", "up")) {
      stop("flex_evaluation: leg must be \"down\" or \"up\"")
    }

    # The itinerary of the leg is every column ending in leg_suffix,
    # and its phases are in phase_col.
    leg_suffix <- paste0("_plan_flex_", leg)
    phase_col  <- paste0("Flex_phase_", leg, "_plan")
  }

  # -------------------------------------------------------------
  # 2. The system of an upward window
  # The draft of the building chose it (flex_window_draft()). The
  # downward leg selects its system in block 6.
  # -------------------------------------------------------------
  {
    hvac_used <- if (leg == "up") draft$hvac_used else NULL
  }

  # -------------------------------------------------------------
  # 3. Take the rows of the window
  # The rows the system fixed. They are taken column by column: a
  # data frame subset through `[` also rebuilds the row names and
  # checks every column, which costs more than the copy itself, and
  # nothing downstream reads the row names.
  # -------------------------------------------------------------
  {
    subset_rows <- window$rows

    period_chunk_subset <- structure(
      lapply(period_chunk, `[`, subset_rows),
      names     = names(period_chunk),
      class     = "data.frame",
      row.names = c(NA_integer_, -length(subset_rows))
    )
  }

  # -------------------------------------------------------------
  # 4. Draw the Commitment Phase
  # The heat of both systems over the rows of the Commitment Phase:
  # the profile the building drafted, with the heat the commitment
  # margin of the set left on the rows of the guard zone. NULL means
  # that a new upward window raises nothing, and the chunk is then
  # returned as it came in.
  # -------------------------------------------------------------
  {
    flex_rows_subset <- window$commitment

    if (length(flex_rows_subset) > 0) {
      # flex_margined_profile is called to put together the heating
      # and cooling of the Commitment Phase of this leg, with the heat
      # the margin left on the rows of the guard zone.
      profile <- flex_margined_profile(
        leg         = leg,
        profile     = draft$profile,
        margined    = margined,
        guard_row   = window$guard_row,
        hvac_used   = hvac_used,
        Q_heat_plan = period_chunk_subset$Q_heat_plan[flex_rows_subset],
        Q_cool_plan = period_chunk_subset$Q_cool_plan[flex_rows_subset],
        restating   = window$restating
      )
      if (is.null(profile)) {
        return(list(chunk = period_chunk, refusal = NULL, drawn = FALSE))
      }

      period_chunk_subset[[paste0("Q_heat", leg_suffix)]][flex_rows_subset] <- profile$Q_heat
      period_chunk_subset[[paste0("Q_cool", leg_suffix)]][flex_rows_subset] <- profile$Q_cool
      rm(list = "profile")
    }
    rm(list = "flex_rows_subset")
  }

  # -------------------------------------------------------------
  # 5. Write the phases fixed by the system
  # The rows of the window take the phase codes of the system, the
  # initial condition 0. The simulation reads them to measure the
  # itinerary against the occupancy band inside the window, and the
  # lock of the Recovery Phase to find its rows.
  # -------------------------------------------------------------
  {
    period_chunk_subset[[phase_col]] <- window$phase
  }

  # -------------------------------------------------------------
  # 6. Select the system of a downward window
  # The downward leg switches off whatever runs, so its system is the
  # one that ran during the Commitment Phase just marked. It is only
  # needed for the lock of the Recovery Phase.
  # -------------------------------------------------------------
  {
    if (leg == "down") {
      # resolve_flex_down_hvac is called to read which system the
      # downward window takes its flexibility from.
      hvac_used <- resolve_flex_down_hvac(period_chunk_subset)
    }
  }

  # -------------------------------------------------------------
  # 7. Simulate the window
  # The first row is the initial condition, which period_calculation()
  # does not recompute. The calculation mode of every other row:
  #   2 (Heat Input)         the Commitment and Neutral Phases, where
  #                          the power of every step is imposed
  #   3 (Setpoint with cap)  the Recovery Phase, where the thermostat
  #                          decides again but the system that was not
  #                          used to provide the service may only hold
  #                          or reduce its power - see
  #                          build_hvac_lock_caps()
  # -------------------------------------------------------------
  {
    calculation_mode_vec <- ifelse(window$phase == 3L, 3L, 2L)

    # build_hvac_lock_caps is called to bound the other system during
    # the Recovery Phase. The caps are read from the _plan itinerary,
    # so they bound the other system by what it would have done had
    # the window never happened.
    system_lock_caps <- build_hvac_lock_caps(
      period_chunk_subset = period_chunk_subset,
      phase_vec           = period_chunk_subset[[phase_col]],
      hvac_used           = hvac_used,
      plan_suffix         = "_plan")

    # period_calculation is called to simulate the three phases of the
    # window over the itinerary of the leg.
    period_chunk_subset <- period_calculation(period_chunk_subset,
                                              asset,
                                              calculation_mode    = calculation_mode_vec,
                                              calculation_context = paste0("plan_flex_", leg),
                                              Q_heat_cap          = system_lock_caps$Q_heat_cap,
                                              Q_cool_cap          = system_lock_caps$Q_cool_cap)
    rm(list = c("calculation_mode_vec", "system_lock_caps", "hvac_used"))
  }

  # -------------------------------------------------------------
  # 8. Write the contribution back into period_chunk
  # The state before writing is kept, because the checks of block 9
  # can still refuse the contribution and the caller must then get
  # the chunk it handed in, untouched.
  # Only the itinerary of the leg (every column ending in leg_suffix)
  # is written back: the phases are the system's, already in the
  # chunk, and nothing else of period_chunk_subset differs from
  # period_chunk, so copying every column of every row would only
  # cost time. The initial condition, the first row of the subset, is
  # not written: it is a row of what comes before the window.
  # -------------------------------------------------------------
  {
    # Defensive check: the simulated rows must match subset_rows.
    if (nrow(period_chunk_subset) != length(subset_rows)) {
      warning("flex_evaluation (", leg, " leg): period_chunk_subset has ",
              nrow(period_chunk_subset), " rows but subset_rows has ",
              length(subset_rows), " elements. Returning period_chunk unchanged.",
              call. = FALSE)
      # flex_refused is called to return the chunk untouched, with
      # the reason the window is refused.
      return(c(flex_refused(period_chunk, "row_mismatch"), drawn = FALSE))
    }

    period_chunk_before <- period_chunk
    leg_columns <- grep(paste0(leg_suffix, "$"), names(period_chunk), value = TRUE)
    for (CONT_101 in leg_columns) {
      period_chunk[[CONT_101]][subset_rows[-1]] <- period_chunk_subset[[CONT_101]][-1]
    }
    rm(list = c("subset_rows", "period_chunk_subset", "leg_columns", "CONT_101",
                "phase_col"))
  }

  # -------------------------------------------------------------
  # 9. Keep or refuse the contribution
  # The contribution is kept only if the itinerary of the building has
  # converged back to its plan by the time the control horizon closes,
  # and only if it is technically feasible. Both checks run on the
  # reconciled period_chunk:
  #   - the rows the convergence check looks at can be outside the
  #     window: see check_recovery_convergence() for why it is measured
  #     there and not at the end of the Recovery Phase. A restated
  #     window is not checked: its tail may run past the control
  #     horizon, and the next market rebuilds it.
  #   - the window may not raise the electricity of both thermal
  #     systems over the plan. The feasibility check has to see the
  #     three phases at once: the case it forbids splits the increase
  #     between the Commitment Phase and the Recovery Phase and raises
  #     both systems at no single instant. See flex_window_is_feasible().
  # -------------------------------------------------------------
  {
    # check_recovery_convergence is called to test whether the
    # itinerary of the leg is back on the plan when the control horizon
    # closes; flex_refused then returns the chunk handed in, with the
    # reason.
    if (!window$restating && !check_recovery_convergence(period_chunk,
                                                         paste0("Elec_total", leg_suffix),
                                                         window$i_end_control,
                                                         parameters)) {
      return(c(flex_refused(period_chunk_before, "no_convergence"),
               drawn = FALSE))
    }

    # flex_window_is_feasible is called to reject a window that raises
    # both thermal systems over the plan; flex_refused then returns the
    # chunk handed in, with the reason.
    if (!flex_window_is_feasible(period_chunk = period_chunk,
                                 leg          = leg,
                                 parameters   = parameters,
                                 asset        = asset)) {
      return(c(flex_refused(period_chunk_before, "opposed_hvac"),
               drawn = FALSE))
    }

    rm(list = c("period_chunk_before", "leg_suffix"))
  }

  return(list(chunk = period_chunk, refusal = NULL, drawn = TRUE))
}
