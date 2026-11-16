# -------------------------------------------------------------
# Function: battery_free_trajectory.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Computes the energy a battery would store over a run of steps if
# nothing limited it, and says on which steps the request breaks a
# limit of the battery. It is the test the flexibility windows use to
# decide whether a request can be carried out: it does not clip the
# request, as battery_trajectory() does, it reports where the
# request could not be served.
# While no step breaks a limit it gives the same energy as
# battery_trajectory(), up to the rounding.
# With the same symbols as battery_trajectory(), in each step k:
#   1. in_k   <- eta_c * max(R_k, 0) - max(-R_k, 0) / eta_d
#        The energy that enters the battery (kWh).
#   2. F_k    <- product, for j up to k, of f_j, with
#        f_j <- (1 - s)^(dt_j / 24), the share of the energy that
#        the battery keeps in the step j.
#   3. E_k    <- F_k * (E_0 + sum, for j up to k, of in_j / F_j)
#        The energy stored at the end of the step (kWh).
# A step breaks the lower side when it discharges and either the
# energy falls below E_min or the electricity it gives is above P_d
# times the duration of the step. It breaks the upper side when it
# charges and either the energy rises above E_max or the electricity
# it takes is above P_c times the duration of the step. All the
# comparisons have a tolerance.
# This function checks the inputs. The run is computed in compiled
# code, by battery_free_trajectory_cpp(), with the same operations in
# the same order. The sum and the product are accumulated as R
# accumulates cumsum() and cumprod().
# -------------------------------------------------------------
# Inputs
#   stored_energy_start : Numeric scalar. The energy stored before
#                         the first step (kWh).
#   delta_t_h           : Numeric vector. The duration of each step
#                         (h).
#   energy_request      : Numeric vector, as long as delta_t_h. The
#                         request of each step (kWh of the system
#                         side, positive to charge).
#   battery             : Named list. The parameters of the battery
#                         (asset$battery).
#   tolerance           : Numeric scalar. The tolerance of the
#                         comparisons with the limits (kWh).
# -------------------------------------------------------------
# Outputs
#   Named list of vectors as long as delta_t_h:
#     - stored_energy: numeric, the energy stored at the end of each
#       step (kWh).
#     - breach: logical, TRUE on the steps that break a limit.
#     - breach_low: logical, TRUE on the steps that break a limit
#       while discharging.
#     - breach_high: logical, TRUE on the steps that break a limit
#       while charging.
#   breach is breach_low or breach_high. The run stops if an input
#   is missing or the vectors differ in length.
# -------------------------------------------------------------
# Code outline
# 1. Check the inputs
# 2. Run the steps
# -------------------------------------------------------------
# Usage instructions
# free <- battery_free_trajectory(
#   stored_energy_start = 5,
#   delta_t_h           = rep(0.25, 4),
#   energy_request      = c(1, 1, -1, -1),
#   battery             = asset$battery,
#   tolerance           = parameters$computing$flex_energy_tol
# )
# -------------------------------------------------------------

battery_free_trajectory <- function(stored_energy_start,
                                    delta_t_h,
                                    energy_request,
                                    battery,
                                    tolerance
                                    ) {

  # -------------------------------------------------------------
  # 1. Check the inputs
  # -------------------------------------------------------------
  {
    n_steps <- length(delta_t_h)
    if (length(energy_request) != n_steps) {
      stop("battery_free_trajectory: delta_t_h and energy_request have ",
           n_steps, " and ", length(energy_request), " elements")
    }
    if (length(stored_energy_start) != 1 || is.na(stored_energy_start) ||
        anyNA(delta_t_h) || anyNA(energy_request) ||
        length(tolerance) != 1 || is.na(tolerance)) {
      stop("battery_free_trajectory: the stored energy, the duration ",
           "of a step, the request or the tolerance has missing values")
    }
    rm(list = "n_steps")
  }

  # -------------------------------------------------------------
  # 2. Run the steps
  # -------------------------------------------------------------
  {
    # battery_free_trajectory_cpp is called to run the request through
    # the battery with no limit and find the steps that break one.
    free <- battery_free_trajectory_cpp(
      stored_energy_start = stored_energy_start,
      delta_t_h           = delta_t_h,
      energy_request      = energy_request,
      battery             = battery,
      tolerance           = tolerance
    )
  }

  return(free)
}
