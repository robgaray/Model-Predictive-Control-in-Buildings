# -------------------------------------------------------------
# Function: flex_evaluation_up.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function evaluates the impact of an UPWARD flexibility event on
# a planning period. It raises the selected HVAC system to its maximum
# power during the Commitment Phase, runs a simulation for the Neutral
# and Recovery Phases, and reconciles the results back into the full
# period chunk.
# -------------------------------------------------------------
# How it differs from flex_evaluation_down()
# The structure is the same, and deliberately so: the two legs of the
# service have to be evaluated with the same window, the same phases and
# the same reconciliation, or their results are not comparable. What
# changes is what happens during the event.
#   1. A system has to be selected first. Downward flexibility is
#      symmetric between the two systems - whatever is running gets
#      switched off - but running the wrong system harder would heat a
#      building that needs cooling, so resolve_flex_up_system() decides,
#      and returns "none" when the situation is not clear enough to
#      commit. Then no upward flexibility is offered.
#   2. During the event the selected system is raised towards its
#      maximum power instead of being reduced towards zero, and the
#      other system is switched off.
#   3. A window only constitutes a real offer if it actually increases
#      the energy of the event; a plan that was already at maximum power
#      throughout the event has nothing to offer.
# The phases, the system lock of the Recovery Phase and the
# reconciliation are identical to the downward leg.
# -------------------------------------------------------------
# Inputs
#   period_chunk             : Data frame. Planning-period data (corresponds to
#                              period_chunk_plan in the caller).  Must contain
#                              *_plan columns produced by period_calculation with
#                              calculation_context = "plan", and matching
#                              *_plan_flex_up baseline columns already initialized.
#   parameters               : Named list. Model and control parameters.  Must include
#                              parameters$control$commitment_phase_length_max,
#                              neutral_phase_timespan,
#                              recovery_phase_timespan (all in hours),
#                              minimum_flexibility (kW),
#                              flex_up_max_power_heating (either "Q_hp_heat_1" or
#                              "Q_hp_heat_2", naming which of the two rated
#                              heating capacities bounds the event), and the
#                              horizons and threshold of resolve_flex_up_system().
#                              parameters$model must include Q_hp_heat_1,
#                              Q_hp_heat_2 and Q_hp_cool (all kW).
#   simulation_control       : Named list. Simulation control object. Must contain:
#                              simulation_control$indexes_local$i_flex (Integer scalar.
#                              Row number in period_chunk at which the flexibility
#                              event starts).
#                              simulation_control$flexibility$commitment_phase_length
#                              (Numeric scalar. Duration of the Commitment Phase (h).
#                              Must be <= commitment_phase_length_max.)
#                              simulation_control$flexibility$flexibility
#                              (Numeric scalar in (0, 1]. Fraction of flexibility to
#                              apply (1 = full flexibility, i.e. maximum increase).)
# -------------------------------------------------------------
# Outputs
#   period_chunk : Data frame. The input data frame with *_plan_flex_up
#                  columns updated, plus Flex_phase_up_plan set to the
#                  phase code of every row of the window (1 Commitment,
#                  2 Neutral, 3 Recovery; 0 elsewhere, as left by
#                  derive_flex_itineraries()). Corresponds to
#                  period_chunk in the caller.
#                  Returned unchanged if no system can be selected, if
#                  there is not enough time remaining from i_flex to
#                  accommodate the full flexibility window, or if the
#                  window does not increase the energy of the event.
# -------------------------------------------------------------
# The power of the event
# With dt_r the timestep of row r in hours, P_max_s the rated power of
# the selected system s in kW, f the flexibility fraction and q_min the
# minimum_flexibility in kW:
#
#   Q_s_plan_flex_up_r = min( P_max_s * dt_r,
#                             max( Q_s_plan_r + f * (P_max_s * dt_r - Q_s_plan_r),
#                                  Q_s_plan_r + q_min * dt_r ) )
#   Q_s'_plan_flex_up_r = 0
#
# It is the exact mirror of the downward expression. The max() term
# guarantees an increase of at least q_min * dt_r, as the downward leg
# guarantees a reduction of at least q_min * dt_r; the outer min() clips
# at the physical maximum power, as the downward leg clips at 0 from
# below. With f = 1 it reduces to P_max_s * dt_r unless the plan was
# already at, or above, the maximum power.
# -------------------------------------------------------------
# Code outline
# 1. Extract flexibility parameters from simulation_control
# 2. Select the system that may offer upward flexibility
# 3. Raise Q_heat/Q_cool in *_plan_flex_up during flexibility window
# 4. Mark the Commitment/Neutral/Recovery Phases in Flex_phase_up_plan
# 5. Build the Recovery Phase power caps
# 6. Run period_calculation for plan_flex_up context
# 7. Check that the event really increases the electricity of the building
# 8. Reconcile subset simulation into full period_chunk
# -------------------------------------------------------------
# Usage instructions
# result_df <- flex_evaluation_up(period_chunk, parameters, simulation_control)
# -------------------------------------------------------------
# Where this function/script is used
#   - derive_flex_itineraries()
#   - evaluate_control()
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - simulation_control$indexes_local$i_flex must be a single integer row index within period_chunk.
#   - simulation_control$flexibility$commitment_phase_length must be <= commitment_phase_length_max.
#   - simulation_control$flexibility$flexibility must be in (0, 1].
#   - If resolve_flex_up_system() returns "none", period_chunk is
#     returned without any changes: there is no system the building can
#     commit to, so there is no upward flexibility to offer.
#   - A new window (not restated) whose Commitment, Neutral and Recovery
#     Phases do not fit before i_end_control is refused ("no_room").
#   - A restated window (simulation_control$flexibility$restating) is
#     drawn wherever it falls. Only the rows of its Commitment Phase in
#     the guard zone take simulation_control$flexibility$flexibility and
#     the commitment margin; the other rows take
#     simulation_control$flexibility$flexibility_projected and no margin
#     (see derive_flex_itineraries()). It is not checked for
#     convergence at the close of the control horizon.
#   - If the Commitment Phase of a new window does not increase the
#     energy of the selected system, period_chunk is returned without any changes. That happens
#     when the plan was already running at maximum power throughout the
#     event, and it is not an error: there is simply nothing left to
#     offer from that start row.
#   - The same happens, after the simulation, when the window does not
#     increase the building's electricity during the event. The check
#     before the simulation looks only at the selected system, and the
#     event also switches the other one off; if the plan was running
#     that other system on the backup resistances, at COP 1, the event
#     can end up consuming less than the plan. Selling that as upward
#     flexibility would be selling a load reduction at upward prices.
#   - This function assumes *_plan_flex_up baseline columns already exist
#     (initialized by derive_flex_itineraries()).
#   - The maximum heating power is either Q_hp_heat_1 or Q_hp_heat_2,
#     selected by parameters$control$flex_up_max_power_heating. The two
#     are the rated capacities of the two operating points of the heat
#     pump, and which of them bounds an upward event is a modelling
#     decision rather than a fact of the equipment, so it is left as a
#     parameter. Raising heating above Q_hp_heat_1 is served by the
#     backup resistances, at COP 1, which the electricity calculation of
#     period_simulation_cpp.cpp already accounts for.
#   - delta_t is computed in hours, consistent with period_calculation()
#     and period_simulation_cpp.cpp. The project uses kW for power and
#     kWh for energy throughout, so the rated powers (kW) only yield an
#     energy comparable with the Q_* columns (kWh) when multiplied by a
#     timestep in hours.
#   - During the Recovery Phase the system that did not provide
#     the service may only hold or reduce its power, never increase it.
#     The restriction is imposed step by step, through
#     calculation_mode 3, and corresponds to an interpretation of the
#     legal regulation of HVAC systems, which does not allow energy
#     management through the alternating use of heating and cooling. See
#     build_system_lock_caps().
#   - COMPUTATIONAL COST: as in flex_evaluation_down(), each call runs
#     period_calculation() once over a bounded window, so this function's
#     own cost does not grow with the optimization horizon.
# -------------------------------------------------------------
# functions/scripts called
#   apply_commitment_margin() - keeps the electrical headroom of every
#                          market slot of the window
#   build_system_lock_caps() - per-step power caps of the Recovery Phase
#   check_recovery_convergence() - convergence test at the close of the
#                          control horizon
#   period_calculation() - core building physics simulation, called with
#                          calculation_context = "plan_flex_up"
#   flex_refused() - tags the chunk with the reason a window was
#                          refused, so the caller can tell the four apart
#   flex_window_is_feasible() - refuses a window that would raise the
#                          electricity of both thermal systems
#   resolve_flex_up_system() - the system that may offer the
#                          upward service from this start row
# -------------------------------------------------------------
flex_evaluation_up <- function(period_chunk, parameters, simulation_control) {

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

  # Select the system that may offer upward flexibility from this start
  # row. Without a dominant system there is no commitment to make.
  system_up <- resolve_flex_up_system(period_chunk, i_flex, parameters)
  if (system_up == "none") {
    return(period_chunk)
  }

  time_at_i_flex <- period_chunk$time[i_flex]

  # Check whether the whole window fits inside the CONTROL HORIZON, not
  # merely inside period_chunk. A window whose tail falls beyond the
  # control horizon is never written to the output: the rows that fall
  # outside are simply dropped, so the optimizer would count on an
  # energy that is then not recorded anywhere. Bounding the window here
  # is what stops that from happening.
  i_end_control <- simulation_control$indexes_local$i_end_control
  if (is.null(i_end_control) || !is.numeric(i_end_control) || i_end_control < 1) {
    stop("flex_evaluation_up: simulation_control$indexes_local$i_end_control ",
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

  # Raise the selected system to its maximum power during the event, and
  # switch the other one off. The maximum power of the heating system is
  # a parameter because the heat pump has two rated operating points and
  # which of them bounds an upward event is a modelling decision.
  # The Commitment Phase is the HALF-OPEN interval [t0, t0 + L). Closed
  # on the right, a window of L hours would reach into the market slot
  # that begins at t0 + L, and reconstruct_flex_phases() would then
  # promote that whole slot, so the window would grow by one slot at
  # every market.
  end_time_flex    <- time_at_i_flex + commitment_phase_length * 3600
  flex_rows_subset <- which(period_chunk_subset$time < end_time_flex)

  if (length(flex_rows_subset) == 0) {
    return(period_chunk)
  }

  {
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
      # use 0 (no energy increase possible)
      prev_time_first <- times_subset[1]
    }
    # Timestep in HOURS: as.numeric() on POSIXct gives seconds, so /3600
    # converts to hours. Hours is the project-wide reference, the same one
    # period_simulation_cpp.cpp uses, and it is what makes a rated power
    # (kW) * delta_t (h) an energy in kWh, directly comparable with the
    # Q_* columns.
    all_times_with_prev <- c(prev_time_first, times_subset)
    delta_t_h_subset <- as.numeric(diff(as.numeric(all_times_with_prev))) / 3600
    delta_t_h_flex   <- delta_t_h_subset[flex_rows_subset]

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

    if (system_up == "heat") {
      P_max <- if (identical(parameters$control$flex_up_max_power_heating, "Q_hp_heat_1")) {
        parameters$model$Q_hp_heat_1
      } else {
        parameters$model$Q_hp_heat_2
      }
      col_used  <- "Q_heat_plan"
      col_other <- "Q_cool_plan"
    } else {
      P_max     <- parameters$model$Q_hp_cool
      col_used  <- "Q_cool_plan"
      col_other <- "Q_heat_plan"
    }

    Q_used_plan  <- period_chunk_subset[[col_used]][flex_rows_subset]
    Q_used_max   <- P_max * delta_t_h_flex

    # Mirror of the downward expression: at least a minimum increase, and
    # never above the physical maximum power of the system.
    Q_used_flex_up <- pmin(
      Q_used_max,
      pmax(
        Q_used_plan + fraction_row * (Q_used_max - Q_used_plan),
        Q_used_plan + minimum_flexibility * delta_t_h_flex
      )
    )

    # apply_commitment_margin is called to pull the itinerary back from
    # the system's limit on the rows of the guard zone, so that every
    # market slot of the window keeps flexibility_commitment_margin of
    # electricity unused and a later re-optimization still has room to
    # move the operation without breaking what this window sells. The
    # other rows of a restated window are drawn as the plan allows,
    # without the margin.
    if (any(guard_row)) {
      n_guard        <- sum(guard_row)
      margin_rows    <- flex_rows_subset[guard_row]
      Q_heat_flex    <- if (system_up == "heat") Q_used_flex_up[guard_row] else rep(0, n_guard)
      Q_cool_flex    <- if (system_up == "heat") rep(0, n_guard) else Q_used_flex_up[guard_row]
      Q_heat_ceiling <- if (system_up == "heat") Q_used_max[guard_row] else rep(0, n_guard)
      Q_cool_ceiling <- if (system_up == "heat") rep(0, n_guard) else Q_used_max[guard_row]

      margined <- apply_commitment_margin(
        Q_heat_flex    = Q_heat_flex,
        Q_heat_plan    = period_chunk_subset$Q_heat_plan[margin_rows],
        Q_cool_flex    = Q_cool_flex,
        Q_cool_plan    = period_chunk_subset$Q_cool_plan[margin_rows],
        Q_heat_ceiling = Q_heat_ceiling,
        Q_cool_ceiling = Q_cool_ceiling,
        market_slot    = period_chunk_subset$MarketUTC[margin_rows],
        Text           = period_chunk_subset$Text[margin_rows],
        delta_t_h      = delta_t_h_flex[guard_row],
        leg            = "up",
        parameters     = parameters
      )

      Q_used_flex_up[guard_row] <- if (system_up == "heat") margined$Q_heat else margined$Q_cool

      # The other system stays off, as it does without the margin. The
      # scaling walks the itinerary back towards the plan and would
      # otherwise bring part of that system's power back with it, which
      # the simulation, where heating and cooling exclude each other at
      # every step, has no way to fly. Dropping it only lowers the
      # electricity of the itinerary, so the headroom the bisection just
      # secured is kept and, where the plan ran the other system, a
      # little more.
      rm(Q_heat_flex, Q_cool_flex, Q_heat_ceiling, Q_cool_ceiling, margined,
         margin_rows, n_guard)
    }
    rm(guard_row, fraction_row)

    # A new window that does not increase the energy of the event is
    # not an offer of upward flexibility. It happens when the plan was
    # already running at maximum power throughout the event, or when
    # the margin left no room to raise anything. A restated window is
    # still drawn: what it commits is then what the new plan allows,
    # and the caller decides what to do with the shortfall.
    if (!restating && sum(Q_used_flex_up - Q_used_plan) <= 0) {
      return(period_chunk)
    }

    period_chunk_subset[[paste0(col_used, "_flex_up")]][flex_rows_subset]  <- Q_used_flex_up
    period_chunk_subset[[paste0(col_other, "_flex_up")]][flex_rows_subset] <- 0

    rm(Q_used_plan, Q_used_max, Q_used_flex_up, P_max, col_used, col_other,
       delta_t_h_flex, delta_t_h_subset, all_times_with_prev, prev_time_first,
       times_subset)
  }
  rm(end_time_flex, flex_rows_subset)

  # Mark the three phases of this window in Flex_phase_up_plan, with
  # L the Commitment Phase, R the Neutral Phase and S the Recovery
  # Phase:
  #   1 Commitment - [t0, t0 + L)
  #   2 Neutral    - [t0 + L, t0 + L + R)
  #   3 Recovery   - [t0 + L + R, t0 + L + R + S]
  # Only phase 1 carries an economic commitment: reward_function()
  # bounds Elec_flex_up_plan to it, so that the rebound of the Neutral
  # and Recovery Phases is not sold as flexibility of the opposite
  # sign. The phase code is what lets reward_function(),
  # compute_recovery_energy_cost() and reconstruct_flex_phases() all
  # agree on which rows belong to the window without recomputing it.
  {
    end_time_commitment    <- time_at_i_flex + commitment_phase_length * 3600
    end_time_neutral <- time_at_i_flex +
      (commitment_phase_length + neutral_phase_timespan) * 3600

    # Half-open on the right, for the reason given where the flexibility
    # rows are selected: the three phases tile the window without any of
    # them reaching into the slot where the next one starts.
    period_chunk_subset$Flex_phase_up_plan <-
      ifelse(period_chunk_subset$time < end_time_commitment, 1L,
      ifelse(period_chunk_subset$time < end_time_neutral,    2L, 3L))

    rm(end_time_commitment, end_time_neutral)
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
    phase_vec           = period_chunk_subset$Flex_phase_up_plan,
    system_used         = system_up,
    plan_suffix         = "_plan")

  # Simulate the flexibility window
  period_chunk_subset <- period_calculation(period_chunk_subset,
                                            parameters,
                                            calculation_mode    = calculation_mode_vec,
                                            calculation_context = "plan_flex_up",
                                            Q_heat_cap          = system_lock_caps$Q_heat_cap,
                                            Q_cool_cap          = system_lock_caps$Q_cool_cap)
  rm(calculation_mode_vec, system_lock_caps, system_up)

  # A window is an upward offer only if it actually raises the
  # building's electricity during the event. The thermal check above
  # looks at the selected system alone, before simulating, and that is
  # not enough: the event also switches the other system off, and when
  # the plan was running that other system on backup resistances, at
  # COP 1, the electricity of the event can come out lower than the
  # plan's even though the selected system went to full power. Selling
  # that as upward flexibility would be selling a load reduction at
  # upward prices, and it would put a negative value into
  # Elec_flex_up_plan, which the economic chain relies on being
  # non-negative to tell the two legs apart.
  {
    event_rows_subset <- which(period_chunk_subset$Flex_phase_up_plan == 1L)

    if (sum(period_chunk_subset$Elec_total_plan_flex_up[event_rows_subset] -
            period_chunk_subset$Elec_total_plan[event_rows_subset]) <= 0) {
      return(period_chunk)
    }

    rm(event_rows_subset)
  }

  # Defensive check: ensure period_chunk_subset rows match subset_rows
  if (nrow(period_chunk_subset) != length(subset_rows)) {
    warning("flex_evaluation_up: period_chunk_subset has ", nrow(period_chunk_subset),
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
                                               "Elec_total_plan_flex_up",
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
  if (!flex_window_is_feasible(period_chunk, "up", parameters)) {
    return(flex_refused(period_chunk_before, "opposed_systems"))
  }

  rm(period_chunk_before)

  attr(period_chunk, "flex_refusal") <- NULL

  return(period_chunk)
}
