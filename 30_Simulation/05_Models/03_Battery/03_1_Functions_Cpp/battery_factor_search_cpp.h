// -------------------------------------------------------------
// Function: battery_factor_search_cpp.h
// Part of the Model Predictive Control in buildings repository
// https://github.com/robgaray/Model-Predictive-Control-in-Buildings
// Developed by Roberto Garay Martinez
// -------------------------------------------------------------
// Overall description
// Finds, for R, the largest factor between 0 and 1 with which a leg
// of a battery can be carried out over a stretch of steps. It is the
// factor of the battery in the draft of a flexibility window, and the
// factor of what it holds of a window already sold.
// The request of a factor f is the base request, with
//   base_request[k] + f * factor_energy[j]
// on each step k = factor_steps[j]. The leg is carried out with f:
//   - without the Recovery Phase, when no step of the stretch breaks
//     a limit of the battery (battery_free_run());
//   - with the Recovery Phase, when the least correction of the
//     Recovery Phase carries the whole stretch out
//     (battery_recovery_correction_core(), with every step checked
//     and no target energy). The correction never takes the leg past
//     the energy it stored before the window.
// If the factor 1 carries the leg out, it is 1. If not even the
// factor 0 does, nothing is found. Otherwise a bisection of
// bisection_steps halvings keeps the factor that carries it out, and
// the factor is the lower end of the last interval. The parameters
// and the terms of each step are computed once for the whole search.
// The operations are those of R, in the same order.
// The file is a header, included by battery_trajectory_cpp.cpp, so
// that the single Rcpp::sourceCpp() call that compiles the module
// also compiles and exports this function. R calls it through
// battery_factor_search(), which checks the inputs first.
// -------------------------------------------------------------
// Inputs
//   stored_energy_start : Double. The energy stored before the first
//                         step (kWh).
//   delta_t_h           : Rcpp::NumericVector. The duration of each
//                         step of the stretch (h).
//   base_request        : Rcpp::NumericVector, as long as delta_t_h.
//                         The request of each step with the factor 0
//                         (kWh of the system side, positive to
//                         charge).
//   reference_energy    : Rcpp::NumericVector, as long as delta_t_h.
//                         The energy the leg stored at the end of each
//                         step before the window (kWh), which the
//                         correction of the Recovery Phase never
//                         passes. Read only with the Recovery Phase.
//   factor_steps        : Rcpp::IntegerVector. The steps the factor
//                         moves, positions in the stretch from 1.
//   factor_energy       : Rcpp::NumericVector, as long as
//                         factor_steps. The energy the factor 1 adds
//                         to each of those steps (kWh).
//   with_recovery       : Bool. True to carry the leg out with the
//                         least correction of the Recovery Phase.
//   recovery_steps      : Rcpp::IntegerVector. The steps of the
//                         Recovery Phase, positions from 1. Read only
//                         with the Recovery Phase; it may be empty.
//   direction           : Double, 1 to charge in the Recovery Phase
//                         and -1 to discharge. Read only with the
//                         Recovery Phase.
//   battery             : Rcpp::List. The parameters of the battery
//                         (asset$battery).
//   bisection_steps     : Integer. The halvings of each bisection.
//   tolerance           : Double. The tolerance of the comparisons
//                         with the limits (kWh).
// -------------------------------------------------------------
// Outputs
//   Rcpp::List with:
//     - found: logical. FALSE when not even the factor 0 carries the
//       leg out.
//     - factor: numeric. The factor found, 0 when nothing is found.
//   It stops with an error if the vectors differ in length or a
//   position is outside the stretch.
// -------------------------------------------------------------
// Code outline
// 1. Check the inputs and compute the terms of each step
// 2. The test of a factor
// 3. The search of the factor
// -------------------------------------------------------------
// Usage instructions
// From R, once battery_trajectory_cpp.cpp is compiled, through
// battery_factor_search():
//   search <- battery_factor_search_cpp(
//     3, rep(0.25, 8), rep(0, 8), rep(3, 8), 2:3, c(-1, -1), TRUE, 5:6,
//     1, asset$battery, 24L, 1e-9)
// -------------------------------------------------------------

#ifndef BATTERY_FACTOR_SEARCH_CPP_H
#define BATTERY_FACTOR_SEARCH_CPP_H

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
#include "battery_recovery_correction_core.h"

