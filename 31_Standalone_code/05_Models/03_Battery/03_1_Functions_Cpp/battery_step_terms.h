// -------------------------------------------------------------
// Function: battery_step_terms.h
// Part of the Model Predictive Control in buildings repository
// https://github.com/robgaray/Model-Predictive-Control-in-Buildings
// Developed by Roberto Garay Martinez
// -------------------------------------------------------------
// Overall description
// Computes, for each step of a run of a battery, the terms that do
// not depend on the request: the share of the energy the battery
// keeps over the step, its product up to the step, and the most it
// can charge and discharge in the step. A search that tests many
// requests on the same run computes them once.
// With s the self-discharge (% per day), dt the duration of the step
// (h), P_c and P_d the maximum powers (kW), in each step k:
//   - keep_k       = (1 - s / 100)^(dt_k / 24)
//   - keep_total_k = keep_1 * keep_2 * ... * keep_k
//   - power_c_k    = P_c * dt_k (kWh)
//   - power_d_k    = P_d * dt_k (kWh)
// The power is computed as R computes x^y: 1 when x is 1 or y is 0,
// x * x when y is 2, and the power of the C library otherwise. The
// product is accumulated in long double and rounded at every step,
// as the cumulative product of R, so that the terms are exactly
// those of the R functions of the battery.
// The file is a header, included by battery_trajectory_cpp.cpp. It
// is not callable from R.
// -------------------------------------------------------------
// The structure BatterySteps
//   delta_t_h  : std::vector<double>. The duration of each step (h).
//   keep       : std::vector<double>. The share kept in each step.
//   keep_total : std::vector<double>. The share kept from the start
//                to the end of each step.
//   power_c    : std::vector<double>. The most the battery can take
//                in each step (kWh).
//   power_d    : std::vector<double>. The most the battery can give
//                in each step (kWh).
// -------------------------------------------------------------
// Inputs
//   delta_t_h : Rcpp::NumericVector. The duration of each step (h).
//   limits    : BatteryLimits. The limits of the battery
//               (battery_limits()).
// -------------------------------------------------------------
// Outputs
//   BatterySteps, the terms of each step.
// -------------------------------------------------------------
// Code outline
// 1. The terms of each step
// -------------------------------------------------------------
// Usage instructions
// From C++, after including this header:
//   BatterySteps steps = battery_step_terms(delta_t_h, limits);
// -------------------------------------------------------------

#ifndef BATTERY_STEP_TERMS_H
#define BATTERY_STEP_TERMS_H

// The compiler shall not fuse a product and a sum into one
// operation: R never does, and the results must be those of R.
#if defined(__clang__)
#pragma STDC FP_CONTRACT OFF
#elif defined(__GNUC__)
#pragma GCC optimize ("fp-contract=off")
#endif

#include <Rcpp.h>
#include <cmath>
#include <vector>
#include "battery_limits.h"

struct BatterySteps
{
  std::vector<double> delta_t_h;
  std::vector<double> keep;
  std::vector<double> keep_total;
  std::vector<double> power_c;
  std::vector<double> power_d;
};

inline BatterySteps battery_step_terms(
  Rcpp::NumericVector delta_t_h,
  const BatteryLimits &limits
)
{
  const std::size_t n_steps = delta_t_h.size();
  BatterySteps steps;

  steps.delta_t_h.assign(delta_t_h.begin(), delta_t_h.end());
  steps.keep.resize(n_steps);
  steps.keep_total.resize(n_steps);
  steps.power_c.resize(n_steps);
  steps.power_d.resize(n_steps);

  // -------------------------------------------------------------
  // 1. The terms of each step
  // The hours of a day and the percent are conversions of unit.
  // -------------------------------------------------------------
  {
    const double base     = 1 - limits.self_discharge / 100;
    long double  kept_all = 1.0L;

    for (std::size_t CONT_001 = 0; CONT_001 < n_steps; ++CONT_001)
    {
      double exponent = steps.delta_t_h[CONT_001] / 24;
      double keep;
      if (exponent == 2.0)
      {
        keep = base * base;
      }
      else if (base == 1.0 || exponent == 0.0)
      {
        keep = 1.0;
      }
      else
      {
        keep = std::pow(base, exponent);
      }

      kept_all *= keep;

      steps.keep[CONT_001]       = keep;
      steps.keep_total[CONT_001] = (double) kept_all;
      steps.power_c[CONT_001]    =
        limits.power_charge * steps.delta_t_h[CONT_001];
      steps.power_d[CONT_001]    =
        limits.power_disch * steps.delta_t_h[CONT_001];
    }
  }

  return steps;
}

#endif
