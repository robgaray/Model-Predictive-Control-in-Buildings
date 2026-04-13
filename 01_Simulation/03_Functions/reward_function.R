# -------------------------------------------------------------
# Function: reward_function.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function calculates a reward function on the adequacy of
# a particular building HVAC operation over a planning period.
# It reads a period_chunk data frame and operates in two modes
# depending on parameters$control$optimization_aim:
#   "energy"      - minimise energy cost while maintaining comfort
#   "flexibility" - additionally account for flexibility revenue
# -------------------------------------------------------------
# Inputs
#   period_chunk             : Data frame. Planning-period data with *_plan (and,
#                              for "flexibility" mode, *_plan_flex) columns produced
#                              by period_calculation() and flex_evaluation().
#                              Required columns:
#                                time             - POSIXct. Simulation timestamps.
#                                Occupancy        - Numeric (0/1). Occupancy flag.
#                                Comfort_plan     - Numeric (0/1). Comfort flag (plan).
#                                Elec_total_plan  - Numeric. Total electricity (plan).
#                                Elec_unit_cost_buy   - Numeric. Electricity buy price.
#                              Additional columns required for "flexibility" mode:
#                                Comfort_plan_flex    - Numeric (0/1). Comfort flag (plan_flex).
#                                Elec_total_plan_flex - Numeric. Total electricity (plan_flex).
#                                Flex_unit_cost_down_com  - Numeric. Commitment flexibility price (down).
#                                Flex_unit_cost_down_exec - Numeric. Execution flexibility price (down).
#                                Flex_Probab          - Numeric. Flexibility execution probability.
#   parameters               : Named list. Must contain:
#                                reward_parameters$Alpha_confort : Numeric. Weight applied to the
#                                                                  comfort penalty term. Defaults
#                                                                  to 10 with a warning if absent.
#                                control_parameters$optimization_aim : Character. "energy" or
#                                                                       "flexibility".
#                                control_parameters$flexibility_recover_timespan   : Numeric (h).
#                                control_parameters$thermal_stabilization_timespan : Numeric (h).
#   i_flex                   : Integer scalar. Row number in period_chunk at which the
#                              flexibility event starts.  Defaults to 1 (first row).
#                              Used to derive time_i_flex = period_chunk$time[i_flex].
#   flexibility_event_length : Numeric scalar. Duration of the flexibility event (h).
#                              Defaults to
#                              parameters$control$flexibility_event_length_max
#                              when NULL.
# -------------------------------------------------------------
# Outputs
#   period_chunk : Data frame. The input data frame with a 'Reward' column
#                  added (or overwritten) containing the per-row reward value
#                  for each timestep, plus the following intermediate result
#                  columns (all modes):
#                    Elec_Cost                  - Numeric. Electricity cost per timestep.
#                  Additional columns added in "flexibility" mode:
#                    Elec_flex_plan             - Numeric. Energy difference (plan - plan_flex).
#                    Elec_flex_com_revenue_plan  - Numeric. Commitment flexibility revenue per timestep.
#                    Elec_flex_exec_revenue_plan - Numeric. Execution flexibility revenue per timestep.
#                    Elec_flex_revenue_plan      - Numeric. Total flexibility revenue per timestep.
#                  The caller is responsible for summing the Reward column
#                  when a scalar reward is required.
# -------------------------------------------------------------
# Code outline
# 1. Extract Alpha_confort parameter
# 2. Calculate delta_t per timestep
# 3. Compute electricity cost
# 4. Mode-specific reward (energy or flexibility)
# 5. Store per-row reward in data frame
# -------------------------------------------------------------
# Usage instructions
# result_df <- reward_function(period_chunk, parameters)
# result_df <- reward_function(period_chunk, parameters, i_flex = 10, flexibility_event_length = 2)
# -------------------------------------------------------------
# Where this function/script is used
# Called by evaluate_control.R
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If parameters$reward$Alpha_confort is NULL, a default value
#     of Alpha_confort = 10 is used and a warning() is issued.
#   - delta_t for the first row is set to 0 (no prior timestep).
#   - For the "flexibility" mode, flex revenue variables default to 0
#     outside the defined time windows.
#   - If optimization_aim is neither "energy" nor "flexibility", stop() is called.
#   - In "energy" mode, the comfort penalty is based on Comfort_plan.
#   - In "flexibility" mode, the comfort penalty applies if EITHER Comfort_plan
#     OR Comfort_plan_flex is 0 (out of comfort) for an occupied period.
#   - When flexibility_event_length is NULL, it falls back to
#     parameters$control$flexibility_event_length_max.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
reward_function <- function(period_chunk, parameters,
                            i_flex = 1L,
                            flexibility_event_length = NULL) {

  # 1. Get Alpha_confort from reward_parameters
  if (!is.null(parameters$reward$Alpha_confort)) {
    Alpha_confort <- parameters$reward$Alpha_confort
  } else {
    warning("Alpha_confort was not found. A default value of Alpha_confort=10 is used.")
    Alpha_confort <- 10
  }

  # 2. Calculate delta_t (minutes) for each row; first row gets 0.
  # period_chunk$time must be POSIXct; diff() returns seconds, /60 converts to minutes.
  delta_t <- c(0, as.numeric(diff(period_chunk$time)) / 60)

  # 3. Common calculations
  period_chunk$Elec_Cost <- period_chunk$Elec_total_plan * period_chunk$Elec_unit_cost_buy * delta_t

  # 4. Mode-specific reward calculation
  optimization_aim <- parameters$control$optimization_aim

  if (optimization_aim == "energy") {

    # In energy mode, comfort penalty is based on Comfort_plan
    Performance_plan <- ifelse(period_chunk$Occupancy == 1 & period_chunk$Comfort_plan == 0, -1, 0) * delta_t

    Reward <- Alpha_confort * Performance_plan - period_chunk$Elec_Cost

  } else if (optimization_aim == "flexibility") {

    period_chunk$Elec_flex_plan <- period_chunk$Elec_total_plan - period_chunk$Elec_total_plan_flex

    # In flexibility mode, penalty applies if EITHER plan OR plan_flex is out of comfort
    Performance_flex <- ifelse(period_chunk$Occupancy == 1 &
                                 (period_chunk$Comfort_plan == 0 | period_chunk$Comfort_plan_flex == 0),
                               -1, 0) * delta_t

    # Time windows for flexibility revenue (based on i_flex)
    if (is.null(flexibility_event_length)) {
      flexibility_event_length <- parameters$control$flexibility_event_length_max
    }
    flexibility_recover_timespan   <- parameters$control$flexibility_recover_timespan
    thermal_stabilization_timespan <- parameters$control$thermal_stabilization_timespan

    time_i_flex <- period_chunk$time[i_flex]

    # 2.1 Flex event window: i_flex to i_flex + flexibility_event_length
    end_flex      <- time_i_flex + flexibility_event_length * 3600
    in_flex_event <- period_chunk$time >= time_i_flex & period_chunk$time <= end_flex

    # 2.2 Stabilisation window: i_flex + flex_length + recover to + thermal_stabilization
    start_stab <- time_i_flex + (flexibility_event_length + flexibility_recover_timespan) * 3600
    end_stab   <- start_stab + thermal_stabilization_timespan * 3600
    in_stab    <- period_chunk$time >= start_stab & period_chunk$time <= end_stab

    # Commitment revenue (only during flex event)
    period_chunk$Elec_flex_com_revenue_plan <- ifelse(in_flex_event,
                                    period_chunk$Elec_flex_plan * period_chunk$Flex_unit_cost_down_com * delta_t,
                                    0)

    # Execution revenue (different formula for each window; 0 elsewhere)
    period_chunk$Elec_flex_exec_revenue_plan <- ifelse(in_flex_event,
                                     period_chunk$Elec_flex_plan * period_chunk$Elec_unit_cost_buy * delta_t +
                                       period_chunk$Elec_flex_plan * period_chunk$Flex_unit_cost_down_exec * delta_t,
                                     ifelse(in_stab,
                                            -period_chunk$Elec_flex_plan * period_chunk$Elec_unit_cost_buy * delta_t,
                                            0))

    period_chunk$Elec_flex_revenue_plan <- period_chunk$Elec_flex_com_revenue_plan + period_chunk$Elec_flex_exec_revenue_plan * period_chunk$Flex_Probab

    Reward <- Alpha_confort * Performance_flex -
              period_chunk$Elec_Cost +
              period_chunk$Elec_flex_revenue_plan

  } else {
    stop("Invalid optimization_aim: '", optimization_aim, "'. Must be 'energy' or 'flexibility'.")
  }

  # 5. Store per-row reward in period_chunk and return the data frame
  period_chunk$Reward <- Reward
  return(period_chunk)
}