# -------------------------------------------------------------
# Function: battery_factor_search.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Finds the largest factor between 0 and 1 with which a leg of a
# battery can be carried out over a stretch of steps. It is the
# factor of the battery in the draft of a flexibility window
# (battery_window_draft()), and the factor of what it holds of a
# window already sold (battery_window_hold()).
# The request of a factor f is the base request, with
#   base_request[k] + f * factor_energy[j]
# on each step k = factor_steps[j]. The leg is carried out with f:
#   - without the Recovery Phase, when no step of the stretch breaks
#     a limit of the battery, as battery_free_trajectory() finds;
#   - with the Recovery Phase, when the least correction of the
#     Recovery Phase carries the whole stretch out, as
#     battery_recovery_correction() finds it with every step checked
#     and no target energy. The correction never takes the leg past
#     the energy it stored before the window, reference_energy.
# If the factor 1 carries the leg out, it is 1. If not even the
# factor 0 does, nothing is found. Otherwise a bisection keeps the
# factor that carries it out, and the factor is the lower end of the
# last interval.
# This function checks the inputs. The search is made in compiled
# code, by battery_factor_search_cpp(), which tests every factor with
# the same physics as the R functions above, with the same operations
# in the same order.
# -------------------------------------------------------------
# Inputs
#   stored_energy_start : Numeric scalar. The energy stored before
#                         the first step (kWh).
#   delta_t_h           : Numeric vector. The duration of each step
#                         of the stretch (h).
#   base_request        : Numeric vector, as long as delta_t_h. The
#                         request of each step with the factor 0
#                         (kWh of the system side, positive to
#                         charge).
#   reference_energy    : Numeric vector, as long as delta_t_h. The
#                         energy the leg stored at the end of each
#                         step before the window (kWh). It is read
#                         only with the Recovery Phase.
#   factor_steps        : Integer vector. The steps the factor moves,
#                         positions in the stretch.
#   factor_energy       : Numeric vector, as long as factor_steps.
#                         The energy the factor 1 adds to each of
#                         those steps (kWh).
#   with_recovery       : Logical scalar. TRUE to carry the leg out
#                         with the least correction of the Recovery
#                         Phase.
#   recovery_steps      : Integer vector. The steps of the Recovery
#                         Phase, positions in the stretch. It may be
#                         empty, and it is read only with the
#                         Recovery Phase.
#   direction           : Numeric scalar, 1 to charge in the
#                         Recovery Phase and -1 to discharge.
#   battery             : Named list. The parameters of the battery
#                         (asset$battery).
#   bisection_steps     : Integer scalar. The halvings of each
#                         bisection.
#   tolerance           : Numeric scalar. The tolerance of the
#                         comparisons with the limits (kWh).
# -------------------------------------------------------------
# Outputs
#   Named list with:
#     - found: logical. FALSE when not even the factor 0 carries the
#       leg out.
#     - factor: numeric. The factor found, 0 when nothing is found.
#   The run stops if an input is missing, the vectors differ in
#   length, a step is outside the stretch or the direction is not 1
#   or -1.
# -------------------------------------------------------------
# Code outline
# 1. Check the inputs
# 2. Find the factor
# -------------------------------------------------------------
# Usage instructions
# search <- battery_factor_search(
#   stored_energy_start = 3,
#   delta_t_h           = rep(0.25, 8),
#   base_request        = rep(0, 8),
#   reference_energy    = rep(3, 8),
#   factor_steps        = 2:3,
#   factor_energy       = c(-1, -1),
#   with_recovery       = TRUE,
#   recovery_steps      = 5:6,
#   direction           = 1,
#   battery             = asset$battery,
#   bisection_steps     = 24,
#   tolerance           = 1e-9
# )
# -------------------------------------------------------------

battery_factor_search <- function(stored_energy_start,
                                  delta_t_h,
                                  base_request,
                                  reference_energy,
                                  factor_steps,
                                  factor_energy,
                                  with_recovery,
                                  recovery_steps,
                                  direction,
                                  battery,
                                  bisection_steps,
                                  tolerance
                                  ) {

  # -------------------------------------------------------------
  # 1. Check the inputs
  # -------------------------------------------------------------
  {
    n_steps <- length(delta_t_h)
    if (length(base_request) != n_steps ||
        length(reference_energy) != n_steps ||
        length(factor_energy) != length(factor_steps) ||
        !(length(direction) == 1 && direction %in% c(-1, 1)) ||
        !(is.logical(with_recovery) && length(with_recovery) == 1 &&
            !is.na(with_recovery)) ||
        anyNA(factor_steps) || anyNA(recovery_steps) ||
        any(factor_steps < 1 | factor_steps > n_steps) ||
        any(recovery_steps < 1 | recovery_steps > n_steps)) {
      stop("battery_factor_search: the steps do not match the ",
           "stretch, or the direction is not 1 or -1")
    }
    if (length(stored_energy_start) != 1 || is.na(stored_energy_start) ||
        anyNA(delta_t_h) || anyNA(base_request) ||
        anyNA(reference_energy) || anyNA(factor_energy) ||
        length(tolerance) != 1 || is.na(tolerance)) {
      stop("battery_factor_search: the stored energy, the duration of ",
           "a step, the request, the reference energy or the tolerance ",
           "has missing values")
    }
    rm(list = "n_steps")
  }

  # -------------------------------------------------------------
  # 2. Find the factor
  # -------------------------------------------------------------
  {
    # battery_factor_search_cpp is called to find, by bisection, the
    # largest factor with which the leg is carried out.
    search <- battery_factor_search_cpp(
      stored_energy_start = stored_energy_start,
      delta_t_h           = delta_t_h,
      base_request        = base_request,
      reference_energy    = reference_energy,
      factor_steps        = as.integer(factor_steps),
      factor_energy       = factor_energy,
      with_recovery       = with_recovery,
      recovery_steps      = as.integer(recovery_steps),
      direction           = direction,
      battery             = battery,
      bisection_steps     = as.integer(bisection_steps),
      tolerance           = tolerance
    )
  }

  return(search)
}
