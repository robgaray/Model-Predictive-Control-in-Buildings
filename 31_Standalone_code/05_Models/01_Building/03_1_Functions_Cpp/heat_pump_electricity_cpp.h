// -------------------------------------------------------------
// Function: heat_pump_electricity_cpp.h
// Part of the Model Predictive Control in buildings repository
// https://github.com/robgaray/Model-Predictive-Control-in-Buildings
// Developed by Roberto Garay Martinez
// -------------------------------------------------------------
// Overall description
// Returns the total electricity the HVAC systems draw, step by step,
// for a given heating and cooling energy. Each step is evaluated by
// heat_pump_electricity_step(), the same expression the period
// simulation uses, so that R can bound an itinerary in electricity
// (through heat_pump_electricity()) without running the simulation
// and without a second copy of the electrical model.
// The file is a header, included by period_simulation_cpp.cpp, so
// that the single Rcpp::sourceCpp() call that compiles the simulation
// also compiles and exports this function.
// -------------------------------------------------------------
// Inputs
// All the vectors are the same length, one entry per time step.
//   Q_heat      : NumericVector. Heating energy of each step (kWh).
//   Q_cool      : NumericVector. Cooling energy of each step (kWh).
//   COP_heat    : NumericVector. Heating COP of each step, as
//                 heat_pump_cop_cpp() returns it.
//   delta_t_h   : NumericVector. Length of each step (h).
//   Q_hp_heat_1 : Double. First rated heating power of the heat pump
//                 (kW).
//   COP_hp_cool : Double. Cooling COP (dimensionless).
// -------------------------------------------------------------
// Outputs
//   NumericVector, the length of the inputs. The electricity of each
//   step (kWh), heating plus cooling.
// -------------------------------------------------------------
// Code outline
// 1. Check that the vectors have the same length
// 2. The electricity of each step
// -------------------------------------------------------------
// Usage instructions
// From R, once period_simulation_cpp.cpp is compiled, through
// heat_pump_electricity(Q_heat, Q_cool, cop_heat, delta_t_h,
//                       asset).
// -------------------------------------------------------------

#ifndef HEAT_PUMP_ELECTRICITY_CPP_H
#define HEAT_PUMP_ELECTRICITY_CPP_H

#include <Rcpp.h>
#include "heat_pump_electricity_step.h"

// [[Rcpp::export]]
inline Rcpp::NumericVector heat_pump_electricity_cpp(
  Rcpp::NumericVector Q_heat,
  Rcpp::NumericVector Q_cool,
  Rcpp::NumericVector COP_heat,
  Rcpp::NumericVector delta_t_h,
  double Q_hp_heat_1,
  double COP_hp_cool
)
{
  int n = Q_heat.size();

  // -------------------------------------------------------------
  // 1. Check that the vectors have the same length
  // -------------------------------------------------------------
  {
    if (Q_cool.size() != n || COP_heat.size() != n ||
        delta_t_h.size() != n)
    {
      Rcpp::stop("heat_pump_electricity_cpp: Q_heat, Q_cool, COP_heat "
                 "and delta_t_h must have the same length");
    }
  }

  Rcpp::NumericVector Elec_total(n);

  // -------------------------------------------------------------
  // 2. The electricity of each step
  // -------------------------------------------------------------
  {
    for (int CONT_001 = 0; CONT_001 < n; ++CONT_001)
    {
      double Elec_heat = 0.0;
      double Elec_cool = 0.0;

      // heat_pump_electricity_step is called for the heating and the
      // cooling electricity of the step, which add up to its total.
      heat_pump_electricity_step(
        Q_heat[CONT_001],
        Q_cool[CONT_001],
        COP_heat[CONT_001],
        delta_t_h[CONT_001],
        Q_hp_heat_1,
        COP_hp_cool,
        Elec_heat,
        Elec_cool
      );

      Elec_total[CONT_001] = Elec_heat + Elec_cool;
    }
  }

  return Elec_total;
}

#endif
