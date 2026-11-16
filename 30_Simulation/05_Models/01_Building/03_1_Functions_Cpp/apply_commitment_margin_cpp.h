// -------------------------------------------------------------
// Function: apply_commitment_margin_cpp.h
// Part of the Model Predictive Control in buildings repository
// https://github.com/robgaray/Model-Predictive-Control-in-Buildings
// Developed by Roberto Garay Martinez
// -------------------------------------------------------------
// Overall description
// The compiled core of apply_commitment_margin(): one market slot at a
// time, it finds the deepest scaling of the itinerary whose
// electricity stays inside the bound of the slot, by bisection on the
// closed form of the electricity.
// The bound of every slot comes in already computed: it is the
// commitment band the system asks of the slot, set by
// commitment_margin_bound() from energy alone. This function is the
// side of the asset: it fits the heat of the itinerary into that
// band.
// The electricity of a row is the one heat_pump_electricity_step()
// computes, at the COP of heat_pump_cop_cpp(): the same electrical
// model the period simulation uses. It is a monotone, piecewise
// linear function of the heat of the row, so the electricity of the
// slot is monotone in the scaling factor and the bisection needs no
// simulation.
// The rules it applies, and why the margin exists, are described in
// apply_commitment_margin(), which prepares its inputs.
// -------------------------------------------------------------
// The sums of a slot
// The electricity of a slot is added up in long double and the rows
// that are missing are left out, as R's sum(..., na.rm = TRUE) does,
// which is how commitment_margin_bound() adds up the bound. The total
// is then rounded to a double.
// A sum beyond the range of a double is returned as an infinity of
// the same sign.
// -------------------------------------------------------------
// The file is a header, included by period_simulation_cpp.cpp, so
// that the single Rcpp::sourceCpp() call that compiles the simulation
// also compiles and exports this function.
// -------------------------------------------------------------
// Inputs
// All the vectors are the same length, one entry per row of the
// Commitment Phase, and all the heat quantities are energies in kWh.
//   Q_heat_flex         : NumericVector. Heating of the itinerary,
//                         before the margin.
//   Q_heat_plan         : NumericVector. Heating of the plan.
//   Q_cool_flex         : NumericVector. Cooling of the itinerary.
//   Q_cool_plan         : NumericVector. Cooling of the plan.
//   slot_id             : IntegerVector. The market slot of each row,
//                         numbered from 1. A row with 0 belongs to no
//                         slot and is left as it is.
//   bound               : NumericVector, one entry per slot. The
//                         electricity (kWh) the itinerary of the slot
//                         may reach: at most this upward, at least
//                         this downward.
//   Text                : NumericVector. Outdoor temperature (degC).
//   delta_t_h           : NumericVector. Timestep (h).
//   leg_up              : Boolean. True for the upward leg, false for
//                         the downward one.
//   bisection_steps     : Integer. Number of halvings of the
//                         bisection (parameter
//                         flexibility_commitment_bisection_steps).
//   COP_hp_heat_1_coef1, COP_hp_heat_1_coef2, COP_hp_heat_1_coef3,
//   Tsup_hp_heat, Text_ref_hp_heat, Tsup_ref_hp_heat
//                       : Double. The COP of the heat pump, as
//                         heat_pump_cop_cpp() reads them.
//   Q_hp_heat_1         : Double. First rated heating power (kW).
//   COP_hp_cool         : Double. Cooling COP (dimensionless).
// -------------------------------------------------------------
// Outputs
//   List with two NumericVectors the length of the inputs:
//     Q_heat : heating of the itinerary after the margin
//     Q_cool : cooling of the itinerary after the margin
// -------------------------------------------------------------
// Code outline
// 1. Check the inputs, and the COP and the rows of every slot
// 2. One slot at a time, find the deepest factor that meets the rule
//    2.1. The plan and the itinerary against the bound
//    2.2. The bisection
// 3. Return the itinerary
// -------------------------------------------------------------
// Usage instructions
// From R, once period_simulation_cpp.cpp is compiled, through
// apply_commitment_margin().
// -------------------------------------------------------------

