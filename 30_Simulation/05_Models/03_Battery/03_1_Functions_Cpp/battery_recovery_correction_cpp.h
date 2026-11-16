// -------------------------------------------------------------
// Function: battery_recovery_correction_cpp.h
// Part of the Model Predictive Control in buildings repository
// https://github.com/robgaray/Model-Predictive-Control-in-Buildings
// Developed by Roberto Garay Martinez
// -------------------------------------------------------------
// Overall description
// Finds, for R, the correction that a battery makes in the Recovery
// Phase of a flexibility leg so that the leg can be carried out until
// the close of the control horizon. The method is that of
// battery_recovery_correction_core(); this function reads the
// parameters, computes the terms of each step, turns the positions of
// R, which start at 1, into positions from 0, and returns the
// correction as R values. R calls it through
// battery_recovery_correction(), which checks the inputs first.
// The file is a header, included by battery_trajectory_cpp.cpp, so
// that the single Rcpp::sourceCpp() call that compiles the module
// also compiles and exports this function.
// -------------------------------------------------------------
// Inputs
//   stored_energy_start : Double. The energy stored before the first
//                         step (kWh).
//   delta_t_h           : Rcpp::NumericVector. The duration of each
//                         step of the stretch (h).
//   base_request        : Rcpp::NumericVector, as long as delta_t_h.
//                         The request of each step with no
//                         correction (kWh of the system side,
//                         positive to charge).
//   reference_energy    : Rcpp::NumericVector, as long as delta_t_h.
//                         The energy the leg stored at the end of each
//                         step before the window (kWh).
//   recovery_steps      : Rcpp::IntegerVector. The steps of the
//                         Recovery Phase, positions in the stretch
//                         from 1. It may be empty.
//   check_steps         : Rcpp::IntegerVector. The steps on which the
//                         limits are checked, positions from 1.
//   direction           : Double, 1 to charge in the Recovery Phase
//                         and -1 to discharge.
//   target_energy       : SEXP. NULL, or the energy to reach at the
//                         last step of the Recovery Phase (kWh).
//   battery             : Rcpp::List. The parameters of the battery
//                         (asset$battery).
//   bisection_steps     : Integer. The halvings of each bisection.
//   tolerance           : Double. The tolerance of the comparisons
//                         with the limits (kWh).
// -------------------------------------------------------------
// Outputs
//   Rcpp::List with:
//     - extra: numeric vector, as long as delta_t_h. The energy added
//       to the request of each step (kWh, 0 outside the Recovery
//       Phase), with the sign of direction.
//     - fits: logical. TRUE when the stretch is carried out with
//       that correction.
//   It stops with an error if the vectors differ in length or a
//   position is outside the stretch.
// -------------------------------------------------------------
// Code outline
// 1. Check the inputs and compute the terms of each step
// 2. Find the correction
// -------------------------------------------------------------
// Usage instructions
// From R, once battery_trajectory_cpp.cpp is compiled, through
// battery_recovery_correction():
//   correction <- battery_recovery_correction_cpp(
//     3, rep(0.25, 8), c(0, 0, 0, 0, 0, -1, -1, -1), rep(6, 8), 3:4,
//     1:8, 1, NULL, asset$battery, 24L, 1e-9)
// -------------------------------------------------------------

#ifndef BATTERY_RECOVERY_CORRECTION_CPP_H
#define BATTERY_RECOVERY_CORRECTION_CPP_H

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
#include "battery_recovery_correction_core.h"

// [[Rcpp::export]]
inline Rcpp::List battery_recovery_correction_cpp(
  double              stored_energy_start,
  Rcpp::NumericVector delta_t_h,
  Rcpp::NumericVector base_request,
  Rcpp::NumericVector reference_energy,
  Rcpp::IntegerVector recovery_steps,
  Rcpp::IntegerVector check_steps,
  double              direction,
  SEXP                target_energy,
  Rcpp::List          battery,
  int                 bisection_steps,
  double              tolerance
)
{
  const R_xlen_t    n_steps = delta_t_h.size();
  BatteryLimits     limits;
  BatterySteps      steps;
  BatteryCorrection correction;
  std::vector<int>  recovery(recovery_steps.size());
  std::vector<int>  check(check_steps.size());

  // -------------------------------------------------------------
  // 1. Check the inputs and compute the terms of each step
  // battery_limits() reads the parameters of the battery, and
  // battery_step_terms() computes the share kept and the power
  // limits of each step, once for the whole search.
  // -------------------------------------------------------------
  {
    if (base_request.size() != n_steps ||
        reference_energy.size() != n_steps)
    {
      Rcpp::stop("battery_recovery_correction_cpp: delta_t_h, "
                 "base_request and reference_energy differ in length");
    }
    for (R_xlen_t CONT_001 = 0; CONT_001 < recovery_steps.size();
         ++CONT_001)
    {
      if (recovery_steps[CONT_001] == NA_INTEGER ||
          recovery_steps[CONT_001] < 1 ||
          recovery_steps[CONT_001] > n_steps)
      {
        Rcpp::stop("battery_recovery_correction_cpp: a step of the "
                   "Recovery Phase is outside the stretch");
      }
      recovery[CONT_001] = recovery_steps[CONT_001] - 1;
    }
    for (R_xlen_t CONT_002 = 0; CONT_002 < check_steps.size();
         ++CONT_002)
    {
      if (check_steps[CONT_002] == NA_INTEGER ||
          check_steps[CONT_002] < 1 ||
          check_steps[CONT_002] > n_steps)
      {
        Rcpp::stop("battery_recovery_correction_cpp: a step checked "
                   "is outside the stretch");
      }
      check[CONT_002] = check_steps[CONT_002] - 1;
    }

    limits = battery_limits(battery);
    steps  = battery_step_terms(delta_t_h, limits);
  }

  // -------------------------------------------------------------
  // 2. Find the correction
  // battery_recovery_correction_core() finds the least correction of
  // the Recovery Phase, or the one that reaches the target energy
  // when it is given.
  // -------------------------------------------------------------
  {
    bool   has_target = !Rf_isNull(target_energy);
    double target     = has_target ? Rcpp::as<double>(target_energy) : 0.0;
    std::vector<double> request(base_request.begin(), base_request.end());
    std::vector<double> reference(reference_energy.begin(),
                                  reference_energy.end());

    battery_recovery_correction_core(stored_energy_start, request,
                                     reference, recovery, check, direction,
                                     has_target, target, limits, steps,
                                     bisection_steps, tolerance,
                                     correction);
  }

  return Rcpp::List::create(
    Rcpp::Named("extra") = Rcpp::NumericVector(correction.extra.begin(),
                                               correction.extra.end()),
    Rcpp::Named("fits")  = correction.fits
  );
}

#endif
