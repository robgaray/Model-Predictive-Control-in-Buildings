# -------------------------------------------------------------
# Function: check_recovery_convergence.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Decides whether a flexibility itinerary has converged back to the
# itinerary of origin by the end of the control horizon.
# -------------------------------------------------------------
# What this protects
# The baseline against which the next market optimizes is the output
# of this one, which keeps whatever is written when the control
# horizon closes. If
# a flexibility itinerary is still deviating at that moment, the next
# market inherits a trajectory that has not settled and its marginal
# valuation starts from a false baseline. A candidate window that leaves
# the building in that state is therefore rejected, however profitable
# it looks on its own.
# The check is made at the end of the CONTROL HORIZON, not at the end of
# the Recovery Phase. The difference matters and is deliberate: a window
# that finishes well before the horizon closes passes the check without
# effort, because by then the flexibility columns are the copy of the
# plan that derive_flex_itineraries() laid as baseline and the
# difference is exactly zero. The check bites on the windows whose Recovery Phase
# reaches the close of the horizon, which are precisely the ones that
# can hand over a dirty state.
# -------------------------------------------------------------
# The two criteria
# Over the last recovery_convergence_window minutes of the control
# horizon, with E the energy of each itinerary aggregated over that
# window:
#
#   converged  if  | E_flex - E_plan | / | E_plan |  <  tol_rel
#              or  | E_flex - E_plan | / window_h    <  tol_abs
#
# Meeting either one is enough. The second is not redundant: the
# relative criterion becomes unstable when the itinerary of origin
# consumes little or nothing, since the denominator tends to zero and a
# difference that is irrelevant in absolute terms turns into a huge
# percentage. A threshold on power covers exactly that case, which is
# why the two are in disjunction and not in conjunction.
# -------------------------------------------------------------
# Inputs
#   period_chunk  : Data frame. The full planning-period chunk, after the
#                   flexibility window has been reconciled into it. Must
#                   contain time, Elec_total_plan and the flex column
#                   named by flex_col.
#   flex_col      : Character scalar. Name of the flexibility itinerary's
#                   electricity column, "Elec_total_plan_flex_down" or
#                   "Elec_total_plan_flex_up".
#   i_end_control : Integer scalar. Row of period_chunk where the control
#                   horizon ends.
#   parameters    : Named list. Must contain
#                   parameters$control$recovery_convergence_window (min),
#                   recovery_convergence_tol_rel (%) and
#                   recovery_convergence_tol_abs (kW).
# -------------------------------------------------------------
# Outputs
#   Logical scalar. TRUE when the itinerary has converged.
# -------------------------------------------------------------
# Code outline
# 1. Resolve the window in whole timesteps
# 2. Aggregate both itineraries over it
# 3. Apply the two criteria in disjunction
# -------------------------------------------------------------
# Usage instructions
# ok <- check_recovery_convergence(period_chunk, "Elec_total_plan_flex_down",
#                                  i_end_control, parameters)
# -------------------------------------------------------------
# Where this function/script is used
#   - flex_evaluation_down()
#   - flex_evaluation_up()
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - The window is given in minutes and the mesh is in timesteps, so
#     the number of rows is round(window_min * 60 / timestep_seconds),
#     with a floor of one row. Nothing here assumes that the window is a
#     whole number of timesteps: with 30 min and 5-minute steps it is 6
#     rows, and with 7 min it is 1 row rather than 0.
#   - The absolute tolerance is a POWER (kW) while the Elec_total_*
#     columns hold the step's ENERGY (kWh). The energy difference is
#     therefore divided by the length of the window in hours, which
#     turns it into the mean power difference over the window and makes
#     the comparison dimensionally correct.
#   - An itinerary of origin with zero energy over the window makes the
#     relative criterion undefined. It is treated as not met, and the
#     decision is left to the absolute criterion, which is well defined
#     there and is the reason it exists.
#   - i_end_control outside the bounds of period_chunk is clamped to the
#     last row, so a chunk shorter than its own control horizon does not
#     produce an out-of-range index.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
check_recovery_convergence <- function(period_chunk,
                                       flex_col,
                                       i_end_control,
                                       parameters) {

  # 1. Resolve the window in whole timesteps
  # -------------------------------------------------------------
  {
    window_min <- parameters$control$recovery_convergence_window
    tol_rel    <- parameters$control$recovery_convergence_tol_rel / 100
    tol_abs    <- parameters$control$recovery_convergence_tol_abs

    if (is.null(window_min) || is.null(tol_rel) || is.null(tol_abs)) {
      stop("check_recovery_convergence: recovery_convergence_window, ",
           "recovery_convergence_tol_rel and recovery_convergence_tol_abs ",
           "are all mandatory in parameters$control")
    }

    timestep_sec <- as.numeric(difftime(period_chunk$time[2],
                                        period_chunk$time[1], units = "secs"))

    n_rows <- max(1L, as.integer(round(window_min * 60 / timestep_sec)))

    i_last  <- min(as.integer(i_end_control), nrow(period_chunk))
    i_first <- max(1L, i_last - n_rows + 1L)
    conv_rows <- i_first:i_last

    window_h <- length(conv_rows) * timestep_sec / 3600
  }

  # 2. Aggregate both itineraries over it
  # -------------------------------------------------------------
  {
    E_plan <- sum(period_chunk$Elec_total_plan[conv_rows])
    E_flex <- sum(period_chunk[[flex_col]][conv_rows])
    deviation <- abs(E_flex - E_plan)
  }

  # 3. Apply the two criteria in disjunction
  # -------------------------------------------------------------
  {
    met_rel <- if (abs(E_plan) > 0) (deviation / abs(E_plan) < tol_rel) else FALSE
    met_abs <- (deviation / window_h) < tol_abs

    converged <- met_rel || met_abs
  }

  rm(window_min, tol_rel, tol_abs, timestep_sec, n_rows, i_last, i_first,
     conv_rows, window_h, E_plan, E_flex, deviation, met_rel, met_abs)

  return(converged)
}
