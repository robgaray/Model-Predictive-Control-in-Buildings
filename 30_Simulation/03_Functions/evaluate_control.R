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
# optimizer with a simulation code in "period_calculation".
# It performs the following steps:
#   1. Calls period_calculation() to simulate the building over the
#      period and stores results in *_plan columns of period_chunk_plan.
#   2. Calls derive_flex_itineraries() to build the *_plan_flex_down and
#      *_plan_flex_up itineraries from the *_plan columns and the
#      flexibility standing from earlier markets.
#   3. For "energy" mode, calls reward_function() directly on the
#      plan columns.
#   4. For "flexibility" mode, performs a parametric evaluation over
#      all market slots in period_chunk_plan as candidate flexibility
#      event start points. For each market slot:
#      - Skips if sum of Elec_total_plan is 0 or Flex_unit_cost_down_com_sell is 0
#      - Tests expanding flexibility events by adding consecutive market
#        slots, up to commitment_phase_length_max
#      - Uses flexibility = 1 (full flexibility)
#      - Stops expanding when Flex_unit_cost_down_com_sell is 0 or reward doesn't improve
#      The best reward across all candidates is returned.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. Simulation data for the period to evaluate.
#                  Must include the columns expected by
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
#   set_point_df : Data frame. Setpoint schedule with hysteresis deadbands
#                  already applied, as returned by convert_setpoints() or
#                  convert_modes_to_setpoints().
#   parameters   : Named list. Model and control parameters passed to
#                  period_calculation(), flex_evaluation_down(), and
#                  reward_function(). Must contain:
#                    parameters$control$optimization_aim :
#                      Character. "energy" or "flexibility".
#                    parameters$market$market_resolution :
#                      Numeric (minutes). Market slot duration used as the
#                      minimum Commitment Phase length step.
#                    parameters$control$commitment_phase_length_max :
#                      Numeric (hours). Longest Commitment Phase a candidate
#                      window may reach.
#   simulation_control : Named list. Simulation control object. Used to
#                        pass these elements to flex_evaluation_down() and
#                        reward_function() via a cloned object:
#                          - simulation_control$indexes_local$i_flex
#                          - simulation_control$flexibility$commitment_phase_length
#                          - simulation_control$flexibility$flexibility
#   marginal_context   : Named list or NULL (default NULL). Passed through to
#                        reward_function() (see resolve_marginal_context()).
# -------------------------------------------------------------
# Outputs
#   A named list with the following elements (in this order):
#   period_chunk : Data frame. The plan data frame corresponding to
#                  the best flexibility scenario found (for
#                  "flexibility" mode), or the plan data frame itself
#                  (for "energy" mode). Always contains a 'Reward'
#                  column with the per-row reward values as set by
#                  reward_function().
#   reward       : Numeric scalar. Sum of per-row reward values in
#                  period_chunk$Reward. Best reward found over all
#                  flexibility candidate market slots (for "flexibility"
#                  mode), or the direct reward from the plan (for
#                  "energy" mode).
# -------------------------------------------------------------
# Code outline
# 1. Run period_calculation for plan context
# 2. Derive the *_plan_flex_down and *_plan_flex_up itineraries from
#    *_plan and the standing commitment
# 3. Evaluate flexibility scenarios (if optimization_aim is flexibility):
#    phase A downward, then phase B upward
# 4. Compute reward function
# 5. Return results
# -------------------------------------------------------------
# Usage instructions
# result <- evaluate_control(period_chunk, set_point_df, parameters, simulation_control)
# -------------------------------------------------------------
# Where this function/script is used
# Called by optimize_control_step.R, fitness_funct_optimize_setpoint.R,
# fitness_funct_optimize_mode.R, and run_market_process.R (Piloting,
# when optimization_aim == "operationflex").
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - Simulation results are stored under execution column names (no suffix)
#     and then aliased to *_plan columns before reward_function() is called,
#     so that reward_function() can read Comfort_plan, Elec_total_plan, etc.
#   - For "flexibility" mode, evaluate_control() always initializes the
#     *_plan_flex_down and *_plan_flex_up columns before searching. The
#     downward loop skips market slots whose Elec_total_plan sums to
#     (effectively) zero in absolute value, or where
#     Flex_unit_cost_down_com_sell is 0 (no flexibility profit
#     available). The absolute value matters: a slot with a net export
#     sums to a negative number and is still a candidate for
#     down-flexibility.
#   - Accepted flexibility windows never overlap WITHIN a leg, and the
#     window that is skipped over is the WHOLE one: Commitment, Neutral
#     and Recovery. When a window whose Commitment Phase is n slots is
#     accepted at slot i, the outer loop resumes past slot i + n + the
#     slots the Neutral and Recovery Phases take, so a later window can
#     neither rewrite the columns of a stretch already committed nor
#     start while the building is still recovering. The outer loop is a
#     while loop for this reason.
#   - Windows of DIFFERENT legs may overlap, and that is intended. The
#     two searches run one after the other over their own set of
#     columns, so a slot can carry a downward commitment and an upward
#     one at the same time; physically they are two different
#     itineraries and neither is flown unless the operator calls it.
#   - The two searches share one algorithm, written once and told which
#     leg it works on. The legs differ only in three filters: the price
#     column that gates a slot, the null-planned-energy skip (downward
#     only - a slot planning no energy has nothing to switch off, but it
#     can always switch something on), and the dominant-system
#     pre-filter (upward only).
#   - A candidate window may close on the last market slot of
#     period_chunk, but it is never accepted: flex_evaluation_down()/
#     flex_evaluation_up() return the chunk untouched when the time left
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
#     simulation_control$flexibility and passed through to flex_evaluation_down()
#     and reward_function() via a cloned simulation_control_2 object.
#   - COMPUTATIONAL COST: for "flexibility"/"operationflex" mode, the outer
#     loop visits each of the L unique market slots of period_chunk at most
#     once (accepted windows are skipped over, not re-entered), and for each
#     starting slot the inner while loop keeps expanding the candidate
#     flexibility window as long as the reward keeps improving, calling
#     flex_evaluation_down() + reward_function() once per expansion step.
#     The expansion stops at M = floor(commitment_phase_length_max /
#     market_slot_h) slots, so the inner loop is bounded by M rather than
#     by the horizon: worst case is O(M) calls per starting slot and
#     O(L * M) overall, each itself proportional to the flexibility
#     window size via period_calculation(). This function is in turn
#     evaluated once per GA individual per generation by
#     optimize_control_step()/fitness_funct_optimize_setpoint(), so a longer
#     optimization horizon (larger L) or a larger GA population/generation
#     count multiplies this cost accordingly. Keep the Piloting optimization
#     horizon and GA population/generation settings conservative for long
#     horizons.
# -------------------------------------------------------------
# functions/scripts called
#   period_calculation() - core building physics simulation
#   derive_flex_itineraries() - builds the two flexibility itineraries
#     from the plan and the commitment already standing
#   flex_evaluation_down()   - downward flexibility event simulation
#   flex_evaluation_up()     - upward flexibility event simulation
#   resolve_flex_up_system() - pre-filter of the upward phase: skips a
#     start slot with no dominant system without simulating it
#   reward_function()    - reward calculation
# -------------------------------------------------------------
evaluate_control <- function(period_chunk,
                             set_point_df=NULL,
                             parameters,
                             simulation_control,
                             marginal_context = NULL) {

  # Simulate the building and energy system (execution context)
  period_chunk <- period_calculation(
    period_chunk        = period_chunk,
    parameters          = parameters,
    calculation_mode    = 1,
    calculation_context = "plan",
    set_point_df        = set_point_df
  )
  
  # Build both flexibility itineraries from the plan AND the flexibility
  # already committed by earlier markets. This used to be a copy of the
  # plan with the commitment set to zero, which made every market start
  # its search as if nothing had ever been sold: see
  # derive_flex_itineraries().
  derived      <- derive_flex_itineraries(period_chunk       = period_chunk,
                                          parameters         = parameters,
                                          simulation_control = simulation_control)
  period_chunk <- derived$period_chunk

  # Whether the standing commitment could be held over this candidate's
  # plan travels with the chunk, because it is reward_function() that
  # has to price it: a candidate whose plan makes an already-sold window
  # impossible is not merely a candidate that sells nothing, it is one
  # that breaks a contract.
  period_chunk$Standing_commitment_held_plan <- as.integer(derived$feasible)
  rm(derived)

  # Compute the reward for this flexibility scenario
  period_chunk <- reward_function(
    period_chunk       = period_chunk,
    parameters         = parameters,
    simulation_control = simulation_control,
    marginal_context   = marginal_context
  )
  reward <- sum(period_chunk$Reward)

  # For flexibility mode, search for flexibility windows, in two chained
  # phases: first downward, then upward over the period_chunk the
  # downward phase leaves behind.
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
  if (parameters$control$optimization_aim == "flexibility" ||
      parameters$control$optimization_aim == "operationflex" ) {

      # 1 MarketUTC slot expressed in hours
      market_slot_h <- parameters$market$market_resolution / 60

      # Longest candidate window, in market slots. The Commitment Phase
      # is built by adding whole market slots, so the bound that
      # commitment_phase_length_max sets in hours becomes a bound on the
      # number of slots the inner loop may reach. It is rounded down: a
      # window of the next slot up would already exceed the maximum.
      # flex_evaluation_down()/flex_evaluation_up() declare
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

      # Energy tolerance below which a market slot's planned energy is
      # treated as zero. It absorbs floating-point residue only; a slot
      # with a genuine net position, in either direction, is above it.
      # Its value is the engine's own flex_energy_tol, read from
      # 01_computing_parameters.csv.
      flex_energy_tol <- parameters$computing$flex_energy_tol

      # Get unique market slots in period_chunk
      unique_market_slots <- unique(period_chunk$MarketUTC)

      search_flexibility_windows <- function(period_chunk, reward, leg) {

        if (leg == "down") {
          price_col   <- "Flex_unit_cost_down_com_sell"
          evaluate_leg <- flex_evaluation_down
        } else {
          price_col   <- "Flex_unit_cost_up_com_sell"
          evaluate_leg <- flex_evaluation_up
        }

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

          current_market_slot <- unique_market_slots[CONT_002]

          # Get all rows belonging to this market_slot
          market_slot_rows <- which(period_chunk$MarketUTC == current_market_slot)

          # 1.0.1 Skip if the planned energy of this market_slot is
          # effectively zero. The test is on the absolute value: a slot
          # with a net export has a genuinely negative sum and can still
          # offer down-flexibility, so it must not be skipped.
          # It only applies to the downward leg. A slot that plans no
          # energy has nothing to switch off, but it can always switch
          # something on, so it is a legitimate upward candidate. What
          # the upward leg does need is that the selected system still
          # has power headroom, and flex_evaluation_up() checks exactly
          # that before committing anything.
          if (leg == "down" &&
              abs(sum(period_chunk$Elec_total_plan[market_slot_rows])) <= flex_energy_tol) {
            CONT_002 <- CONT_002 + 1
            next
          }

          # 1.0.2 Skip if this leg's new-commitment price is 0 for this
          # slot (check first row of slot)
          if (period_chunk[[price_col]][market_slot_rows[1]] == 0) {
            CONT_002 <- CONT_002 + 1
            next
          }

          # 1.0.3 Upward leg only: skip the slot without simulating it
          # when no system dominates. resolve_flex_up_system() is far
          # cheaper than a simulation, and flex_evaluation_up() would
          # decline the window anyway, so asking here saves the whole
          # inner loop for every start slot in a shoulder-season stretch.
          if (leg == "up" &&
              resolve_flex_up_system(period_chunk, market_slot_rows[1], parameters) == "none") {
            CONT_002 <- CONT_002 + 1
            next
          }

          # 1.1 Create period_chunk_test
          period_chunk_test <- period_chunk

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
          # place only, flex_evaluation_down()/flex_evaluation_up(), which
          # return the chunk untouched when the control horizon has not
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
            last_market_slot     <- unique_market_slots[last_market_slot_idx]
            last_slot_rows       <- which(period_chunk$MarketUTC == last_market_slot)

            # 1.2.2 If this leg's new-commitment price for the last
            # market_slot is 0, terminate the test
            if (period_chunk[[price_col]][last_slot_rows[1]] == 0) break

            # Calculate the commitment_phase_length for this test
            # (number of market slots * market slot duration in hours)
            commitment_phase_length <- n_slots_to_test * market_slot_h

            # Get the starting row index (first row of the first market slot)
            i_flex <- market_slot_rows[1]

            # 1.2.3 Generate period_chunk_test_inner with this leg's
            # evaluation function (flexibility <- 1) and reward_function.
            # Set flexibility parameters in simulation_control_2.
            simulation_control_2 <- simulation_control
            simulation_control_2$indexes_local$i_flex                  <- i_flex
            simulation_control_2$flexibility$commitment_phase_length  <- commitment_phase_length
            simulation_control_2$flexibility$flexibility               <- 1

            # The leg's evaluation function is called to apply this
            # candidate flexibility window (starting at i_flex, spanning
            # commitment_phase_length) to that leg's columns and simulate
            # the Neutral and Recovery Phases, so its
            # reward can be compared against the current best.
            period_chunk_test_inner <- evaluate_leg(period_chunk       = period_chunk_test,
                                                    parameters         = parameters,
                                                    simulation_control = simulation_control_2)

            # Compute the reward for this flexibility scenario
            period_chunk_test_inner <- reward_function(period_chunk       = period_chunk_test_inner,
                                                       parameters         = parameters,
                                                       simulation_control = simulation_control_2,
                                                       marginal_context   = marginal_context)

            # 1.2.4 Calculate reward_flex
            reward_flex <- sum(period_chunk_test_inner$Reward)

            # 1.2.5 If reward_flex is superior to reward
            if (reward_flex > reward) {
              # Overwrite reward
              reward <- reward_flex
              # Overwrite period_chunk
              period_chunk <- period_chunk_test_inner
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
          # build_system_lock_caps(), so there is nothing free to
          # commit there. Resuming at the end of the Commitment Phase,
          # which is what this did before, let a second window start
          # inside the Neutral Phase of the first, and left the two
          # indistinguishable in the committed energy written to
          # Main_df.
          CONT_002 <- CONT_002 + max(accepted_slots + tail_slots, 1)
        }

        return(list(period_chunk = period_chunk, reward = reward))
      }

      # Phase A, downward search, and phase B, upward search, over the
      # period_chunk phase A leaves behind.
      for (CONT_003 in c("down", "up")) {
        search_result <- search_flexibility_windows(period_chunk, reward, CONT_003)
        period_chunk  <- search_result$period_chunk
        reward        <- search_result$reward
      }

      rm(list = intersect(
        c("CONT_003", "search_result", "search_flexibility_windows",
          "market_slot_h", "max_commitment_slots", "flex_energy_tol",
          "unique_market_slots"),
        ls()
      ))

  } else {

    # For energy mode the reward was already computed above; nothing more to do.

  }

  return(list(period_chunk = period_chunk, reward = reward))
}