#ifndef APPLY_COMMITMENT_MARGIN_CPP_H
#define APPLY_COMMITMENT_MARGIN_CPP_H

#include <Rcpp.h>
#include <cfloat>
#include <vector>
#include "heat_pump_cop_cpp.h"
#include "heat_pump_electricity_step.h"

// [[Rcpp::export]]
inline Rcpp::List apply_commitment_margin_cpp(
  Rcpp::NumericVector Q_heat_flex,
  Rcpp::NumericVector Q_heat_plan,
  Rcpp::NumericVector Q_cool_flex,
  Rcpp::NumericVector Q_cool_plan,
  Rcpp::IntegerVector slot_id,
  Rcpp::NumericVector bound,
  Rcpp::NumericVector Text,
  Rcpp::NumericVector delta_t_h,
  bool leg_up,
  int bisection_steps,
  double COP_hp_heat_1_coef1,
  double COP_hp_heat_1_coef2,
  double COP_hp_heat_1_coef3,
  double Tsup_hp_heat,
  double Text_ref_hp_heat,
  double Tsup_ref_hp_heat,
  double Q_hp_heat_1,
  double COP_hp_cool
)
{
  int n       = Q_heat_flex.size();
  int n_slots = bound.size();

  Rcpp::NumericVector COP_heat;
  std::vector< std::vector<int> > slot_rows(n_slots);

  // -------------------------------------------------------------
  // 1. Check the inputs, and the COP and the rows of every slot
  // The rows of a slot are kept in increasing order, which is the
  // order its sums are taken in.
  // -------------------------------------------------------------
  {
    if (Q_heat_plan.size() != n || Q_cool_flex.size() != n ||
        Q_cool_plan.size() != n || slot_id.size() != n ||
        Text.size() != n || delta_t_h.size() != n)
    {
      Rcpp::stop("apply_commitment_margin_cpp: every vector must have "
                 "the same length");
    }

    // heat_pump_cop_cpp is called once for the COP of every row,
    // which depends on the outdoor temperature alone.
    COP_heat = heat_pump_cop_cpp(
      Text,
      COP_hp_heat_1_coef1,
      COP_hp_heat_1_coef2,
      COP_hp_heat_1_coef3,
      Tsup_hp_heat,
      Text_ref_hp_heat,
      Tsup_ref_hp_heat
    );

    for (int CONT_001 = 0; CONT_001 < n; ++CONT_001)
    {
      int slot = slot_id[CONT_001];
      if (slot >= 1 && slot <= n_slots)
      {
        slot_rows[slot - 1].push_back(CONT_001);
      }
    }
  }

  // The electricity of one row, added to the sum of its slot.
  // heat_pump_electricity_step is called for the heating and the
  // cooling electricity of the row; a missing total is left out.
  auto add_row_electricity = [&](long double &sum, double Q_heat,
                                 double Q_cool, int row)
  {
    double Elec_heat = 0.0;
    double Elec_cool = 0.0;
    heat_pump_electricity_step(
      Q_heat,
      Q_cool,
      COP_heat[row],
      delta_t_h[row],
      Q_hp_heat_1,
      COP_hp_cool,
      Elec_heat,
      Elec_cool
    );
    double Elec_total = Elec_heat + Elec_cool;
    if (!ISNAN(Elec_total))
    {
      sum += Elec_total;
    }
  };

  // A long double sum rounded to a double, as R's sum() returns it.
  auto close_sum = [](long double sum)
  {
    if (sum > DBL_MAX)
    {
      return R_PosInf;
    }
    if (sum < -DBL_MAX)
    {
      return R_NegInf;
    }
    return (double) sum;
  };

  // The electricity of some rows for a given heat pair.
  auto slot_electricity = [&](Rcpp::NumericVector &Q_heat,
                              Rcpp::NumericVector &Q_cool,
                              const std::vector<int> &rows)
  {
    long double sum = 0.0;
    for (size_t CONT_002 = 0; CONT_002 < rows.size(); ++CONT_002)
    {
      int row = rows[CONT_002];
      add_row_electricity(sum, Q_heat[row], Q_cool[row], row);
    }
    return close_sum(sum);
  };

  Rcpp::NumericVector Q_heat_out = Rcpp::clone(Q_heat_flex);
  Rcpp::NumericVector Q_cool_out = Rcpp::clone(Q_cool_flex);

  // -------------------------------------------------------------
  // 2. One slot at a time, find the deepest factor that meets the rule
  // Upward the electricity of the slot must stay at or below its
  // bound; downward, at or above it. inside() carries the direction,
  // so the rest of the block is the same for both legs.
  // Index of sub-blocks:
  //   2.1. The plan and the itinerary against the bound
  //   2.2. The bisection
  // -------------------------------------------------------------
  {
    for (int CONT_003 = 0; CONT_003 < n_slots; ++CONT_003)
    {
      const std::vector<int> &rows = slot_rows[CONT_003];
      int n_rows = rows.size();

      double slot_bound = bound[CONT_003];

      auto inside = [&](double value)
      {
        return leg_up ? (value <= slot_bound) : (value >= slot_bound);
      };

      // -------------------------------------------------------------
      // 2.1. The plan and the itinerary against the bound
      // The plan itself outside the band means the slot has no service
      // to offer, whatever the factor, so it is left as the plan. The
      // itinerary as the caller built it already inside the band needs
      // nothing.
      // -------------------------------------------------------------
      {
        if (!inside(slot_electricity(Q_heat_plan, Q_cool_plan, rows)))
        {
          for (int CONT_005 = 0; CONT_005 < n_rows; ++CONT_005)
          {
            int row = rows[CONT_005];
            Q_heat_out[row] = Q_heat_plan[row];
            Q_cool_out[row] = Q_cool_plan[row];
          }
          continue;
        }

        if (inside(slot_electricity(Q_heat_flex, Q_cool_flex, rows)))
        {
          continue;
        }
      }

      // -------------------------------------------------------------
      // 2.2. The bisection
      // low is the deepest factor tested that stays inside the band,
      // high the shallowest that does not, so the bisection closes on
      // the deepest itinerary the margin allows. A candidate only
      // differs from the plan on the rows of this slot, so the
      // bisection works on those rows alone.
      // -------------------------------------------------------------
      {
        double low  = 0.0;
        double high = 1.0;

        std::vector<double> heat_move(n_rows);
        std::vector<double> cool_move(n_rows);
        for (int CONT_006 = 0; CONT_006 < n_rows; ++CONT_006)
        {
          int row = rows[CONT_006];
          heat_move[CONT_006] = Q_heat_flex[row] - Q_heat_plan[row];
          cool_move[CONT_006] = Q_cool_flex[row] - Q_cool_plan[row];
        }

        for (int CONT_007 = 0; CONT_007 < bisection_steps; ++CONT_007)
        {
          double middle = (low + high) / 2.0;

          long double sum = 0.0;
          for (int CONT_008 = 0; CONT_008 < n_rows; ++CONT_008)
          {
            int row = rows[CONT_008];
            double candidate_heat =
              Q_heat_plan[row] + middle * heat_move[CONT_008];
            double candidate_cool =
              Q_cool_plan[row] + middle * cool_move[CONT_008];
            add_row_electricity(sum, candidate_heat, candidate_cool, row);
          }

          if (inside(close_sum(sum)))
          {
            low  = middle;
          }
          else
          {
            high = middle;
          }
        }

        for (int CONT_009 = 0; CONT_009 < n_rows; ++CONT_009)
        {
          int row = rows[CONT_009];
          Q_heat_out[row] = Q_heat_plan[row] +
            low * (Q_heat_flex[row] - Q_heat_plan[row]);
          Q_cool_out[row] = Q_cool_plan[row] +
            low * (Q_cool_flex[row] - Q_cool_plan[row]);
        }
      }
    }
  }

  // -------------------------------------------------------------
  // 3. Return the itinerary
  // -------------------------------------------------------------
  return Rcpp::List::create(
    Rcpp::Named("Q_heat") = Q_heat_out,
    Rcpp::Named("Q_cool") = Q_cool_out
  );
}

#endif
