// -------------------------------------------------------------
// Function: heat_pump_cop_cpp.h
// Part of the Model Predictive Control in buildings repository
// https://github.com/robgaray/Model-Predictive-Control-in-Buildings
// Developed by Roberto Garay Martinez
// -------------------------------------------------------------
// Overall description
// Returns the heating COP of the heat pump at each outdoor
// temperature. It is the only place where the COP is written: the
// period simulation, the bisection of the commitment margin and, from
// R, heat_pump_cop() all take it from here.
// The COP is referred to a rating point: it equals
// COP_hp_heat_1_coef1 at (Text_ref_hp_heat, Tsup_ref_hp_heat) and is
// corrected linearly by how far each temperature departs from it. The
// reference is the A7/W35 rating point of EN 14511, which is why the
// coefficients are only meaningful alongside the two reference
// temperatures.
// A heat pump never gives less heat than the electricity it uses, so
// the COP is never below 1: where the line falls below 1 (at very low
// outdoor temperatures, or with other coefficients), the COP is 1.
//   COP = max(1, COP_hp_heat_1_coef1
//                + COP_hp_heat_1_coef2 * (Text - Text_ref_hp_heat)
//                + COP_hp_heat_1_coef3 * (Tsup_hp_heat - Tsup_ref_hp_heat))
// The file is a header, included by period_simulation_cpp.cpp, so
// that the single Rcpp::sourceCpp() call that compiles the simulation
// also compiles and exports this function.
// -------------------------------------------------------------
// Inputs
//   Text                : NumericVector. Outdoor temperature (degC).
//   COP_hp_heat_1_coef1 : Double. Heating COP at the reference point,
//                         dimensionless.
//   COP_hp_heat_1_coef2 : Double. Sensitivity of the COP to the
//                         outdoor temperature (1/degC).
//   COP_hp_heat_1_coef3 : Double. Sensitivity of the COP to the
//                         supply temperature (1/degC).
//   Tsup_hp_heat        : Double. Supply temperature (degC).
//   Text_ref_hp_heat    : Double. Outdoor temperature of the reference
//                         point (degC).
//   Tsup_ref_hp_heat    : Double. Supply temperature of the reference
//                         point (degC).
// -------------------------------------------------------------
// Outputs
//   NumericVector, the length of Text. The heating COP at each
//   outdoor temperature, never below 1.
// -------------------------------------------------------------
// Code outline
// 1. The COP at each outdoor temperature
// -------------------------------------------------------------
// Usage instructions
// From C++, after including this header:
//   NumericVector cop = heat_pump_cop_cpp(Text, coef1, coef2, coef3,
//                                         Tsup, Text_ref, Tsup_ref);
// From R, once period_simulation_cpp.cpp is compiled, through
// heat_pump_cop(Text, parameters).
// -------------------------------------------------------------

#ifndef HEAT_PUMP_COP_CPP_H
#define HEAT_PUMP_COP_CPP_H

#include <Rcpp.h>

// [[Rcpp::export]]
inline Rcpp::NumericVector heat_pump_cop_cpp(
  Rcpp::NumericVector Text,
  double COP_hp_heat_1_coef1,
  double COP_hp_heat_1_coef2,
  double COP_hp_heat_1_coef3,
  double Tsup_hp_heat,
  double Text_ref_hp_heat,
  double Tsup_ref_hp_heat
)
{
  int n = Text.size();
  Rcpp::NumericVector COP_heat(n);

  // -------------------------------------------------------------
  // 1. The COP at each outdoor temperature
  // The supply term does not depend on the step, but it is evaluated
  // inside the sum, in the same order as the rest of the expression,
  // so that every caller gets exactly the same value. The line is
  // then floored at 1: by definition, a COP is never below 1. A
  // missing outdoor temperature (NA) still gives a missing COP.
  // -------------------------------------------------------------
  {
    for (int CONT_001 = 0; CONT_001 < n; ++CONT_001)
    {
      double COP_line =
        COP_hp_heat_1_coef1 +
        COP_hp_heat_1_coef2 * (Text[CONT_001] - Text_ref_hp_heat) +
        COP_hp_heat_1_coef3 * (Tsup_hp_heat   - Tsup_ref_hp_heat);
      COP_heat[CONT_001] = COP_line < 1.0 ? 1.0 : COP_line;
    }
  }

  return COP_heat;
}

#endif
