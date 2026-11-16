// -------------------------------------------------------------
// Function: battery_free_run.h
// Part of the Model Predictive Control in buildings repository
// https://github.com/robgaray/Model-Predictive-Control-in-Buildings
// Developed by Roberto Garay Martinez
// -------------------------------------------------------------
// Overall description
// Computes the energy a battery would store over a run of steps if
// nothing limited it, and says on which steps the request breaks a
// limit of the battery. It is the only copy of that physics in the
// compiled code: the free trajectory that R calls, the least
// correction of the Recovery Phase and the search of the factor of a
// leg all run it.
// With E_0 the energy before the first step, eta_c and eta_d the
// efficiencies, R_k the request of the step k and F_k the share kept
// from the start to the end of the step k (battery_step_terms()):
//   1. in_k = eta_c * max(R_k, 0) - max(-R_k, 0) / eta_d
//        The energy that enters the battery (kWh).
//   2. E_k  = F_k * (E_0 + sum, for j up to k, of in_j / F_j)
//        The energy stored at the end of the step (kWh).
// The sum is accumulated in long double and rounded at every step,
// as the cumulative sum of R, so that the energy is exactly the one
// that R computes with cumsum() and cumprod().
// A step breaks the lower side when it discharges and either the
// energy falls below E_min or the electricity it gives is above P_d
// times the duration of the step. It breaks the upper side when it
// charges and either the energy rises above E_max or the electricity
// it takes is above P_c times the duration of the step. All the
// comparisons have a tolerance.
// The file is a header, included by battery_trajectory_cpp.cpp. It
// is not callable from R.
// -------------------------------------------------------------
// The structure BatteryFreeRun
//   stored_energy : std::vector<double>. The energy stored at the
//                   end of each step (kWh).
//   breach_low    : std::vector<char>. 1 on the steps that break a
//                   limit while discharging.
//   breach_high   : std::vector<char>. 1 on the steps that break a
//                   limit while charging.
// -------------------------------------------------------------
// Inputs
//   stored_energy_start : Double. The energy stored before the first
//                         step (kWh).
//   energy_request      : std::vector<double>. The request of each
//                         step (kWh of the system side, positive to
//                         charge).
//   limits              : BatteryLimits. The limits of the battery
//                         (battery_limits()).
//   steps               : BatterySteps. The terms of each step
//                         (battery_step_terms()).
//   tolerance           : Double. The tolerance of the comparisons
//                         with the limits (kWh).
//   run                 : BatteryFreeRun. Written: its vectors are
//                         resized to the run and filled.
// -------------------------------------------------------------
// Outputs
//   None returned. The run is written into run.
// -------------------------------------------------------------
// Code outline
// 1. Run the steps
// -------------------------------------------------------------
// Usage instructions
// From C++, after including this header:
//   BatteryFreeRun run;
//   battery_free_run(stored_energy_start, request, limits, steps,
//                    tolerance, run);
// -------------------------------------------------------------

#ifndef BATTERY_FREE_RUN_H
#define BATTERY_FREE_RUN_H

// The compiler shall not fuse a product and a sum into one
// operation: R never does, and the results must be those of R.
#if defined(__clang__)
#pragma STDC FP_CONTRACT OFF
#elif defined(__GNUC__)
#pragma GCC optimize ("fp-contract=off")
#endif

#include <Rcpp.h>
#include <algorithm>
#include <vector>
#include "battery_limits.h"
#include "battery_step_terms.h"

struct BatteryFreeRun
{
  std::vector<double> stored_energy;
  std::vector<char>   breach_low;
  std::vector<char>   breach_high;
};

inline void battery_free_run(
  double                     stored_energy_start,
  const std::vector<double> &energy_request,
  const BatteryLimits       &limits,
  const BatterySteps        &steps,
  double                     tolerance,
  BatteryFreeRun            &run
)
{
  const std::size_t n_steps = energy_request.size();

  run.stored_energy.resize(n_steps);
  run.breach_low.resize(n_steps);
  run.breach_high.resize(n_steps);

  // -------------------------------------------------------------
  // 1. Run the steps
  // -------------------------------------------------------------
  {
    long double energy_in_all = 0.0L;

    for (std::size_t CONT_001 = 0; CONT_001 < n_steps; ++CONT_001)
    {
      double request   = energy_request[CONT_001];
      double energy_in = limits.eta_charge * std::max(request, 0.0) -
        std::max(-request, 0.0) / limits.eta_disch;

      energy_in_all += energy_in / steps.keep_total[CONT_001];

      double energy = steps.keep_total[CONT_001] *
        (stored_energy_start + (double) energy_in_all);

      run.stored_energy[CONT_001] = energy;
      run.breach_high[CONT_001]   = request > 0 &&
        (energy > limits.energy_max + tolerance ||
         request > steps.power_c[CONT_001] + tolerance);
      run.breach_low[CONT_001]    = request < 0 &&
        (energy < limits.energy_min - tolerance ||
         -request > steps.power_d[CONT_001] + tolerance);
    }
  }
}

#endif
