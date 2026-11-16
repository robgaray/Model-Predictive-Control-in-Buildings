// -------------------------------------------------------------
// Function: battery_trajectory_cpp.cpp
// Part of the Model Predictive Control in buildings repository
// https://github.com/robgaray/Model-Predictive-Control-in-Buildings
// Developed by Roberto Garay Martinez
// -------------------------------------------------------------
// Overall description
// Computes, step by step, the energy a battery stores, takes from the
// system and gives to it over a run of steps, from the energy that
// each step asks of it, cutting the request with the limits of the
// battery. It is the loop of battery_trajectory(), which describes
// the physics and checks the inputs before it calls this function.
// With E_max, E_min, eta_c, eta_d from battery_limits() and f, P_c *
// dt and P_d * dt from battery_step_terms(), in each step k:
//   1. E'        = f * E_(k-1)
//   2. B_c       = (E_max - E') / eta_c
//      B_d       = (E' - E_min) * eta_d
//   3. A_c       = max(0, min(P_c * dt, B_c))
//      A_d       = max(0, min(P_d * dt, B_d))
//   4. Charge    = min(max(R, 0), A_c)
//      Discharge = min(max(-R, 0), A_d)
//   5. E_k       = E' + eta_c * Charge - Discharge / eta_d, or
//      exactly E_max or E_min when the room of the battery limits
//      the charge or the discharge.
// The operations are those of R, in the same order, so that the
// results are exactly the ones R would compute.
// -------------------------------------------------------------
// The compiled physics of the battery
// This file includes the other headers of the folder, so that the
// single Rcpp::sourceCpp() call that compiles it compiles all of
// them and exports to R:
//   - battery_trajectory_cpp()
//   - battery_free_trajectory_cpp()
//   - battery_recovery_correction_cpp()
//   - battery_factor_search_cpp()
// The headers battery_limits.h, battery_step_terms.h,
// battery_free_run.h and battery_recovery_correction_core.h hold the
// parameters, the terms of each step, the free trajectory and the
// correction of the Recovery Phase that the exported functions share.
// They are not callable from R.
// -------------------------------------------------------------
// Inputs
//   stored_energy_start : Double. The energy stored before the first
//                         step (kWh).
//   delta_t_h           : Rcpp::NumericVector. The duration of each
//                         step (h).
//   energy_request      : Rcpp::NumericVector, as long as delta_t_h.
//                         The request of each step (kWh of the
//                         system side, positive to charge). It may
//                         be Inf or -Inf.
//   battery             : Rcpp::List. The parameters of the battery
//                         (asset$battery).
// -------------------------------------------------------------
// Outputs
//   Rcpp::List of three numeric vectors as long as delta_t_h:
//     - charge: the electricity the battery takes from the system
//       in each step (kWh, never negative).
//     - discharge: the electricity it gives to the system in each
//       step (kWh, never negative).
//     - stored_energy: the energy stored at the end of each step
//       (kWh).
//   It stops with an error if the vectors differ in length.
// -------------------------------------------------------------
// Code outline
// 1. Check the lengths and compute the terms of each step
// 2. Run the steps
// -------------------------------------------------------------
// Usage instructions
// Called from R through battery_trajectory(). Compiled with
// Rcpp::sourceCpp() on this file alone: the headers it includes are
// found in its own folder.
// -------------------------------------------------------------

// The compiler shall not fuse a product and a sum into one
// operation: R never does, and the results must be those of R.
#if defined(__clang__)
#pragma STDC FP_CONTRACT OFF
#elif defined(__GNUC__)
#pragma GCC optimize ("fp-contract=off")
#endif

#include <Rcpp.h>
#include <algorithm>
#include "battery_limits.h"
#include "battery_step_terms.h"
#include "battery_free_run.h"
#include "battery_free_trajectory_cpp.h"
#include "battery_recovery_correction_core.h"
#include "battery_recovery_correction_cpp.h"
#include "battery_factor_search_cpp.h"

// [[Rcpp::export]]
Rcpp::List battery_trajectory_cpp(
  double              stored_energy_start,
  Rcpp::NumericVector delta_t_h,
  Rcpp::NumericVector energy_request,
  Rcpp::List          battery
)
{
  const R_xlen_t n_steps = delta_t_h.size();
  BatteryLimits  limits;
  BatterySteps   steps;

  Rcpp::NumericVector charge(n_steps);
  Rcpp::NumericVector discharge(n_steps);
  Rcpp::NumericVector stored_energy(n_steps);

  // -------------------------------------------------------------
  // 1. Check the lengths and compute the terms of each step
  // battery_limits() reads the parameters of the battery, and
  // battery_step_terms() computes the share kept and the power
  // limits of each step.
  // -------------------------------------------------------------
  {
    if (energy_request.size() != n_steps)
    {
      Rcpp::stop("battery_trajectory_cpp: delta_t_h and "
                 "energy_request differ in length");
    }

    limits = battery_limits(battery);
    steps  = battery_step_terms(delta_t_h, limits);
  }

  // -------------------------------------------------------------
  // 2. Run the steps
  // -------------------------------------------------------------
  {
    double energy = stored_energy_start;

    for (R_xlen_t CONT_001 = 0; CONT_001 < n_steps; ++CONT_001)
    {
      double energy_kept = steps.keep[CONT_001] * energy;
      double room_c      = (limits.energy_max - energy_kept) /
        limits.eta_charge;
      double room_d      = (energy_kept - limits.energy_min) *
        limits.eta_disch;
      double limit_c     = std::max(0.0,
                                    std::min(steps.power_c[CONT_001],
                                             room_c));
      double limit_d     = std::max(0.0,
                                    std::min(steps.power_d[CONT_001],
                                             room_d));
      double request     = energy_request[CONT_001];
      double step_c      = std::min(std::max(request, 0.0), limit_c);
      double step_d      = std::min(std::max(-request, 0.0), limit_d);

      if (step_c > 0 && step_c >= room_c)
      {
        energy = limits.energy_max;
      }
      else if (step_d > 0 && step_d >= room_d)
      {
        energy = limits.energy_min;
      }
      else
      {
        energy = energy_kept + limits.eta_charge * step_c -
          step_d / limits.eta_disch;
      }

      charge[CONT_001]        = step_c;
      discharge[CONT_001]     = step_d;
      stored_energy[CONT_001] = energy;
    }
  }

  return Rcpp::List::create(
    Rcpp::Named("charge")        = charge,
    Rcpp::Named("discharge")     = discharge,
    Rcpp::Named("stored_energy") = stored_energy
  );
}
