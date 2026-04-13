# -------------------------------------------------------------
# Function: evaluate_control.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function evaluates the optimality of a control setpoint
# schedule over a particular period.
# This is a generic wrapper function that allows to integrate an
# optimizer with a simulation code in "period_calculation".
# It performs the following steps:
#   1. Calls period_calculation() to simulate the building over the
#      period and stores results in *_plan columns of period_chunk_plan.
#   2. Copies every *_plan column to a matching *_plan_flex column so
#      that the baseline (no flexibility event) is the starting reward.
#   3. For "energy" mode, calls reward_function() directly on the
#      plan columns.
#   4. For "flexibility" mode, performs a parametric evaluation over
#      all rows of period_chunk_plan as candidate flexibility event
#      start points (i_flex, Loop 1), over event lengths from 1 MarketUTC
#      slot to flexibility_event_length_max (Loop 2), and over flexibility
#      fractions n/flexibility_splits for n in 1..flexibility_splits
#      (Loop 3).  For each combination where Elec_total > 0, calls
#      flex_evaluation() and reward_function() to evaluate the resulting
#      reward.  The best reward across all candidates is returned.
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
#                    parameters$control$flexibility_event_length_max :
#                      Numeric (h). Maximum flexibility event length.
#                    parameters$control$flexibility_splits :
#                      Integer. Number of flexibility fraction steps.
#                    parameters$optimization$market_resolution :
#                      Numeric (minutes). Market slot duration used as the
#                      minimum flexibility event length step.
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
#                  flexibility candidate start rows (for "flexibility"
#                  mode), or the direct reward from the plan (for
#                  "energy" mode).
# -------------------------------------------------------------
# Code outline
# 1. Copy plan columns from period_chunk
# 2. Run period_calculation for plan context
# 3. Evaluate flexibility scenarios (if optimization_aim is flexibility)
# 4. Compute reward function
# 5. Return results
# -------------------------------------------------------------
# Usage instructions
# result <- evaluate_control(period_chunk, set_point_df, parameters)
# -------------------------------------------------------------
# Where this function/script is used
# Called by optimize_control_step.R, fitness_funct_optimize_setpoint.R,
# and fitness_funct_optimize_mode.R
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - Simulation results are stored under execution column names (no suffix)
#     and then aliased to *_plan columns before reward_function() is called,
#     so that reward_function() can read Comfort_plan, Elec_total_plan, etc.
#   - For "flexibility" mode, flex_evaluation() adds *_plan_flex columns
#     required by reward_function(). The loop skips rows where Elec_total
#     is <= 0 (no electricity consumption at that timestep, or effectively
#     zero due to floating-point representation).
#   - If all rows have Elec_total <= 0 in "flexibility" mode, the returned
#     reward is -Inf.
# -------------------------------------------------------------
# functions/scripts called
#   period_calculation() - core building physics simulation
#   flex_evaluation()    - flexibility event simulation
#   reward_function()    - reward calculation
# -------------------------------------------------------------
evaluate_control <- function(period_chunk,
                             set_point_df,
                             parameters) {

  # Simulate the building and energy system (execution context)
  period_chunk <- period_calculation(
    period_chunk        = period_chunk,
    parameters          = parameters,
    calculation_mode    = 1,
    calculation_context = "plan",
    set_point_df        = set_point_df
  )
  
  # Prepare for flexibility assessment by copying plan columns to plan_flex columns
  plan_cols <- grep("_plan$", names(period_chunk), value = TRUE)
  for (CONT_001 in plan_cols) {
    period_chunk[[paste0(CONT_001, "_flex")]] <- period_chunk[[CONT_001]]
  }
  rm(plan_cols, CONT_001)

  # Compute the reward for this flexibility scenario
  period_chunk <- reward_function(
    period_chunk = period_chunk,
    parameters   = parameters
  )
  reward <- sum(period_chunk$Reward)

  # For flexibility mode, find the best flexibility event start row
  if (parameters$control$optimization_aim == "flexibility") {

      # 1 MarketUTC slot expressed in hours
      market_slot_h <- parameters$optimization$market_resolution / 60

      for (CONT_002 in seq_len(nrow(period_chunk))) {
        
        period_chunk_test <- period_chunk

        # Skip rows where no electricity is consumed (use <= 0 to handle
        # floating-point values that are effectively zero)
        if (period_chunk_test$Elec_total_plan[CONT_002] <= 0) next
        
        # Skip rows where flexibility provides no profit
        if (period_chunk_test$Flex_unit_cost_down_com[CONT_002]  == 0 &
            period_chunk_test$Flex_unit_cost_down_exec[CONT_002] == 0) next

        # Loop 2: iterate flexibility_event_length from 1 MarketUTC slot to max
        for (CONT_003 in seq(market_slot_h,
                             parameters$control$flexibility_event_length_max,
                             by = market_slot_h)) {

          # Loop 3: iterate flexibility fraction n/flexibility_splits
          for (CONT_004 in seq_len(parameters$control$flexibility_splits)) {
            flexibility <- CONT_004 / parameters$control$flexibility_splits

            # Evaluate the flexibility scenario starting at row i_flex
            period_chunk_test_inner <- flex_evaluation(
              period_chunk             = period_chunk_test,
              parameters               = parameters,
              i_flex                   = CONT_002,
              flexibility_event_length = CONT_003,
              flexibility              = flexibility
            )

            # Compute the reward for this flexibility scenario
            period_chunk_test_inner <- reward_function(
              period_chunk             = period_chunk_test_inner,
              parameters               = parameters,
              i_flex                   = CONT_002,
              flexibility_event_length = CONT_003
            )
            reward_flex <- sum(period_chunk_test_inner$Reward)

            # Keep the best reward found so far
            if (reward_flex > reward) {
              reward <- reward_flex
              period_chunk <- period_chunk_test_inner
            }
          }
        }
      }

  } else {

    # For energy mode the reward was already computed above; nothing more to do.

  }

  return(list(period_chunk = period_chunk, reward = reward))
}
