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
#                                reward_parameters$Alpha_Service_Min : Numeric. Weight applied to the
#                                                                  comfort penalty term. Defaults
#                                                                  to 10 with a warning if absent.
#                                control_parameters$optimization_aim : Character. "energy" or
#                                                                       "flexibility".
#                                control_parameters$flexibility_recover_timespan   : Numeric (h).
#                                control_parameters$thermal_stabilization_timespan : Numeric (h).
#   simulation_control       : Named list. Simulation control object. Must contain:
#                                simulation_control$indexes_local$i_flex : Integer scalar. Row number in
#                                  period_chunk at which the flexibility event starts.
#                                  Defaults to 1 when NULL or absent.
#                                simulation_control$flexibility$flexibility_event_length : Numeric
#                                  scalar. Duration of the flexibility event (h). Defaults to
#                                  parameters$control$flexibility_event_length_max when NULL.
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
# 1. Extract Alpha_Service_Min parameter
# 2. Extract i_flex and flexibility_event_length from simulation_control
# 3. Calculate delta_t per timestep
# 4. Compute electricity cost
# 5. Mode-specific reward (energy or flexibility)
# 6. Store per-row reward in data frame
# -------------------------------------------------------------
# Usage instructions
# result_df <- reward_function(period_chunk, parameters, simulation_control)
# -------------------------------------------------------------
# Where this function/script is used
# Called by evaluate_control.R
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If parameters$reward$Alpha_Service_Min is NULL, a default value
#     of Alpha_Service_Min = 10 is used and a warning() is issued.
#   - delta_t for the first row is set to 0 (no prior timestep).
#   - For the "flexibility" mode, flex revenue variables default to 0
#     outside the defined time windows.
#   - If optimization_aim is neither "energy" nor "flexibility", stop() is called.
#   - In "energy" mode, the comfort penalty is based on Comfort_plan.
#   - In "flexibility" mode, the comfort penalty applies if EITHER Comfort_plan
#     OR Comfort_plan_flex is 0 (out of comfort) for an occupied period.
#   - When simulation_control$indexes_local$i_flex is NULL, it defaults to 1 (first row).
#   - When simulation_control$flexibility$flexibility_event_length is NULL,
#     it falls back to parameters$control$flexibility_event_length_max.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
reward_function <- function(period_chunk, parameters,
                            simulation_control = NULL) {

  # 1. Get Alpha_Service_Min from reward_parameters
  if (!is.null(parameters$reward$Alpha_Service_Min)) {
    Alpha_Service_Min <- parameters$reward$Alpha_Service_Min
  } else {
    stop("Alpha_Service_Min was not found")
  }

  # 2. Extract i_flex and flexibility_event_length from simulation_control
  if (!is.null(simulation_control) &&
      !is.null(simulation_control$indexes_local$i_flex)) {
    i_flex <- simulation_control$indexes_local$i_flex
  } else {
    i_flex <- 1L
  }

  if (!is.null(simulation_control) &&
      !is.null(simulation_control$flexibility$flexibility_event_length)) {
    flexibility_event_length <- simulation_control$flexibility$flexibility_event_length
  } else {
    flexibility_event_length <- NULL
  }

  # 3. Calculate delta_t (minutes) for each row; first row gets 0.
  # period_chunk$time must be POSIXct; diff() returns seconds, /60 converts to minutes.
  delta_t <- c(0, as.numeric(diff(period_chunk$time)) / 60)

  # 4. Common calculations
  period_chunk$Elec_Cost <- period_chunk$Elec_total_plan * period_chunk$Elec_unit_cost_buy * delta_t

  # 5. Mode-specific reward calculation
  optimization_aim <- parameters$control$optimization_aim

  if (optimization_aim == "energy" || 
      (optimization_aim == "flexibility" && 
       (is.null(i_flex) ||
        i_flex == 0 ||
        is.null(flexibility_event_length)
        ||
        flexibility_event_length == 0
        )
       )
      ) {
    # In energy mode, comfort penalty is based on Comfort_plan
    Performance_plan <- ifelse(period_chunk$Occupancy == 1 & period_chunk$Comfort_plan == 0, -1, 0) * delta_t

    Reward <- Alpha_Service_Min * Performance_plan - period_chunk$Elec_Cost

  } else if (optimization_aim == "flexibility"  ||
             optimization_aim =="operationflex") {

    period_chunk$Elec_flex_plan <- period_chunk$Elec_total_plan - period_chunk$Elec_total_plan_flex

    # In flexibility mode, penalty applies if EITHER plan AND plan_flex is out of comfort
    Performance_flex <- ifelse(period_chunk$Occupancy == 1 &
                                 (period_chunk$Comfort_plan == 0 & period_chunk$Comfort_plan_flex == 0),
                               -1, 0) * delta_t

    # Time windows for flexibility revenue (based on i_flex)
    if (is.null(flexibility_event_length)) {
      flexibility_event_length <- parameters$control$flexibility_event_length_max
    }
    flexibility_recover_timespan   <- parameters$control$flexibility_recover_timespan
    thermal_stabilization_timespan <- parameters$control$thermal_stabilization_timespan

    time_i_flex <- period_chunk$time[i_flex]

    # 5.1 Flex event window: i_flex to i_flex + flexibility_event_length
    end_flex      <- time_i_flex + flexibility_event_length * 3600
    in_flex_event <- period_chunk$time >= time_i_flex & period_chunk$time <= end_flex

    # 5.2 Stabilisation window: i_flex + flex_length + recover to + thermal_stabilization
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
                                                              0)
                                                       )

    period_chunk$Elec_flex_revenue_plan <- period_chunk$Elec_flex_com_revenue_plan + period_chunk$Elec_flex_exec_revenue_plan * period_chunk$Flex_Probab

    Reward <- Alpha_Service_Min * Performance_flex -
              period_chunk$Elec_Cost +
              period_chunk$Elec_flex_revenue_plan

  } else {
    stop("Invalid optimization_aim: '", optimization_aim, "'. Must be 'energy' or 'flexibility'.")
  }

  # 6. Store per-row reward in period_chunk and return the data frame
  period_chunk$Reward <- Reward
  return(period_chunk)
}
