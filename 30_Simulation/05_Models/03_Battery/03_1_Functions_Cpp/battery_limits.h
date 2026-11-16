// -------------------------------------------------------------
// Function: battery_limits.h
// Part of the Model Predictive Control in buildings repository
// https://github.com/robgaray/Model-Predictive-Control-in-Buildings
// Developed by Roberto Garay Martinez
// -------------------------------------------------------------
// Overall description
// Reads the parameters of a battery, the group battery of the
// parameters of its asset, and gives the limits that every step of
// the compiled physics of the battery uses. The values are read by
// name, as the R functions of the battery read them, and the
// energies are computed with the same operations:
//   - energy_max = SOC_max * Capacity (kWh)
//   - energy_min = SOC_min * Capacity (kWh)
// It is the only place of the compiled code where the parameters of
// a battery are read.
// The file is a header, included by battery_trajectory_cpp.cpp, so
// that the single Rcpp::sourceCpp() call that compiles the module
// compiles it too. It is not callable from R.
// -------------------------------------------------------------
// The structure BatteryLimits
//   energy_max     : Double. The highest energy stored (kWh).
//   energy_min     : Double. The lowest energy stored (kWh).
//   eta_charge     : Double. The efficiency of the charge (-).
//   eta_disch      : Double. The efficiency of the discharge (-).
//   power_charge   : Double. The maximum charge power (kW).
//   power_disch    : Double. The maximum discharge power (kW).
//   self_discharge : Double. The self-discharge (% per day).
// -------------------------------------------------------------
// Inputs
//   battery : Rcpp::List. The parameters of the battery
//             (asset$battery), with the elements:
//               - Capacity
//               - SOC_min
//               - SOC_max
//               - Charge_efficiency
//               - Discharge_efficiency
//               - Charge_power_max
//               - Discharge_power_max
//               - Self_discharge
// -------------------------------------------------------------
// Outputs
//   BatteryLimits, the limits of the battery.
// -------------------------------------------------------------
// Code outline
// 1. Read the parameters and compute the limits of the energy
// -------------------------------------------------------------
// Usage instructions
// From C++, after including this header:
//   BatteryLimits limits = battery_limits(battery);
// -------------------------------------------------------------

#ifndef BATTERY_LIMITS_H
#define BATTERY_LIMITS_H

// The compiler shall not fuse a product and a sum into one
// operation: R never does, and the results must be those of R.
#if defined(__clang__)
#pragma STDC FP_CONTRACT OFF
#elif defined(__GNUC__)
#pragma GCC optimize ("fp-contract=off")
#endif

#include <Rcpp.h>

struct BatteryLimits
{
  double energy_max;
  double energy_min;
  double eta_charge;
  double eta_disch;
  double power_charge;
  double power_disch;
  double self_discharge;
};

inline BatteryLimits battery_limits(
  Rcpp::List battery
)
{
  BatteryLimits limits;

  // -------------------------------------------------------------
  // 1. Read the parameters and compute the limits of the energy
  // -------------------------------------------------------------
  {
    double capacity = Rcpp::as<double>(battery["Capacity"]);

    limits.energy_max     = Rcpp::as<double>(battery["SOC_max"]) * capacity;
    limits.energy_min     = Rcpp::as<double>(battery["SOC_min"]) * capacity;
    limits.eta_charge     = Rcpp::as<double>(battery["Charge_efficiency"]);
    limits.eta_disch      =
      Rcpp::as<double>(battery["Discharge_efficiency"]);
    limits.power_charge   = Rcpp::as<double>(battery["Charge_power_max"]);
    limits.power_disch    =
      Rcpp::as<double>(battery["Discharge_power_max"]);
    limits.self_discharge = Rcpp::as<double>(battery["Self_discharge"]);
  }

  return limits;
}

#endif
