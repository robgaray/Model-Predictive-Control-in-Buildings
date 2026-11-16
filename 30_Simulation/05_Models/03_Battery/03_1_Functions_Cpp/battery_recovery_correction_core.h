// -------------------------------------------------------------
// Function: battery_recovery_correction_core.h
// Part of the Model Predictive Control in buildings repository
// https://github.com/robgaray/Model-Predictive-Control-in-Buildings
// Developed by Roberto Garay Martinez
// -------------------------------------------------------------
// Overall description
// Finds the correction that a battery makes in the Recovery Phase of
// a flexibility leg so that the leg can be carried out until the
// close of the control horizon. It is the compiled method of
// battery_recovery_correction(), whose header describes it in full:
//   - the correction is one power over the steps of the Recovery
//     Phase, in the direction that gives the energy back, and a step
//     that cannot take that power takes what it can still take;
//   - a step never takes more than what brings the leg back to the
//     energy it stored before the window, so the correction stops
//     where the leg is back on that energy;
//   - with no correction the stretch is carried out, or the least
//     power that keeps the limit the window worsens is found by
//     bisection, or the most the battery can do does not keep it and
//     the stretch does not fit;
//   - when the least power found breaks the other limit, it is taken
//     once more where the energy of the step it keeps at the limit is
//     exactly the limit, by a linear interpolation between the last
//     two powers of the bisection, and kept if the stretch is then
//     carried out;
//   - with a target energy, the least power that reaches it at the
//     last step of the Recovery Phase is found by bisection between
//     the least correction and the most the battery can do, and kept
//     if the stretch is carried out with it.
// Each power tested runs the stretch with battery_free_run(). The
// operations are those of R, in the same order, so that the
// correction is exactly the one R would compute.
// The positions of the steps start at 0. The terms of each step are
// computed once by the caller, so that a search that asks for many
// corrections on the same stretch does not compute them again.
// The file is a header, included by battery_trajectory_cpp.cpp. It
// is not callable from R.
// -------------------------------------------------------------
// The structure BatteryCorrection
//   extra : std::vector<double>. The energy added to the request of
//           each step (kWh, 0 outside the Recovery Phase), with the
//           sign of the direction.
//   fits  : Bool. True when the stretch is carried out with that
//           correction.
// -------------------------------------------------------------
// Inputs
//   stored_energy_start : Double. The energy stored before the first
//                         step (kWh).
//   base_request        : std::vector<double>. The request of each
//                         step with no correction (kWh of the system
//                         side, positive to charge).
//   reference_energy    : std::vector<double>, as long as
//                         base_request. The energy the leg stored at
//                         the end of each step before the window (kWh).
//   recovery_steps      : std::vector<int>. The steps of the Recovery
//                         Phase, positions from 0. It may be empty.
//   check_steps         : std::vector<int>. The steps on which the
//                         limits are checked, positions from 0.
//   direction           : Double, 1 to charge in the Recovery Phase
//                         and -1 to discharge.
//   has_target          : Bool. True when a target energy is given.
//   target_energy       : Double. The energy to reach at the last
//                         step of the Recovery Phase (kWh), read only
//                         when has_target is true.
//   limits              : BatteryLimits. The limits of the battery
//                         (battery_limits()).
//   steps               : BatterySteps. The terms of each step
//                         (battery_step_terms()).
//   bisection_steps     : Integer. The halvings of each bisection.
//   tolerance           : Double. The tolerance of the comparisons
//                         with the limits (kWh).
//   correction          : BatteryCorrection. Written: the correction
//                         found.
// -------------------------------------------------------------
// Outputs
//   None returned. The correction is written into correction.
// -------------------------------------------------------------
// Code outline
// 1. The functions of the search
// 2. The most the battery can do
// 3. The least correction
//   3.1. The bisection
//   3.2. The least power at the limit
// 4. The correction that reaches the target energy
// 5. The energy of the correction
// -------------------------------------------------------------
// Usage instructions
// From C++, after including this header:
//   BatteryCorrection correction;
//   battery_recovery_correction_core(stored_energy_start, request,
//                                    reference, recovery, check,
//                                    direction, false, 0.0, limits, steps,
//                                    bisection_steps, tolerance,
//                                    correction);
// -------------------------------------------------------------

