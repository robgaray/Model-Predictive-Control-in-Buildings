# heat_pump_cop_cpp.h

**C++ module** &nbsp;·&nbsp; `30_Simulation/05_Models/01_Building/03_1_Functions_Cpp/heat_pump_cop_cpp.h`

## Function

Returns the heating COP of the heat pump at each outdoor temperature. It is the only place where the COP is written: the period simulation, the bisection of the commitment margin and, from R, heat_pump_cop() all take it from here. The COP is referred to a rating point: it equals COP_hp_heat_1_coef1 at (Text_ref_hp_heat, Tsup_ref_hp_heat) and is corrected linearly by how far each temperature departs from it. The reference is the A7/W35 rating point of EN 14511, which is why the coefficients are only meaningful alongside the two reference temperatures. A heat pump never gives less heat than the electricity it uses, so the COP is never below 1: where the line falls below 1 (at very low outdoor temperatures, or with other coefficients), the COP is 1.

- COP = max(1, COP_hp_heat_1_coef1 + COP_hp_heat_1_coef2 * (Text - Text_ref_hp_heat) + COP_hp_heat_1_coef3 * (Tsup_hp_heat - Tsup_ref_hp_heat))

The file is a header, included by period_simulation_cpp.cpp, so that the single Rcpp::sourceCpp() call that compiles the simulation also compiles and exports this function.

## Called by

- [apply_commitment_margin_cpp.h](apply_commitment_margin_cpp.md)
- [heat_pump_cop.R](heat_pump_cop.md)
- [period_simulation_cpp.cpp](period_simulation_cpp.md)

## What it calls, in order of appearance

- Nothing: this piece calls no other piece of the project.

## Input data

- Text                : NumericVector. Outdoor temperature (degC).
- COP_hp_heat_1_coef1 : Double. Heating COP at the reference point, dimensionless.
- COP_hp_heat_1_coef2 : Double. Sensitivity of the COP to the outdoor temperature (1/degC).
- COP_hp_heat_1_coef3 : Double. Sensitivity of the COP to the supply temperature (1/degC).
- Tsup_hp_heat        : Double. Supply temperature (degC).
- Text_ref_hp_heat    : Double. Outdoor temperature of the reference point (degC).
- Tsup_ref_hp_heat    : Double. Supply temperature of the reference point (degC).

## Output data

- NumericVector, the length of Text. The heating COP at each outdoor temperature, never below 1.

## Other notes from the file header

### Code outline

1. The COP at each outdoor temperature

### Usage instructions

From C++, after including this header:

- NumericVector cop = heat_pump_cop_cpp(Text, coef1, coef2, coef3, Tsup, Text_ref, Tsup_ref);

From R, once period_simulation_cpp.cpp is compiled, through heat_pump_cop(Text, parameters).

## Diagram

![Block diagram of heat_pump_cop_cpp.h](heat_pump_cop_cpp.jpg)

Also available as [heat_pump_cop_cpp.svg](heat_pump_cop_cpp.svg).

---

[Back to the code structure index](../Code_Structure.md)
