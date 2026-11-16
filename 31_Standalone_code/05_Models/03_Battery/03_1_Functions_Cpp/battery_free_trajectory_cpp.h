// -------------------------------------------------------------
// Function: battery_free_trajectory_cpp.h
// Part of the Model Predictive Control in buildings repository
// https://github.com/robgaray/Model-Predictive-Control-in-Buildings
// Developed by Roberto Garay Martinez
// -------------------------------------------------------------
// Overall description
// Computes, for R, the energy a battery would store over a run of
// steps if nothing limited it, and says on which steps the request
// breaks a limit of the battery. The physics is that of
// battery_free_run(); this function reads the parameters, computes
// the terms of each step and returns the run as R vectors. R calls it
// through battery_free_trajectory(), which checks the inputs first.
// The file is a header, included by battery_trajectory_cpp.cpp, so
// that the single Rcpp::sourceCpp() call that compiles the module
// also compiles and exports this function.
// -------------------------------------------------------------
// Inputs
//   stored_energy_start : Double. The energy stored before the first
//                         step (kWh).
//   delta_t_h           : Rcpp::NumericVector. The duration of each
//                         step (h).
//   energy_request      : Rcpp::NumericVector, as long as delta_t_h.
//                         The request of each step (kWh of the
//                         system side, positive to charge).
//   battery             : Rcpp::List. The parameters of the battery
//                         (asset$battery).
//   tolerance           : Double. The tolerance of the comparisons
//                         with the limits (kWh).
// -------------------------------------------------------------
// Outputs
//   Rcpp::List with the vectors, as long as delta_t_h:
//     - stored_energy: numeric, the energy stored at the end of each
//       step (kWh).
//     - breach: logical, TRUE on the steps that break a limit.
//     - breach_low: logical, TRUE on the steps that break a limit
//       while discharging.
//     - breach_high: logical, TRUE on the steps that break a limit
//       while charging.
//   It stops with an error if the vectors differ in length.
// -------------------------------------------------------------
// Code outline
// 1. Check the lengths and compute the terms of each step
// 2. Run the steps
// 3. Return the run
// -------------------------------------------------------------
// Usage instructions
// From R, once battery_trajectory_cpp.cpp is compiled, through
// battery_free_trajectory():
//   free <- battery_free_trajectory_cpp(5, rep(0.25, 4),
//                                       c(1, 1, -1, -1),
//                                       asset$battery, 1e-9)
// -------------------------------------------------------------

#ifndef BATTERY_FREE_TRAJECTORY_CPP_H
#define BATTERY_FREE_TRAJECTORY_CPP_H

// The compiler shall not fuse a product and a sum into one
// operation: R never does, and the results must be those of R.
#if defined(__clang__)
#pragma STDC FP_CONTRACT OFF
#elif defined(__GNUC__)
#pragma GCC optimize ("fp-contract=off")
#endif

#include <Rcpp.h>
#include <vector>
#include "battery_limits.h"
#include "battery_step_terms.h"
#include "battery_free_run.h"

// [[Rcpp::export]]
inline Rcpp::List battery_free_trajectory_cpp(
  double              stored_energy_start,
  Rcpp::NumericVector delta_t_h,
  Rcpp::NumericVector energy_request,
  Rcpp::List          battery,
  double              tolerance
)
{
  const R_xlen_t n_steps = delta_t_h.size();
  BatteryLimits  limits;
  BatterySteps   steps;
  BatteryFreeRun run;

  // -------------------------------------------------------------
  // 1. Check the lengths and compute the terms of each step
  // battery_limits() reads the parameters of the battery, and
  // battery_step_terms() computes the share kept and the power
  // limits of each step, which the run needs.
  // -------------------------------------------------------------
  {
    if (energy_request.size() != n_steps)
    {
      Rcpp::stop("battery_free_trajectory_cpp: delta_t_h and "
                 "energy_request differ in length");
    }

    limits = battery_limits(battery);
    steps  = battery_step_terms(delta_t_h, limits);
  }

  // -------------------------------------------------------------
  // 2. Run the steps
  // battery_free_run() runs the request through the battery with no
  // limit and marks the steps that break one.
  // -------------------------------------------------------------
  {
    std::vector<double> request(energy_request.begin(),
                                energy_request.end());
    battery_free_run(stored_energy_start, request, limits, steps,
                     tolerance, run);
  }

  // -------------------------------------------------------------
  // 3. Return the run
  // -------------------------------------------------------------
  Rcpp::NumericVector stored_energy(run.stored_energy.begin(),
                                    run.stored_energy.end());
  Rcpp::LogicalVector breach(n_steps);
  Rcpp::LogicalVector breach_low(n_steps);
  Rcpp::LogicalVector breach_high(n_steps);
  {
    for (R_xlen_t CONT_001 = 0; CONT_001 < n_steps; ++CONT_001)
    {
      breach_low[CONT_001]  = run.breach_low[CONT_001] != 0;
      breach_high[CONT_001] = run.breach_high[CONT_001] != 0;
      breach[CONT_001]      = run.breach_low[CONT_001] != 0 ||
        run.breach_high[CONT_001] != 0;
    }
  }

  return Rcpp::List::create(
    Rcpp::Named("stored_energy") = stored_energy,
    Rcpp::Named("breach")        = breach,
    Rcpp::Named("breach_low")    = breach_low,
    Rcpp::Named("breach_high")   = breach_high
  );
}

#endif
