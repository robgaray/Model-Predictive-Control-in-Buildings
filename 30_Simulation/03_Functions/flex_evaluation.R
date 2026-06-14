# -------------------------------------------------------------
# Function: flex_evaluation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function evaluates the impact of a flexibility event on a
# planning period. It reduces heating and cooling by a given
# flexibility fraction during the flexibility event, runs a simulation
# for the recovery and thermal-stabilisation window, and reconciles
# the results back into the full period chunk.
# -------------------------------------------------------------
# Inputs
#   period_chunk             : Data frame. Planning-period data (corresponds to
#                              period_chunk_plan in the caller).  Must contain
#                              *_plan columns produced by period_calculation with
#                              calculation_context = "plan", and matching
#                              *_plan_flex baseline columns already initialized.
#   parameters               : Named list. Model and control parameters.  Must include
#                              parameters$control$flexibility_event_length_max,
#                              flexibility_recover_timespan,
#                              thermal_stabilization_timespan (all in hours), and
#                              minimum_flexibility (kW).
#   simulation_control       : Named list. Simulation control object. Must contain:
#                              simulation_control$indexes_global$i_flex (Integer scalar.
#                              Row number in period_chunk at which the flexibility
#                              event starts).
#                              simulation_control$flexibility$flexibility_event_length
#                              (Numeric scalar. Duration of the flexibility event (h).
#                              Must be <= flexibility_event_length_max.)
#                              simulation_control$flexibility$flexibility
#                              (Numeric scalar in (0, 1]. Fraction of flexibility to
#                              apply (1 = full flexibility, i.e. maximum reduction).)
# -------------------------------------------------------------
# Outputs
#   period_chunk : Data frame. The input data frame with *_plan_flex
#                  columns updated. Corresponds to
#                  period_chunk in the caller.
#                  Returned unchanged if there is not enough time
#                  remaining from i_flex to accommodate the full
#                  flexibility window.
# -------------------------------------------------------------
# Code outline
# 1. Extract flexibility parameters from simulation_control
# 2. Modify Q_heat/Q_cool in *_plan_flex during flexibility window
# 3. Run period_calculation for plan_flex context
# 4. Reconcile subset simulation into full period_chunk
# -------------------------------------------------------------
# Usage instructions
# result_df <- flex_evaluation(period_chunk, parameters, simulation_control)
# -------------------------------------------------------------
# Where this function/script is used
# Called by evaluate_control.R during flexibility optimization.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - simulation_control$indexes_global$i_flex must be a single integer row index within period_chunk.
#   - simulation_control$flexibility$flexibility_event_length must be <= flexibility_event_length_max.
#   - simulation_control$flexibility$flexibility must be in (0, 1].
#   - If the time distance from i_flex to the last row of period_chunk
#     is less than flexibility_event_length + flexibility_recover_timespan
#     + thermal_stabilization_timespan (hours), period_chunk is returned
#     without any changes.
#   - This function assumes *_plan_flex baseline columns already exist
#     (initialized by evaluate_control() through
#     initialize_plan_flex_columns()).
#   - The Q_heat_plan_flex and Q_cool_plan_flex values during the flex
#     event are set to Q_*_plan * (1 - flexibility), corrected so that
#     they are at least minimum_flexibility * delta_t smaller than the
#     corresponding Q_*_plan values (clamped to 0 from below).
#   - delta_t is computed in minutes, consistent with period_calculation().
# -------------------------------------------------------------
# functions/scripts called
#   period_calculation() - core building physics simulation, called with
#                          calculation_context = "plan_flex"
# -------------------------------------------------------------
flex_evaluation <- function(period_chunk, parameters, simulation_control) {

  i_flex                   <- simulation_control$indexes_global$i_flex
  flexibility_event_length <- simulation_control$flexibility$flexibility_event_length
  flexibility              <- simulation_control$flexibility$flexibility

  # Extract flexibility parameters
  flexibility_recover_timespan   <- parameters$control$flexibility_recover_timespan
  thermal_stabilization_timespan <- parameters$control$thermal_stabilization_timespan
  minimum_flexibility            <- parameters$control$minimum_flexibility

  total_window_h <- flexibility_event_length + flexibility_recover_timespan + thermal_stabilization_timespan

  # Validate i_flex
  stopifnot(is.numeric(i_flex), length(i_flex) == 1,
            i_flex >= 1, i_flex <= nrow(period_chunk))

  time_at_i_flex <- period_chunk$time[i_flex]
  time_at_end    <- period_chunk$time[nrow(period_chunk)]

  # Check whether enough time remains for the full flexibility window
  time_distance_h <- as.numeric(difftime(time_at_end, time_at_i_flex, units = "hours"))
  if (time_distance_h < total_window_h) {
    return(period_chunk)
  }

  # Generate period_chunk_subset: rows from i_flex to i_flex + total_window_h hours
  end_time_subset <- time_at_i_flex + total_window_h * 3600
  subset_rows <- which(period_chunk$time >= time_at_i_flex &
                         period_chunk$time <= end_time_subset)
  period_chunk_subset <- period_chunk[subset_rows, ]

  # Apply flexibility reduction to Q_heat_plan_flex and Q_cool_plan_flex
  # up to flexibility_event_length.
  # Reduction formula: Q_*_plan_flex = Q_*_plan * (1 - flexibility)
  # Corrected so that Q_*_plan_flex is at least minimum_flexibility * delta_t
  # smaller than Q_*_plan (clamped to 0 from below).
  # delta_t is in minutes, consistent with period_calculation().
  end_time_flex    <- time_at_i_flex + flexibility_event_length * 3600
  flex_rows_subset <- which(period_chunk_subset$time <= end_time_flex)

  if (length(flex_rows_subset) > 0) {
    # Compute delta_t (minutes) for each flex row, mirroring period_calculation().
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
    all_times_with_prev <- c(prev_time_first, times_subset)
    delta_t_subset <- as.numeric(diff(as.numeric(all_times_with_prev))) / 60
    delta_t_flex <- delta_t_subset[flex_rows_subset]

    # Compute minimum-corrected flex values
    Q_heat_plan_flex <- pmax(
      0,
      pmin(
        period_chunk_subset$Q_heat_plan[flex_rows_subset] * (1 - flexibility),
        period_chunk_subset$Q_heat_plan[flex_rows_subset] - (minimum_flexibility * delta_t_flex)
      )
    )
    Q_cool_plan_flex <- pmax(
      0,
      pmin(
        period_chunk_subset$Q_cool_plan[flex_rows_subset] * (1 - flexibility),
        period_chunk_subset$Q_cool_plan[flex_rows_subset] - minimum_flexibility * delta_t_flex
      )
    )

    period_chunk_subset$Q_heat_plan_flex[flex_rows_subset] <- Q_heat_plan_flex
    period_chunk_subset$Q_cool_plan_flex[flex_rows_subset] <- Q_cool_plan_flex
    rm(Q_heat_plan_flex, Q_cool_plan_flex, delta_t_flex, delta_t_subset, all_times_with_prev,
       prev_time_first, times_subset)
  }
  rm(end_time_flex, flex_rows_subset)

  # Build calculation_mode vector:
  #   2 (Heat Input) up to flexibility_event_length + flexibility_recover_timespan
  #   1 (Setpoint)   for the thermal stabilisation period
  end_time_mode2 <- time_at_i_flex +
    (flexibility_event_length + flexibility_recover_timespan) * 3600
  calculation_mode_vec <- ifelse(period_chunk_subset$time <= end_time_mode2, 2L, 1L)
  rm(end_time_mode2)

  # Simulate the flexibility window
  period_chunk_subset <- period_calculation(period_chunk_subset,
                                            parameters,
                                            calculation_mode    = calculation_mode_vec,
                                            calculation_context = "plan_flex")
  rm(calculation_mode_vec)

  # Defensive check: ensure period_chunk_subset rows match subset_rows
  if (nrow(period_chunk_subset) != length(subset_rows)) {
    warning("flex_evaluation: period_chunk_subset has ", nrow(period_chunk_subset),
            " rows but subset_rows has ", length(subset_rows),
            " elements. Returning period_chunk unchanged.")
    return(period_chunk)
  }

  # Reconcile period_chunk_subset back into period_chunk
  period_chunk[subset_rows, ] <- period_chunk_subset
  rm(subset_rows, period_chunk_subset, end_time_subset)

  return(period_chunk)
}
