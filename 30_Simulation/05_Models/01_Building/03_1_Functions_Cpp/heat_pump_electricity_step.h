// -------------------------------------------------------------
// Function: heat_pump_electricity_step.h
// Part of the Model Predictive Control in buildings repository
// https://github.com/robgaray/Model-Predictive-Control-in-Buildings
// Developed by Roberto Garay Martinez
// -------------------------------------------------------------
// Overall description
// Computes the electricity the HVAC systems draw in one time step for
// a given heating and cooling energy. It is the only place where this
// expression is written: the period simulation, the bisection of the
// commitment margin and, from R, heat_pump_electricity() all
// evaluate it here.
//   - The heat pump covers the heating up to its first rated point,
//     Q_hp_heat_1, at the COP of the moment (heat_pump_cop_cpp()).
//   - The backup resistances cover the rest of the heating, at COP 1.
//   - Cooling has a single constant COP.
// The electricity is a monotone, piecewise linear function of the
// heat, so a bisection over it needs no simulation.
// Q_heat is the step's ENERGY (kWh) while Q_hp_heat_1 is a POWER
// (kW), so the threshold is the energy the heat pump can deliver in
// the step, Q_hp_heat_1 * delta_t. Comparing the energy against the
// bare power would make the split depend on the timestep length
// instead of on the equipment.
// The minimum and the maximum follow the rule of R's pmin() and
// pmax() for a missing value: the result is missing when either
// operand is, and it is the second operand when both are. A missing
// input gives a missing electricity, as it does in R.
// The file is a header, included by period_simulation_cpp.cpp, so
// that it is compiled with the simulation. It is not exported to R.
// -------------------------------------------------------------
// Inputs
//   Q_heat      : Double. Heating energy of the step (kWh).
//   Q_cool      : Double. Cooling energy of the step (kWh).
//   COP_heat    : Double. Heating COP of the step, as
//                 heat_pump_cop_cpp() returns it.
//   delta_t     : Double. Length of the step (h).
//   Q_hp_heat_1 : Double. First rated heating power of the heat pump
//                 (kW).
//   COP_hp_cool : Double. Cooling COP (dimensionless).
//   Elec_heat   : Double, by reference. Receives the heating
//                 electricity of the step (kWh).
//   Elec_cool   : Double, by reference. Receives the cooling
//                 electricity of the step (kWh).
// -------------------------------------------------------------
// Outputs
//   Elec_heat and Elec_cool, written through their references. The
//   total electricity of the step is Elec_heat + Elec_cool.
// -------------------------------------------------------------
// Code outline
// 1. The heating electricity
// 2. The cooling electricity
// -------------------------------------------------------------
// Usage instructions
// double Elec_heat = 0.0;
// double Elec_cool = 0.0;
// heat_pump_electricity_step(Q_heat, Q_cool, COP_heat, delta_t,
//                            Q_hp_heat_1, COP_hp_cool,
//                            Elec_heat, Elec_cool);
// -------------------------------------------------------------

#ifndef HEAT_PUMP_ELECTRICITY_STEP_H
#define HEAT_PUMP_ELECTRICITY_STEP_H

#include <Rcpp.h>

inline void heat_pump_electricity_step(
  double Q_heat,
  double Q_cool,
  double COP_heat,
  double delta_t,
  double Q_hp_heat_1,
  double COP_hp_cool,
  double &Elec_heat,
  double &Elec_cool
)
{
  // -------------------------------------------------------------
  // 1. The heating electricity
  // The part up to Q_hp_heat_1_step is served at COP_heat, and the
  // rest by the backup resistances at COP 1.
  // -------------------------------------------------------------
  {
    double Q_hp_heat_1_step = Q_hp_heat_1 * delta_t;
    double Q_backup         = Q_heat - Q_hp_heat_1_step;

    double Q_heat_pump = ISNAN(Q_hp_heat_1_step) ? Q_hp_heat_1_step :
      (Q_hp_heat_1_step < Q_heat ? Q_hp_heat_1_step : Q_heat);
    double Q_resistance = (0.0 > Q_backup) ? 0.0 : Q_backup;

    Elec_heat = Q_heat_pump / COP_heat + Q_resistance;
  }

  // -------------------------------------------------------------
  // 2. The cooling electricity
  // -------------------------------------------------------------
  {
    Elec_cool = Q_cool / COP_hp_cool;
  }
}

#endif