// [[Rcpp::export]]
inline Rcpp::List battery_factor_search_cpp(
  double              stored_energy_start,
  Rcpp::NumericVector delta_t_h,
  Rcpp::NumericVector base_request,
  Rcpp::NumericVector reference_energy,
  Rcpp::IntegerVector factor_steps,
  Rcpp::NumericVector factor_energy,
  bool                with_recovery,
  Rcpp::IntegerVector recovery_steps,
  double              direction,
  Rcpp::List          battery,
  int                 bisection_steps,
  double              tolerance
)
{
  const R_xlen_t      n_steps  = delta_t_h.size();
  const R_xlen_t      n_factor = factor_steps.size();
  BatteryLimits       limits;
  BatterySteps        steps;
  std::vector<double> base(base_request.begin(), base_request.end());
  std::vector<double> reference(reference_energy.begin(),
                                reference_energy.end());
  std::vector<double> energy(factor_energy.begin(), factor_energy.end());
  std::vector<int>    moved(n_factor);
  std::vector<int>    recovery(recovery_steps.size());
  std::vector<int>    check(n_steps);

  // -------------------------------------------------------------
  // 1. Check the inputs and compute the terms of each step
  // battery_limits() reads the parameters of the battery, and
  // battery_step_terms() computes the share kept and the power
  // limits of each step, once for the whole search. Every step of
  // the stretch is checked.
  // -------------------------------------------------------------
  {
    if (base_request.size() != n_steps ||
        reference_energy.size() != n_steps ||
        factor_energy.size() != n_factor)
    {
      Rcpp::stop("battery_factor_search_cpp: delta_t_h, base_request "
                 "and reference_energy, or factor_steps and "
                 "factor_energy, differ in length");
    }
    for (R_xlen_t CONT_001 = 0; CONT_001 < n_factor; ++CONT_001)
    {
      if (factor_steps[CONT_001] == NA_INTEGER ||
          factor_steps[CONT_001] < 1 || factor_steps[CONT_001] > n_steps)
      {
        Rcpp::stop("battery_factor_search_cpp: a step the factor moves "
                   "is outside the stretch");
      }
      moved[CONT_001] = factor_steps[CONT_001] - 1;
    }
    for (R_xlen_t CONT_002 = 0; CONT_002 < recovery_steps.size();
         ++CONT_002)
    {
      if (recovery_steps[CONT_002] == NA_INTEGER ||
          recovery_steps[CONT_002] < 1 ||
          recovery_steps[CONT_002] > n_steps)
      {
        Rcpp::stop("battery_factor_search_cpp: a step of the Recovery "
                   "Phase is outside the stretch");
      }
      recovery[CONT_002] = recovery_steps[CONT_002] - 1;
    }
    for (R_xlen_t CONT_003 = 0; CONT_003 < n_steps; ++CONT_003)
    {
      check[CONT_003] = (int) CONT_003;
    }

    limits = battery_limits(battery);
    steps  = battery_step_terms(delta_t_h, limits);
  }

  // -------------------------------------------------------------
  // 2. The test of a factor
  // The request of the factor, then the run of the stretch with no
  // limit (battery_free_run()), or the least correction of the
  // Recovery Phase (battery_recovery_correction_core()).
  // -------------------------------------------------------------
  std::vector<double> request(n_steps);
  BatteryFreeRun      run;
  BatteryCorrection   correction;
  auto carried_out = [&](double factor)
  {
    request = base;
    for (R_xlen_t CONT_004 = 0; CONT_004 < n_factor; ++CONT_004)
    {
      int step      = moved[CONT_004];
      request[step] = base[step] + factor * energy[CONT_004];
    }

    if (with_recovery)
    {
      battery_recovery_correction_core(stored_energy_start, request,
                                       reference, recovery, check,
                                       direction,
                                       false, 0.0, limits, steps,
                                       bisection_steps, tolerance,
                                       correction);
      return correction.fits;
    }

    battery_free_run(stored_energy_start, request, limits, steps,
                     tolerance, run);
    for (R_xlen_t CONT_005 = 0; CONT_005 < n_steps; ++CONT_005)
    {
      if (run.breach_low[CONT_005] || run.breach_high[CONT_005])
      {
        return false;
      }
    }
    return true;
  };

  // -------------------------------------------------------------
  // 3. The search of the factor
  // -------------------------------------------------------------
  bool   found  = true;
  double factor = 1.0;
  {
    if (!carried_out(1.0))
    {
      if (!carried_out(0.0))
      {
        found  = false;
        factor = 0.0;
      }
      else
      {
        double factor_low  = 0.0;
        double factor_high = 1.0;
        for (int CONT_006 = 0; CONT_006 < bisection_steps; ++CONT_006)
        {
          double factor_mid = (factor_low + factor_high) / 2;
          if (carried_out(factor_mid))
          {
            factor_low  = factor_mid;
          }
          else
          {
            factor_high = factor_mid;
          }
        }
        factor = factor_low;
      }
    }
  }

  return Rcpp::List::create(
    Rcpp::Named("found")  = found,
    Rcpp::Named("factor") = factor
  );
}

#endif
