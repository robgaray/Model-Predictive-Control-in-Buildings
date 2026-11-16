# -------------------------------------------------------------
# Function: battery_trajectory.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Computes the energy a battery stores, takes from the system and
# gives to it over a run of steps, from the energy that each step
# asks of it. It is the core of the physics of the battery. It works
# in energy per step, not in power, so that a run that follows an
# energy that a plan has already computed reproduces it exactly.
# With C the capacity, E_max = SOC_max * C and E_min = SOC_min * C
# (kWh), eta_c and eta_d the efficiencies of charge and discharge,
# s the self-discharge (share per day), P_c and P_d the maximum
# powers (kW) and dt the duration of the step (h), in each step k:
#   1. f      <- (1 - s)^(dt / 24)
#   2. E'     <- f * E_(k-1)
#        The energy after the self-discharge (kWh).
#   3. B_c    <- (E_max - E') / eta_c
#      B_d    <- (E' - E_min) * eta_d
#        The energy of the system side that fills the battery up to
#        E_max, and that empties it down to E_min (kWh).
#   4. A_c    <- max(0, min(P_c * dt, B_c))
#      A_d    <- max(0, min(P_d * dt, B_d))
#        The most the battery can take and give in the step (kWh).
#   5. Charge    <- min(max(R, 0), A_c)
#      Discharge <- min(max(-R, 0), A_d)
#        R is the request of the step (kWh). It never charges and
#        discharges at the same time: the sign of R decides.
#   6. E_k    <- E' + eta_c * Charge - Discharge / eta_d
#        When the capacity limits the charge, or the minimum energy
#        limits the discharge, E_k is exactly E_max or E_min.
# The self-discharge may leave the battery under E_min: E_min limits
# the discharge, not the rest.
# This function checks the inputs. The steps are computed in compiled
# code, by battery_trajectory_cpp(), with the same operations in the
# same order.
# -------------------------------------------------------------
# Inputs
#   stored_energy_start : Numeric scalar. The energy stored before
#                         the first step (kWh).
#   delta_t_h           : Numeric vector. The duration of each step
#                         (h).
#   energy_request      : Numeric vector, as long as delta_t_h. The
#                         request of each step (kWh of the system
#                         side, positive to charge). It may be Inf
#                         or -Inf.
#   battery             : Named list. The parameters of the battery
#                         (asset$battery).
# -------------------------------------------------------------
# Outputs
#   Named list of three numeric vectors as long as delta_t_h:
#     - charge: the electricity the battery takes from the system
#       in each step (kWh, never negative).
#     - discharge: the electricity it gives to the system in each
#       step (kWh, never negative).
#     - stored_energy: the energy stored at the end of each step
#       (kWh).
#   The run stops if an input is missing or the vectors differ in
#   length.
# -------------------------------------------------------------
# Code outline
# 1. Check the inputs
# 2. Run the steps
# -------------------------------------------------------------
# Usage instructions
# run <- battery_trajectory(
#   stored_energy_start = 5,
#   delta_t_h           = rep(1 / 12, 3),
#   energy_request      = c(Inf, Inf, -Inf),
#   battery             = asset$battery
# )
# -------------------------------------------------------------

battery_trajectory <- function(stored_energy_start,
                               delta_t_h,
                               energy_request,
                               battery
                               ) {

  # -------------------------------------------------------------
  # 1. Check the inputs
  # -------------------------------------------------------------
  {
    n_steps <- length(delta_t_h)
    if (length(energy_request) != n_steps) {
      stop("battery_trajectory: delta_t_h and energy_request have ",
           n_steps, " and ", length(energy_request), " elements")
    }
    if (length(stored_energy_start) != 1 || is.na(stored_energy_start) ||
        anyNA(delta_t_h) || anyNA(energy_request)) {
      stop("battery_trajectory: the stored energy, the duration of a ",
           "step or the request has missing values")
    }
    rm(list = "n_steps")
  }

  # -------------------------------------------------------------
  # 2. Run the steps
  # -------------------------------------------------------------
  {
    # battery_trajectory_cpp is called to run the request through the
    # battery step by step, cutting it with the limits of the battery.
    run <- battery_trajectory_cpp(
      stored_energy_start = stored_energy_start,
      delta_t_h           = delta_t_h,
      energy_request      = energy_request,
      battery             = battery
    )
  }

  return(run)
}