#ifndef BATTERY_RECOVERY_CORRECTION_CORE_H
#define BATTERY_RECOVERY_CORRECTION_CORE_H

// The compiler shall not fuse a product and a sum into one
// operation: R never does, and the results must be those of R.
#if defined(__clang__)
#pragma STDC FP_CONTRACT OFF
#elif defined(__GNUC__)
#pragma GCC optimize ("fp-contract=off")
#endif

#include <Rcpp.h>
#include <algorithm>
#include <cmath>
#include <limits>
#include <vector>
#include "battery_limits.h"
#include "battery_step_terms.h"
#include "battery_free_run.h"

struct BatteryCorrection
{
  std::vector<double> extra;
  bool                fits;
};

inline void battery_recovery_correction_core(
  double                     stored_energy_start,
  const std::vector<double> &base_request,
  const std::vector<double> &reference_energy,
  const std::vector<int>    &recovery_steps,
  const std::vector<int>    &check_steps,
  double                     direction,
  bool                       has_target,
  double                     target_energy,
  const BatteryLimits       &limits,
  const BatterySteps        &steps,
  int                        bisection_steps,
  double                     tolerance,
  BatteryCorrection         &correction
)
{
  const std::size_t n_steps      = base_request.size();
  const std::size_t n_recovery   = recovery_steps.size();
  const double      minus_inf    =
    -std::numeric_limits<double>::infinity();
  std::vector<double> step_room(n_recovery);
  std::vector<double> extra(n_steps);
  std::vector<double> request(n_steps);
  std::vector<int>    gap_steps;
  std::vector<int>    recovery_index(n_steps, -1);

  // -------------------------------------------------------------
  // 1. The functions of the search
  // The power each step of the Recovery Phase can still take is the
  // charge power, or the discharge power, less the power of its
  // request. The energy of a correction of a power is, in each step,
  // that power or the one the step can still take, if lower, times
  // the duration of the step, and never more than the energy that
  // brings the leg back to the energy it stored before the window, its
  // reference, at the end of the step. The steps are taken in order,
  // with the energy stored computed as battery_free_run() computes
  // it, so that a step knows the energy the leg has before it. The
  // energy that must enter the battery in a step to end it on the
  // reference gives the request that does it: that energy divided by
  // the charge efficiency, or times the discharge efficiency when it
  // leaves the battery. A step where the leg is already on the
  // reference, or beyond it, takes no correction. So the correction
  // stops where the leg is back on its reference, and the leg follows
  // it from there. The stretch is run with the correction
  // of a power, and it breaks a limit on the side that the window
  // worsens, or on any side. The gap of a run on the side that the
  // window worsens is how far the stored energy of its worst step is
  // beyond the limit of that side. Only the steps from the start of
  // the Recovery Phase on, and that move energy towards that limit,
  // count. A missing value is kept where R would keep it.
  // -------------------------------------------------------------
  {
    for (std::size_t CONT_001 = 0; CONT_001 < n_recovery; ++CONT_001)
    {
      int    step = recovery_steps[CONT_001];
      double room = (direction == 1) ?
        limits.power_charge - base_request[step] / steps.delta_t_h[step] :
        limits.power_disch + base_request[step] / steps.delta_t_h[step];
      step_room[CONT_001] = (std::isnan(room) || room > 0.0) ? room : 0.0;
      recovery_index[step] = (int) CONT_001;
    }

    if (n_recovery > 0)
    {
      int first_recovery = *std::min_element(recovery_steps.begin(),
                                             recovery_steps.end());
      for (std::size_t CONT_002 = 0; CONT_002 < check_steps.size();
           ++CONT_002)
      {
        if (check_steps[CONT_002] >= first_recovery)
        {
          gap_steps.push_back(check_steps[CONT_002]);
        }
      }
    }
  }

  auto extra_of = [&](double power)
  {
    std::fill(extra.begin(), extra.end(), 0.0);
    long double energy_in_all = 0.0L;
    for (std::size_t CONT_003 = 0; CONT_003 < n_steps; ++CONT_003)
    {
      int index = recovery_index[CONT_003];
      if (index >= 0)
      {
        double room    = step_room[index];
        double served  = (std::isnan(room) || room < power) ? room : power;
        double offered = served * steps.delta_t_h[CONT_003];
        double kept    = steps.keep_total[CONT_003] *
          (stored_energy_start + (double) energy_in_all);
        double needed_in      = reference_energy[CONT_003] - kept;
        double needed_request = (needed_in >= 0) ?
          needed_in / limits.eta_charge : needed_in * limits.eta_disch;
        double needed = direction *
          (needed_request - base_request[CONT_003]);
        double taken  = (needed < offered) ? needed : offered;
        if (taken < 0)
        {
          taken = 0.0;
        }
        extra[CONT_003] = direction * taken;
      }
      double asked     = base_request[CONT_003] + extra[CONT_003];
      double energy_in = limits.eta_charge * std::max(asked, 0.0) -
        std::max(-asked, 0.0) / limits.eta_disch;
      energy_in_all += energy_in / steps.keep_total[CONT_003];
    }
  };

  // battery_free_run() is called by run_of to run the stretch with
  // the correction of a power and find the steps that break a limit.
  auto run_of = [&](double power, BatteryFreeRun &run)
  {
    extra_of(power);
    for (std::size_t CONT_004 = 0; CONT_004 < n_steps; ++CONT_004)
    {
      request[CONT_004] = base_request[CONT_004] + extra[CONT_004];
    }
    battery_free_run(stored_energy_start, request, limits, steps,
                     tolerance, run);
  };

  auto worse_of = [&](const BatteryFreeRun &run)
  {
    for (std::size_t CONT_005 = 0; CONT_005 < check_steps.size();
         ++CONT_005)
    {
      int step = check_steps[CONT_005];
      if ((direction == 1) ? run.breach_low[step] : run.breach_high[step])
      {
        return true;
      }
    }
    return false;
  };

  auto any_of = [&](const BatteryFreeRun &run)
  {
    for (std::size_t CONT_006 = 0; CONT_006 < check_steps.size();
         ++CONT_006)
    {
      int step = check_steps[CONT_006];
      if (run.breach_low[step] || run.breach_high[step])
      {
        return true;
      }
    }
    return false;
  };

  auto gap_of = [&](double power, const BatteryFreeRun &run)
  {
    extra_of(power);
    double gap = minus_inf;
    for (std::size_t CONT_007 = 0; CONT_007 < gap_steps.size(); ++CONT_007)
    {
      int    step       = gap_steps[CONT_007];
      double step_ask   = base_request[step] + extra[step];
      double step_gap   = minus_inf;
      if (direction == 1)
      {
        if (step_ask < 0)
        {
          step_gap = limits.energy_min - run.stored_energy[step];
        }
      }
      else
      {
        if (step_ask > 0)
        {
          step_gap = run.stored_energy[step] - limits.energy_max;
        }
      }
      if (step_gap > gap)
      {
        gap = step_gap;
      }
    }
    return gap;
  };

  // -------------------------------------------------------------
  // 2. The most the battery can do
  // The power that takes every step of the Recovery Phase to its
  // charge power, or to its discharge power.
  // -------------------------------------------------------------
  double power_max = 0.0;
  {
    for (std::size_t CONT_008 = 0; CONT_008 < n_recovery; ++CONT_008)
    {
      if (step_room[CONT_008] > power_max)
      {
        power_max = step_room[CONT_008];
      }
    }
  }

  // -------------------------------------------------------------
  // 3. The least correction
  // With no correction, the stretch is carried out or the limit the
  // window worsens is broken. In the second case a bisection finds
  // the least power that keeps it, if the most the battery can do
  // keeps it.
  // Sub-blocks:
  //   3.1. The bisection
  //   3.2. The least power at the limit
  // -------------------------------------------------------------
  double         power_least = 0.0;
  double         power_low   = 0.0;
  bool           has_low     = false;
  bool           exhausted   = false;
  BatteryFreeRun run_least;
  BatteryFreeRun run_test;

  // -------------------------------------------------------------
  // 3.1. The bisection
  // -------------------------------------------------------------
  {
    run_of(0.0, run_least);

    if (worse_of(run_least))
    {
      run_of(power_max, run_test);
      if (worse_of(run_test))
      {
        exhausted   = true;
        power_least = power_max;
        std::swap(run_least, run_test);
      }
      else
      {
        has_low = true;
        double power_high = power_max;
        for (int CONT_009 = 0; CONT_009 < bisection_steps; ++CONT_009)
        {
          double power_mid = (power_low + power_high) / 2;
          run_of(power_mid, run_test);
          if (worse_of(run_test))
          {
            power_low  = power_mid;
          }
          else
          {
            power_high = power_mid;
          }
        }
        power_least = power_high;
        run_of(power_least, run_least);
      }
    }
  }

  // -------------------------------------------------------------
  // 3.2. The least power at the limit
  // Only when the least power found breaks the other limit. The gap
  // of the stored energy on the side that the window worsens is
  // linear in the power between the last two powers of the
  // bisection, so the power where it is 0 is interpolated between
  // them, within the powers the battery can make. It is kept when
  // the stretch is carried out with it.
  // -------------------------------------------------------------
  {
    if (!exhausted && has_low && any_of(run_least))
    {
      run_of(power_low, run_test);
      double gap_low  = gap_of(power_low, run_test);
      double gap_high = gap_of(power_least, run_least);
      if (std::isfinite(gap_low) && std::isfinite(gap_high) &&
          gap_low != gap_high)
      {
        double power_limit = power_least - gap_high *
          (power_least - power_low) / (gap_high - gap_low);
        power_limit = std::min(std::max(power_limit, power_low),
                               power_max);
        run_of(power_limit, run_test);
        if (!any_of(run_test))
        {
          power_least = power_limit;
          std::swap(run_least, run_test);
        }
      }
    }

    correction.fits = !exhausted && !any_of(run_least);
  }

  // -------------------------------------------------------------
  // 4. The correction that reaches the target energy
  // The energy at the last step of the Recovery Phase moves in one
  // direction with the power, so the least power that reaches the
  // target is found by bisection between the least correction and
  // the most the battery can do. The target is the reference of that
  // step, which the correction never passes, so it is reached when
  // the energy is within the tolerance of it. If the stretch is not
  // carried out with it, the least correction is kept.
  // -------------------------------------------------------------
  double power = power_least;
  {
    if (has_target && correction.fits && n_recovery > 0)
    {
      int last_step = *std::max_element(recovery_steps.begin(),
                                         recovery_steps.end());
      auto reached_of = [&](double power_test)
      {
        run_of(power_test, run_test);
        double energy = run_test.stored_energy[last_step];
        return (direction == 1) ? energy >= target_energy - tolerance :
          energy <= target_energy + tolerance;
      };

      double power_plan;
      if (reached_of(power_least))
      {
        power_plan = power_least;
      }
      else if (!reached_of(power_max))
      {
        power_plan = power_max;
      }
      else
      {
        double power_from = power_least;
        double power_to   = power_max;
        for (int CONT_010 = 0; CONT_010 < bisection_steps; ++CONT_010)
        {
          double power_mid = (power_from + power_to) / 2;
          if (reached_of(power_mid))
          {
            power_to   = power_mid;
          }
          else
          {
            power_from = power_mid;
          }
        }
        power_plan = power_to;
      }

      run_of(power_plan, run_test);
      if (!any_of(run_test))
      {
        power = power_plan;
      }
    }
  }

  // -------------------------------------------------------------
  // 5. The energy of the correction
  // -------------------------------------------------------------
  {
    extra_of(power);
    correction.extra = extra;
  }
}

#endif
