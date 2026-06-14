# -------------------------------------------------------------
# Function: evaluate_control.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function evaluates the optimality of a control setpoint
# schedule over a particular period.
# This is a generic wrapper function that allows to integrate an
# optimizer with a simulation code in "period_calculation".
# It performs the following steps:
#   1. Calls period_calculation() to simulate the building over the
#      period and stores results in *_plan columns of period_chunk_plan.
#   2. Calls initialize_plan_flex_columns() to create the *_plan_flex
#      baseline from *_plan columns.
#   3. For "energy" mode, calls reward_function() directly on the
#      plan columns.
#   4. For "flexibility" mode, performs a parametric evaluation over
#      all market slots in period_chunk_plan as candidate flexibility
#      event start points. For each market slot:
#      - Skips if sum of Elec_total_plan is 0 or Flex_unit_cost_down_com is 0
#      - Tests expanding flexibility events by adding consecutive market slots
#      - Uses flexibility = 1 (full flexibility)
#      - Stops expanding when Flex_unit_cost_down_com is 0 or reward doesn't improve
#      The best reward across all candidates is returned.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. Simulation data for the period to evaluate.
#                  Must include the columns expected by period_calculation()
#                  (e.g. time, Text, SolarR, Elec_unit_cost_buy, Occupancy,
#                  MarketUTC, Ti, Te, Act_heat, Act_cool).
#   set_point_df : Data frame. Setpoint schedule with hysteresis deadbands
#                  already applied, as returned by convert_setpoints() or
#                  convert_modes_to_setpoints().
#   parameters   : Named list. Model and control parameters passed to
#                  period_calculation(), flex_evaluation(), and
#                  reward_function(). Must contain:
#                    parameters$control$optimization_aim :
#                      Character. "energy" or "flexibility".
#                    parameters$market$market_resolution :
#                      Numeric (minutes). Market slot duration used as the
#                      minimum flexibility event length step.
#   simulation_control : Named list. Simulation control object. Used to pass
#                        simulation_control$indexes_local$i_flex,
#                        simulation_control$flexibility$flexibility_event_length,
#                        and simulation_control$flexibility$flexibility to
#                        flex_evaluation() and reward_function() via a cloned object.
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
# 2. Initialize *_plan_flex baseline from *_plan
# 3. Evaluate flexibility scenarios (if optimization_aim is flexibility)
# 4. Compute reward function
# 5. Return results
# -------------------------------------------------------------
# Usage instructions
# result <- evaluate_control(period_chunk, set_point_df, parameters, simulation_control)
# -------------------------------------------------------------
# Where this function/script is used
# Called by optimize_control_step.R, fitness_funct_optimize_setpoint.R,
# and fitness_funct_optimize_mode.R
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - Simulation results are stored under execution column names (no suffix)
#     and then aliased to *_plan columns before reward_function() is called,
#     so that reward_function() can read Comfort_plan, Elec_total_plan, etc.
#   - For "flexibility" mode, evaluate_control() always initializes
#     *_plan_flex columns before calling flex_evaluation(). The loop skips
#     market slots where the sum of Elec_total_plan is 0, or where
#     Flex_unit_cost_down_com is 0 (no flexibility profit available).
#   - If all market slots are skipped in "flexibility" mode, the returned
#     reward is the baseline reward without flexibility.
#   - flexibility_event_length and flexibility are set in
#     simulation_control$flexibility and passed through to flex_evaluation()
#     and reward_function() via a cloned simulation_control_2 object.
# -------------------------------------------------------------
# functions/scripts called
#   period_calculation() - core building physics simulation
#   initialize_plan_flex_columns() - create *_plan_flex baseline
#   flex_evaluation()    - flexibility event simulation
#   reward_function()    - reward calculation
# -------------------------------------------------------------
evaluate_control <- function(period_chunk,
                             set_point_df=NULL,
                             parameters,
                             simulation_control) {

  # Simulate the building and energy system (execution context)
  period_chunk <- period_calculation(
    period_chunk        = period_chunk,
    parameters          = parameters,
    calculation_mode    = 1,
    calculation_context = "plan",
    set_point_df        = set_point_df
  )
  
  # Prepare flexibility baseline by copying *_plan to *_plan_flex columns
  period_chunk <- initialize_plan_flex_columns(period_chunk = period_chunk)

  # Compute the reward for this flexibility scenario
  period_chunk <- reward_function(
    period_chunk       = period_chunk,
    parameters         = parameters,
    simulation_control = simulation_control
  )
  reward <- sum(period_chunk$Reward)

  # For flexibility mode, find the best flexibility event start row
  if (parameters$control$optimization_aim == "flexibility" ||
      parameters$control$optimization_aim == "operationflex" ) {

      # 1 MarketUTC slot expressed in hours
      market_slot_h <- parameters$market$market_resolution / 60

      # Get unique market slots in period_chunk
      unique_market_slots <- unique(period_chunk$MarketUTC)

      # Loop 1: Iterate through each market_slot
      for (CONT_002 in seq_along(unique_market_slots)) {
        
        current_market_slot <- unique_market_slots[CONT_002]
        
        # Get all rows belonging to this market_slot
        market_slot_rows <- which(period_chunk$MarketUTC == current_market_slot)
        
        # 1.0.1 Skip if sum of Elec_total_plan for all observations in this
        # market_slot is 0 (use <= 0 to handle floating-point values that are
        # effectively zero)
        if (sum(period_chunk$Elec_total_plan[market_slot_rows]) <= 0) next
        
        # 1.0.2 Skip if Flex_unit_cost_down_com is 0 (check first row of slot)
        if (period_chunk$Flex_unit_cost_down_com[market_slot_rows[1]] == 0) next
        
        # 1.1 Create period_chunk_test
        period_chunk_test <- period_chunk
        
        # 1.2 Test flexibility by market slot
        # 1.2.1 Start with a single market_slot
        n_slots_to_test <- 1
        
        # Continue testing until we reach the end or stop condition
        while ((CONT_002 + n_slots_to_test - 1) <= length(unique_market_slots)) {
          
          # Get the last market_slot in the current test range
          last_market_slot_idx <- CONT_002 + n_slots_to_test - 1
          last_market_slot     <- unique_market_slots[last_market_slot_idx]
          last_slot_rows       <- which(period_chunk$MarketUTC == last_market_slot)
          
          # 1.2.2 If Flex_unit_cost_down_com for the last market_slot is 0,
          # terminate the test
          if (period_chunk$Flex_unit_cost_down_com[last_slot_rows[1]] == 0) break
          
          # Calculate the flexibility_event_length for this test
          # (number of market slots * market slot duration in hours)
          flexibility_event_length <- n_slots_to_test * market_slot_h
          
          # Get the starting row index (first row of the first market slot)
          i_flex <- market_slot_rows[1]
          
          # 1.2.3 Generate period_chunk_test_inner with flex_evaluation
          # (flexibility <- 1) and reward_function.
          # Set flexibility parameters in simulation_control_2.
          simulation_control_2 <- simulation_control
          simulation_control_2$indexes_local$i_flex                  <- i_flex
          simulation_control_2$flexibility$flexibility_event_length  <- flexibility_event_length
          simulation_control_2$flexibility$flexibility               <- 1

          period_chunk_test_inner <- flex_evaluation(period_chunk       = period_chunk_test,
                                                     parameters         = parameters,
                                                     simulation_control = simulation_control_2)
          
          # Compute the reward for this flexibility scenario
          period_chunk_test_inner <- reward_function(period_chunk       = period_chunk_test_inner,
                                                     parameters         = parameters,
                                                     simulation_control = simulation_control_2)
          
          # 1.2.4 Calculate reward_flex
          reward_flex <- sum(period_chunk_test_inner$Reward)
          
          # 1.2.5 If reward_flex is superior to reward
          if (reward_flex > reward) {
            # Overwrite reward
            reward <- reward_flex
            # Overwrite period_chunk
            period_chunk <- period_chunk_test_inner
            # Continue to next iteration: incorporate the next market_slot
            n_slots_to_test <- n_slots_to_test + 1
          } else {
            # 1.2.6 If reward_flex is equal or inferior to reward,
            # go back to point 1 at the next market_slot
            break
          }
        }
      }

  } else {

    # For energy mode the reward was already computed above; nothing more to do.

  }

  return(list(period_chunk = period_chunk, reward = reward))
}
