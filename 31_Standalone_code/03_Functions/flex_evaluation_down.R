# -------------------------------------------------------------
# Function: flex_evaluation_down.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function evaluates the impact of a flexibility event on a
# planning period. It reduces heating and cooling by a given
# flexibility fraction during the flexibility event, runs a simulation
# for the Neutral and Recovery Phases, and reconciles
# the results back into the full period chunk.
# -------------------------------------------------------------
# Inputs
#   period_chunk             : Data frame. Planning-period data (corresponds to
#                              period_chunk_plan in the caller).  Must contain
#                              *_plan columns produced by period_calculation with
#                              calculation_context = "plan", and matching
#                              *_plan_flex_down baseline columns already initialized.
#   parameters               : Named list. Model and control parameters.  Must include
#                              parameters$control$commitment_phase_length_max,
#                              neutral_phase_timespan,
#                              recovery_phase_timespan (all in hours), and
#                              minimum_flexibility (kW).
#   simulation_control       : Named list. Simulation control object. Must contain:
#                              simulation_control$indexes_local$i_flex (Integer scalar.
#                              Row number in period_chunk at which the flexibility
#                              event starts).
#                              simulation_control$flexibility$commitment_phase_length
#                              (Numeric scalar. Duration of the Commitment Phase (h).
#                              Must be <= commitment_phase_length_max.)
#                              simulation_control$flexibility$flexibility
#                              (Numeric scalar in (0, 1]. Fraction of flexibility to
#                              apply (1 = full flexibility, i.e. maximum reduction).)
# -------------------------------------------------------------
# Outputs
#   period_chunk : Data frame. The input data frame with *_plan_flex_down
#                  columns updated, plus Flex_phase_down_plan set to the
#                  phase code of every row of the window (1 Commitment,
#                  2 Neutral, 3 Recovery; 0 elsewhere, as left by
#                  derive_flex_itineraries()). Corresponds to
#                  period_chunk in the caller.
#                  A new window that does not fit before
#                  i_end_control is refused (see EXCEPTIONS).
# -------------------------------------------------------------
# Code outline
# 1. Extract flexibility parameters from simulation_control
# 2. Modify Q_heat/Q_cool in *_plan_flex_down during flexibility window
# 3. Mark the Commitment/Neutral/Recovery Phases in Flex_phase_down_plan
# 4. Identify the system used and build the Recovery Phase power caps
# 5. Run period_calculation for plan_flex_down context
# 6. Reconcile subset simulation into full period_chunk
# -------------------------------------------------------------
# Usage instructions
# result_df <- flex_evaluation_down(period_chunk, parameters, simulation_control)
# -------------------------------------------------------------
# Where this function/script is used
#   - derive_flex_itineraries()
#   - evaluate_control()
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - simulation_control$indexes_local$i_flex must be a single integer row index within period_chunk.
#   - simulation_control$flexibility$commitment_phase_length must be <= commitment_phase_length_max.
#   - simulation_control$flexibility$flexibility must be in (0, 1].
#   - A new window (not restated) whose Commitment, Neutral and Recovery
#     Phases do not fit before i_end_control is refused ("no_room").
#   - A restated window (simulation_control$flexibility$restating) is
#     drawn wherever it falls. Only the rows of its Commitment Phase in
#     the guard zone take simulation_control$flexibility$flexibility and
#     the commitment margin; the other rows take
#     simulation_control$flexibility$flexibility_projected and no margin
#     (see derive_flex_itineraries()). It is not checked for
#     convergence at the close of the control horizon.
#   - This function assumes *_plan_flex_down baseline columns already exist
#     (initialized by derive_flex_itineraries()).
#   - During the Recovery Phase the system that did not provide the
#     flexibility service may only hold or reduce its power, never increase
#     it. The restriction is imposed step by step, through
#     calculation_mode 3, so that the bound of every step propagates to the
#     state the next step decides on. It corresponds to an interpretation of
#     the legal regulation of HVAC systems, which does not allow energy
#     management through the alternating use of heating and cooling. See
#     build_system_lock_caps().
#   - The Q_heat_plan_flex_down and Q_cool_plan_flex_down values during the flex
#     event are set to Q_*_plan * (1 - flexibility), corrected so that
#     they are at least minimum_flexibility * delta_t smaller than the
#     corresponding Q_*_plan values (clamped to 0 from below).
#   - delta_t is computed in hours, consistent with period_calculation()
#     and period_simulation_cpp.cpp. The project uses kW for power and
#     kWh for energy throughout, so minimum_flexibility (kW) only yields
#     an energy comparable with the Q_* columns (kWh) when multiplied by
#     a timestep in hours.
#   - COMPUTATIONAL COST: each call here runs period_calculation() once over
#     a bounded window (commitment_phase_length + neutral_phase_timespan
#     + recovery_phase_timespan), so this function's own cost does not
#     grow with the optimization horizon. However, evaluate_control()'s
#     nested market-slot loop can call this function O(L^2) times per
#     evaluation (L = number of market slots in the horizon) - see the
#     COMPUTATIONAL COST note in evaluate_control.R's header for the
#     aggregate cost.
# -------------------------------------------------------------
# functions/scripts called
#   apply_commitment_margin() - keeps the electrical headroom of every
#                          market slot of the window
#   build_system_lock_caps() - per-step power caps of the Recovery Phase
#   check_recovery_convergence() - convergence test at the close of the
#                          control horizon
#   period_calculation() - core building physics simulation, called with
#                          calculation_context = "plan_flex_down"
#   flex_refused() - tags the chunk with the reason a window was
#                          refused, so the caller can tell the four apart
#   flex_window_is_feasible() - refuses a window that would raise the
#                          electricity of both thermal systems
# -------------------------------------------------------------
flex_evaluation_down <- function(period_chunk, parameters, simulation_control) {

  # A chunk handed in may still carry the refusal tag of an earlier
  # call, so it is cleared here: the tag on the way out always describes
  # THIS call.
  attr(period_chunk, "flex_refusal") <- NULL

  i_flex                   <- simulation_control$indexes_local$i_flex
  commitment_phase_length <- simulation_control$flexibility$commitment_phase_length
  flexibility              <- simulation_control$flexibility$flexibility

  # Extract flexibility parameters
  neutral_phase_timespan   <- parameters$control$neutral_phase_timespan
  recovery_phase_timespan <- parameters$control$recovery_phase_timespan
  minimum_flexibility            <- parameters$control$minimum_flexibility

  total_window_h <- commitment_phase_length + neutral_phase_timespan + recovery_phase_timespan

  # Validate i_flex
  stopifnot(is.numeric(i_flex), length(i_flex) == 1,
            i_flex >= 1, i_flex <= nrow(period_chunk))

  time_at_i_flex <- period_chunk$time[i_flex]

  # Check whether the whole window fits inside the CONTROL HORIZON, not
  # merely inside period_chunk. A window whose tail falls beyond the
  # control horizon is never written to the output: the rows that fall
  # outside are simply dropped, so the optimizer would count on an
  # energy that is then not recorded anywhere. Bounding the window here
  # is what stops that from happening.
  i_end_control <- simulation_control$indexes_local$i_end_control
  if (is.null(i_end_control) || !is.numeric(i_end_control) || i_end_control < 1) {
    stop("flex_evaluation_down: simulation_control$indexes_local$i_end_control ",
         "is mandatory and must be a row index of period_chunk")
  }
  i_end_control <- min(as.integer(i_end_control), nrow(period_chunk))
  time_at_end   <- period_chunk$time[i_end_control]

  # A window that is being RE-STATED is not a new sale: the energy was
  # already sold by an earlier market and what is left to do is to carry
  # it forward, wherever it falls. Only a new sale has to fit whole
  # inside the control horizon. The restatement mode says which rows of
  # a restated Commitment Phase are in the guard zone (see
  # derive_flex_itineraries()): with "guard", the rows up to
  # i_end_control; with "projection", none. The rows out of the guard
  # zone take their own fraction, flexibility_projected.
  restating        <- isTRUE(simulation_control$flexibility$restating)
  restatement_mode <- simulation_control$flexibility$restatement_mode
  if (is.null(restatement_mode)) {
    restatement_mode <- "guard"
  }
  flexibility_projected <- simulation_control$flexibility$flexibility_projected
  if (is.null(flexibility_projected)) {
    flexibility_projected <- flexibility
  }

  if (!restating) {
    time_distance_h <- as.numeric(difftime(time_at_end, time_at_i_flex, units = "hours"))
    if (time_distance_h < total_window_h) {
      return(flex_refused(period_chunk, "no_room"))
    }
    rm(time_distance_h)
  }

  # Generate period_chunk_subset: rows from i_flex to i_flex + total_window_h hours
  end_time_subset <- time_at_i_flex + total_window_h * 3600
  subset_rows <- which(period_chunk$time >= time_at_i_flex &
                         period_chunk$time <= end_time_subset)
  period_chunk_subset <- period_chunk[subset_rows, ]

  # Apply flexibility reduction to Q_heat_plan_flex_down and Q_cool_plan_flex_down
  # up to commitment_phase_length.
  # Reduction formula: Q_*_plan_flex_down = Q_*_plan * (1 - flexibility)
  # Corrected so that Q_*_plan_flex_down is at least minimum_flexibility * delta_t
  # smaller than Q_*_plan (clamped to 0 from below).
  # delta_t is in hours, the project-wide reference: minimum_flexibility is
  # a power (kW) and the Q_* columns are energies (kWh), so the product is
  # only an energy when the timestep is expressed in hours.
  # The Commitment Phase is the HALF-OPEN interval [t0, t0 + L). Closed
  # on the right, a window of L hours would reach into the market slot
  # that begins at t0 + L, and reconstruct_flex_phases() would then
  # promote that whole slot, so the window would grow by one slot at
  # every market.
  end_time_flex    <- time_at_i_flex + commitment_phase_length * 3600
  flex_rows_subset <- which(period_chunk_subset$time < end_time_flex)

  if (length(flex_rows_subset) > 0) {
    # Compute delta_t (hours) for each flex row, mirroring period_calculation().
    # For the first row of the subset (= i_flex in period_chunk), look back one
    # row in period_chunk if possible; otherwise use the next step's delta_t.
    times_subset <- period_chunk_subset$time
    if (i_flex > 1) {
      prev_time_first <- period_chunk$time[i_flex - 1]
    } else if (length(times_subset) >= 2) {
      # No prior row in period_chunk: extrapolate backwards using the first two-row interval
      prev_time_first <- times_subset[1] - (times_subset[2] - times_subset[1])
    } else {
      # Only one row in subset and no prior row: delta_t cannot be determined;
      # use 0 (no energy correction possible for the minimum reduction)
      prev_time_first <- times_subset[1]
    }
    # Timestep in HOURS: as.numeric() on POSIXct gives seconds, so /3600
    # converts to hours. Hours is the project-wide reference, the same one
    # period_simulation_cpp.cpp uses, and it is what makes
    # minimum_flexibility (kW) * delta_t (h) an energy in kWh, directly
    # comparable with the Q_* columns.
    all_times_with_prev <- c(prev_time_first, times_subset)
    delta_t_h_subset <- as.numeric(diff(as.numeric(all_times_with_prev))) / 3600
    delta_t_h_flex <- delta_t_h_subset[flex_rows_subset]

    # The rows of the Commitment Phase in the guard zone, and the
    # fraction of every row. Every row of a new sale is in it.
    guard_row <- if (!restating) {
      rep(TRUE, length(flex_rows_subset))
    } else if (restatement_mode == "guard") {
      subset_rows[flex_rows_subset] <= i_end_control
    } else {
      rep(FALSE, length(flex_rows_subset))
    }
    fraction_row <- ifelse(guard_row, flexibility, flexibility_projected)

    # Compute minimum-corrected flex values
    Q_heat_plan_flex_down <- pmax(
      0,
      pmin(
        period_chunk_subset$Q_heat_plan[flex_rows_subset] * (1 - fraction_row),
        period_chunk_subset$Q_heat_plan[flex_rows_subset] - (minimum_flexibility * delta_t_h_flex)
      )
    )
    Q_cool_plan_flex_down <- pmax(
      0,
      pmin(
        period_chunk_subset$Q_cool_plan[flex_rows_subset] * (1 - fraction_row),
        period_chunk_subset$Q_cool_plan[flex_rows_subset] - minimum_flexibility * delta_t_h_flex
      )
    )

    # apply_commitment_margin is called to lift the itinerary off zero
    # on the rows of the guard zone, so that every market slot of the
    # window keeps at least flexibility_commitment_margin of electricity
    # running and a later re-optimization still has something left to
    # shed without breaking what this window sells. The other rows of a
    # restated window are drawn as the plan allows, without the margin.
    if (any(guard_row)) {
      margin_rows <- flex_rows_subset[guard_row]
      # The ceiling arguments are not read on the downward leg, whose
      # bound is the margin itself, so the plan is passed for them.
      margined <- apply_commitment_margin(
        Q_heat_flex    = Q_heat_plan_flex_down[guard_row],
        Q_heat_plan    = period_chunk_subset$Q_heat_plan[margin_rows],
        Q_cool_flex    = Q_cool_plan_flex_down[guard_row],
        Q_cool_plan    = period_chunk_subset$Q_cool_plan[margin_rows],
        Q_heat_ceiling = period_chunk_subset$Q_heat_plan[margin_rows],
        Q_cool_ceiling = period_chunk_subset$Q_cool_plan[margin_rows],
        market_slot    = period_chunk_subset$MarketUTC[margin_rows],
        Text           = period_chunk_subset$Text[margin_rows],
        delta_t_h      = delta_t_h_flex[guard_row],
        leg            = "down",
        parameters     = parameters
      )
      Q_heat_plan_flex_down[guard_row] <- margined$Q_heat
      Q_cool_plan_flex_down[guard_row] <- margined$Q_cool
      rm(margined, margin_rows)
    }
    rm(guard_row, fraction_row)

    period_chunk_subset$Q_heat_plan_flex_down[flex_rows_subset] <- Q_heat_plan_flex_down
    period_chunk_subset$Q_cool_plan_flex_down[flex_rows_subset] <- Q_cool_plan_flex_down
    rm(Q_heat_plan_flex_down, Q_cool_plan_flex_down, delta_t_h_flex, delta_t_h_subset, all_times_with_prev,
       prev_time_first, times_subset)
  }
  rm(end_time_flex, flex_rows_subset)

  # Mark the three phases of this window in Flex_phase_down_plan, with
  # L the Commitment Phase, R the Neutral Phase and S the Recovery
  # Phase:
  #   1 Commitment - [t0, t0 + L)
  #   2 Neutral    - [t0 + L, t0 + L + R)
  #   3 Recovery   - [t0 + L + R, t0 + L + R + S]
  # Only phase 1 carries an economic commitment: reward_function()
  # bounds Elec_flex_down_plan to it, so that the rebound of the
  # Neutral and Recovery Phases is not sold as flexibility of
  # the opposite sign. The phase code is what lets reward_function(),
  # compute_recovery_energy_cost() and reconstruct_flex_phases() all
  # agree on which rows belong to the window without recomputing it.
  {
    end_time_commitment    <- time_at_i_flex + commitment_phase_length * 3600
    end_time_neutral <- time_at_i_flex +
      (commitment_phase_length + neutral_phase_timespan) * 3600

    # Half-open on the right, for the reason given where the flexibility
    # rows are selected: the three phases tile the window without any of
    # them reaching into the slot where the next one starts.
    period_chunk_subset$Flex_phase_down_plan <-
      ifelse(period_chunk_subset$time < end_time_commitment, 1L,
      ifelse(period_chunk_subset$time < end_time_neutral,    2L, 3L))

    rm(end_time_commitment, end_time_neutral)
  }

  # Identify the system that provides the downward flexibility service.
  # The simulation loop forces heating and cooling to be mutually
  # exclusive at every timestep, so "the system used" is simply the one
  # that was running. That exclusivity is per step and not per window,
  # though, and a long Commitment Phase can contain a change of system
  # halfway through; the system with the larger accumulated heat over the
  # window is the one taken. When both accumulate zero, nothing was
  # flexed and no system is locked.
  {
    event_rows_subset <- which(period_chunk_subset$Flex_phase_down_plan == 1L)

    S_heat_event <- sum(period_chunk_subset$Q_heat_plan[event_rows_subset])
    S_cool_event <- sum(period_chunk_subset$Q_cool_plan[event_rows_subset])

    if (S_heat_event <= 0 && S_cool_event <= 0) {
      system_used <- "none"
    } else if (S_heat_event >= S_cool_event) {
      system_used <- "heat"
    } else {
      system_used <- "cool"
    }

    rm(event_rows_subset, S_heat_event, S_cool_event)
  }

  # Build calculation_mode vector:
  #   2 (Heat Input)         up to commitment_phase_length +
  #                          neutral_phase_timespan, where the power of
  #                          every step is imposed
  #   3 (Setpoint with cap)  for the Recovery Phase, where the
  #                          thermostat decides again but the system that was
  #                          not used to provide the service may only hold or
  #                          reduce its power - see build_system_lock_caps()
  end_time_mode2 <- time_at_i_flex +
    (commitment_phase_length + neutral_phase_timespan) * 3600
  calculation_mode_vec <- ifelse(period_chunk_subset$time <= end_time_mode2, 2L, 3L)
  rm(end_time_mode2)

  # The caps are read from the _plan itinerary, so they bound the other
  # system by what it would have done had the event never happened.
  system_lock_caps <- build_system_lock_caps(
    period_chunk_subset = period_chunk_subset,
    phase_vec           = period_chunk_subset$Flex_phase_down_plan,
    system_used         = system_used,
    plan_suffix         = "_plan")

  # Simulate the flexibility window
  period_chunk_subset <- period_calculation(period_chunk_subset,
                                            parameters,
                                            calculation_mode    = calculation_mode_vec,
                                            calculation_context = "plan_flex_down",
                                            Q_heat_cap          = system_lock_caps$Q_heat_cap,
                                            Q_cool_cap          = system_lock_caps$Q_cool_cap)
  rm(calculation_mode_vec, system_lock_caps, system_used)

  # Defensive check: ensure period_chunk_subset rows match subset_rows
  if (nrow(period_chunk_subset) != length(subset_rows)) {
    warning("flex_evaluation_down: period_chunk_subset has ", nrow(period_chunk_subset),
            " rows but subset_rows has ", length(subset_rows),
            " elements. Returning period_chunk unchanged.")
    return(flex_refused(period_chunk, "row_mismatch"))
  }

  # Reconcile period_chunk_subset back into period_chunk. The state
  # before reconciling is kept, because the convergence check below can
  # still reject the window and the caller must then get the chunk it
  # handed in, untouched.
  period_chunk_before <- period_chunk
  period_chunk[subset_rows, ] <- period_chunk_subset
  rm(subset_rows, period_chunk_subset, end_time_subset)

  # The window is admissible only if the flexibility itinerary has
  # converged back to the plan by the time the control horizon closes.
  # The check runs on the reconciled period_chunk, because the rows it
  # looks at can be outside the window: see
  # check_recovery_convergence() for why it is measured there and not at
  # the end of the Recovery Phase.
  # A restated window is not checked: its tail may run past the
  # control horizon, and the next market rebuilds it.
  if (!restating && !check_recovery_convergence(period_chunk,
                                               "Elec_total_plan_flex_down",
                                               i_end_control,
                                               parameters)) {
    return(flex_refused(period_chunk_before, "no_convergence"))
  }

  # And only if it is technically feasible: the window may not raise the
  # electricity of both thermal systems over the plan. The check runs
  # here, on the reconciled chunk, because it has to see the three
  # phases at once - the case it forbids splits the increase between the
  # Commitment Phase and the Recovery Phase and raises both systems at
  # no single instant. See flex_window_is_feasible().
  if (!flex_window_is_feasible(period_chunk, "down", parameters)) {
    return(flex_refused(period_chunk_before, "opposed_systems"))
  }

  rm(period_chunk_before)

  attr(period_chunk, "flex_refusal") <- NULL

  return(period_chunk)
}
