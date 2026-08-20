// -------------------------------------------------------------
// Function: period_simulation_cpp.cpp
// Part of the Model Predictive Control in buildings repository
// https://github.com/robgaray/Model-Predictive-Control-in-Buildings
// Developed by Roberto Garay Martinez
// -------------------------------------------------------------
// Overall description
// This function implements the core thermal simulation loop in C++ using Rcpp.
// It performs a sequential step-by-step calculation of building temperatures
// (internal Ti and envelope Te) based on a 2C RC building model.
// This function performs no economic calculation: energy cost is always
// resolved afterwards in R, through reward_function()/
// compute_marginal_energy_cost() (planning contexts) or through
// calc_differential_cost() (execution accounting), both of which apply the
// buy/sell price distinction this simplified per-timestep multiplication
// cannot express.
// -------------------------------------------------------------
// Inputs
//   Ti                     : NumericVector. Internal temperature.
//   Te                     : NumericVector. Envelope temperature.
//   Act_heat               : IntegerVector. Heating activation states.
//   Act_cool               : IntegerVector. Cooling activation states.
//   Q_heat                 : NumericVector. Heating energy per step.
//   Q_cool                 : NumericVector. Cooling energy per step.
//   Elec_heat              : NumericVector. Heating electricity.
//   Elec_cool              : NumericVector. Cooling electricity.
//   Elec_total             : NumericVector. Total electricity.
//   Comfort                : IntegerVector. Comfort flags.
//   SolarR                 : NumericVector. Solar radiation.
//   Text                   : NumericVector. Outdoor temperature.
//   T_ext_24h              : NumericVector. 24h mean outdoor temperature.
//   Act_vent               : IntegerVector. Ventilation activation.
//   time                   : NumericVector. Simulation timestamps (seconds).
//   comfort_low            : NumericVector. Lower comfort temperature limit.
//   comfort_high           : NumericVector. Upper comfort temperature limit.
//   STP_heat_low           : NumericVector. Lower heating setpoint.
//   STP_heat_high          : NumericVector. Upper heating setpoint.
//   STP_cool_low           : NumericVector. Lower cooling setpoint.
//   STP_cool_high          : NumericVector. Upper cooling setpoint.
//   calculation_mode_vec   : IntegerVector. Computation mode per step.
//   Ci, Ce, Rie, Rea       : Double. Thermal model parameters.
//   Aw, Ae                 : Double. Solar aperture parameters.
//   Shading_0, Shading_1   : Double. Shading coefficients.
//   Setpoint_Shading1      : Double. Shading activation threshold.
//   AT_hp_heat_1, AT_hp_heat_2: Double. Heat pump temperature deltas.
//   Q_hp_heat_1, Q_hp_heat_2  : Double. Heat pump heating capacities.
//   COP_hp_heat_1_coef1    : Double. COP coefficient 1.
//   COP_hp_heat_1_coef2    : Double. COP coefficient 2.
//   COP_hp_heat_1_coef3    : Double. COP coefficient 3.
//   Tsup_hp_heat           : Double. Heat pump supply temperature.
//   Q_hp_cool, COP_hp_cool : Double. Cooling capacity and COP.
//   Rvent01, Rvent1        : Double. Ventilation resistance values.
//   Rvent2, Rvent2_HR      : Double. Ventilation resistance values.
//   Setpoint_Rvent1        : Double. Ventilation threshold.
//   inertial_fact          : Double. Thermal inertia factor.
// -------------------------------------------------------------
// Outputs
//   List                   : Contains all updated simulation vectors.
// -------------------------------------------------------------
// Code outline
// 1. Extract dimensions and verify inputs.
// 2. Loop through each timestep to calculate thermal dynamics.
// 3. Construct and return the output List.
// -------------------------------------------------------------
// Usage instructions
// Called from R via period_calculation.R.
// -------------------------------------------------------------
// Where this function/script is used
// Called by period_calculation.R.
// -------------------------------------------------------------
// functions/scripts called
// (none)
// -------------------------------------------------------------

#include <Rcpp.h>
#include <algorithm>

using namespace Rcpp;

// [[Rcpp::export]]
List period_simulation_cpp(
  NumericVector Ti,
  NumericVector Te,
  IntegerVector Act_heat,
  IntegerVector Act_cool,
  NumericVector Q_heat,
  NumericVector Q_cool,
  NumericVector Elec_heat,
  NumericVector Elec_cool,
  NumericVector Elec_total,
  IntegerVector Comfort,
  NumericVector SolarR,
  NumericVector Text,
  NumericVector T_ext_24h,
  IntegerVector Act_vent,
  NumericVector time,
  NumericVector comfort_low,
  NumericVector comfort_high,
  NumericVector STP_heat_low,
  NumericVector STP_heat_high,
  NumericVector STP_cool_low,
  NumericVector STP_cool_high,
  IntegerVector calculation_mode_vec,
  double Ci,
  double Ce,
  double Rie,
  double Rea,
  double Aw,
  double Ae,
  double Shading_0,
  double Shading_1,
  double Setpoint_Shading1,
  double AT_hp_heat_1,
  double AT_hp_heat_2,
  double Q_hp_heat_1,
  double Q_hp_heat_2,
  double COP_hp_heat_1_coef1,
  double COP_hp_heat_1_coef2,
  double COP_hp_heat_1_coef3,
  double Tsup_hp_heat,
  double Q_hp_cool,
  double COP_hp_cool,
  double Rvent01,
  double Rvent1,
  double Rvent2,
  double Rvent2_HR,
  double Setpoint_Rvent1,
  double inertial_fact
)
{
  int n = Ti.size();

  // -------------------------------------------------------------
  // 1. Simulation loop
  // -------------------------------------------------------------
  for (int CONT_001 = 1; CONT_001 < n; ++CONT_001)
  {
    double Ti_prev        = 0.0;
    double Te_prev        = 0.0;
    int Act_heat_prev     = 0;
    int Act_cool_prev     = 0;
    double Q_heat_prev    = 0.0;
    double Q_cool_prev    = 0.0;
    double SolarR_t       = 0.0;
    int Act_vent_t        = 0;
    double Text_t         = 0.0;
    double STP_heat_low_t  = 0.0;
    double STP_heat_high_t = 0.0;
    double STP_cool_low_t  = 0.0;
    double STP_cool_high_t = 0.0;
    double T_ext_24h_t     = 0.0;
    double comfort_low_t   = 0.0;
    double comfort_high_t  = 0.0;
    double delta_t         = 0.0;

    // -------------------------------------------------------------
    // 1.1. Extract previous and current values
    // -------------------------------------------------------------
    {
      
      // previous values
      Ti_prev         = Ti[CONT_001 - 1];
      Te_prev         = Te[CONT_001 - 1];
      Act_heat_prev   = Act_heat[CONT_001 - 1];
      Act_cool_prev   = Act_cool[CONT_001 - 1];
      Q_heat_prev     = Q_heat[CONT_001 - 1];
      Q_cool_prev     = Q_cool[CONT_001 - 1];

      // current values
      SolarR_t         = SolarR[CONT_001];
      Act_vent_t       = Act_vent[CONT_001];
      Text_t           = Text[CONT_001];
      STP_heat_low_t   = STP_heat_low[CONT_001];
      STP_heat_high_t  = STP_heat_high[CONT_001];
      STP_cool_low_t   = STP_cool_low[CONT_001];
      STP_cool_high_t  = STP_cool_high[CONT_001];
      T_ext_24h_t      = T_ext_24h[CONT_001];
      comfort_low_t    = comfort_low[CONT_001];
      comfort_high_t   = comfort_high[CONT_001];

      // delta time (minutes)
      delta_t          = (time[CONT_001] - time[CONT_001 - 1]) / 3600.0;
    }

    int Act_heat_new = 0;
    int Act_cool_new = 0;
    
    // -------------------------------------------------------------
    // 1.2. Heating and Cooling control (Hysteresis)
    // -------------------------------------------------------------
    {
      // Act_heat calculation (histeresis)
      if (Ti_prev < STP_heat_low_t)
      {
        Act_heat_new = 1;
      }
      else if (Ti_prev > STP_heat_high_t)
      {
        Act_heat_new = 0;
      }
      else
      {
        Act_heat_new = Act_heat_prev;
      }
      
      // Act_cool calculation (histeresis)
      // Depends on Act_heat_new to avoid double activation
      if (Act_heat_new == 1)
      {
        Act_cool_new = 0;
      }
      else if (Ti_prev > STP_cool_high_t)
      {
        Act_cool_new = 1;
      }
      else if (Ti_prev < STP_cool_low_t)
      {
        Act_cool_new = 0;
      }
      else
      {
        Act_cool_new = Act_cool_prev;
      }
    }

    double Q_heat_new = 0.0;
    double Q_cool_new = 0.0;
    // -------------------------------------------------------------
    // 1.3. Heating and Cooling energy
    // -------------------------------------------------------------
    {
      // Check calculation_mode at current timestep
      int calculation_mode_t = calculation_mode_vec[CONT_001];

      if (calculation_mode_t == 1)
      {
        // Setpoint mode: calculate Q_heat and Q_cool based on setpoints
        // Q_heat calculation (piecewise)
        double Delta_temp_h = STP_heat_high_t - Ti_prev;
        if (Act_heat_new == 1)
        {
          if (Delta_temp_h < AT_hp_heat_1)
          {
            Q_heat_new = Q_hp_heat_1;
          }
          else if (Delta_temp_h > AT_hp_heat_2)
          {
            Q_heat_new = Q_hp_heat_2;
          }
          else
          {
            Q_heat_new = Q_hp_heat_1 + 
              (Q_hp_heat_2 - Q_hp_heat_1) * (Delta_temp_h - AT_hp_heat_1) / (AT_hp_heat_2 - AT_hp_heat_1);
          }
        }
        else
        {
          Q_heat_new = 0.0;
        }
        
        // Q_cool calculation
        if (Act_cool_new == 1)
        {
          Q_cool_new = Q_hp_cool;
        }
        else
        {
          Q_cool_new = 0.0;
        }
      }
      else if (calculation_mode_t == 2)
      {
        // Heat Input mode: get Q_heat and Q_cool directly from period_chunk
        // Divides by delta_t to avoid unit problems since
        // the rest of the calculations expect power (kW or equivalent)
        // rather than energy (kWh or equivalent)
        Q_heat_new = Q_heat[CONT_001] / delta_t;
        Q_cool_new = Q_cool[CONT_001] / delta_t;
      }
    }

    double Rvent_t   = 0.0;
    double Shading_t = 0.0;

    // -------------------------------------------------------------
    // 1.4. Ventilation and Shading
    // -------------------------------------------------------------
    {
      // Rvent calculation
      // For daytime ventilation (Act_vent_t == 1), an advanced selection
      // logic is applied based on T_equilibrium and the comparison between
      // indoor and outdoor temperatures. The heat recovery system (HR) is
      // activated when it reduces energy consumption:
      //   - Heating mode (Ti < T_eq): activate HR when outdoor is colder
      //     than indoor (prevents heat loss through ventilation).
      //   - Cooling mode (Ti > T_eq): activate HR when outdoor is warmer
      //     than indoor (prevents heat gain through ventilation).
      
      if (Act_vent_t == 1)
      {
        double T_equilibrium_t = (STP_heat_high_t + STP_cool_low_t) / 2.0;
        
        // Heat recovery (HR) is beneficial when ventilation would worsen the
        // thermal balance. HR is activated when outdoor air temperature (Text_t)
        // drives the building away from comfort:
        //   Cooling mode (Ti > T_eq): outdoor warmer than indoor → activate HR
        //   Cooling mode (Ti > T_eq): outdoor cooler than indoor → no HR (free cooling)
        //   Heating mode (Ti < T_eq): outdoor cooler than indoor → activate HR
        //   Heating mode (Ti < T_eq): outdoor warmer than indoor → no HR (free heating)

        if (Ti_prev > T_equilibrium_t && Ti_prev < Text_t)
        {
          Rvent_t = Rvent2_HR;
        }
        else if (Ti_prev < T_equilibrium_t && Ti_prev < Text_t)
        {
          Rvent_t = Rvent2;
        }
        else if (Ti_prev > T_equilibrium_t && Ti_prev > Text_t)
        {
          Rvent_t = Rvent2;
        }
        else
        {
          Rvent_t = Rvent2_HR;
        }
      }
      else if (!NumericVector::is_na(T_ext_24h_t) && T_ext_24h_t >= Setpoint_Rvent1)
      {
        Rvent_t = Rvent1;
      }
      else
      {
        Rvent_t = Rvent01;
      }

      // Shading: Shading_t is the fraction of window solar gain blocked
      // (0 = unshaded, 1 = fully shaded) - applied as (1 - Shading_t)
      // below. Full shading (Shading_1) engages when the 24h running
      // mean outdoor temperature exceeds Setpoint_Shading1 (avoids
      // overheating in warm periods); the baseline coefficient
      // (Shading_0) applies otherwise.
      Shading_t = (!NumericVector::is_na(T_ext_24h_t) && T_ext_24h_t > Setpoint_Shading1) ? Shading_1 : Shading_0;
    }

    double Ti_new = 0.0;
    double Te_new = 0.0;

    // -------------------------------------------------------------
    // 1.5. Internal temperature calculations (RC equations)
    // -------------------------------------------------------------
    {
      Ti_new = Ti_prev + 
                ((Te_prev - Ti_prev) / Rie + 
                 (Text_t - Ti_prev) / Rvent_t + 
                 (Aw * SolarR_t * (1.0 - Shading_t) / 1000.0) +
                 ((1.0 - inertial_fact) * (Q_heat_new - Q_cool_new) + 
                  (inertial_fact) * (Q_heat_prev / delta_t - Q_cool_prev / delta_t))) *
                (1.0 / Ci) * delta_t;
                
      Te_new = Te_prev + 
                ((Ti_prev - Te_prev) / Rie + 
                 (Text_t - Te_prev) / Rea + 
                 (Ae * SolarR_t / 1000.0)) *
                (1.0 / Ce) * delta_t;
      
      // Heat pump power to per-step energy conversion for proper storage
      Q_heat_new *= delta_t;
      Q_cool_new *= delta_t;
    }

    double Elec_heat_t  = 0.0;
    double Elec_cool_t  = 0.0;
    double Elec_total_t = 0.0;

    // -------------------------------------------------------------
    // 1.6. Electricity calculation (no cost: see file header)
    // -------------------------------------------------------------
    {
      double COP_heat = COP_hp_heat_1_coef1 +
                        COP_hp_heat_1_coef2 * Text_t +
                        COP_hp_heat_1_coef3 * Tsup_hp_heat;

      Elec_heat_t  = (std::min(Q_heat_new, Q_hp_heat_1) / COP_heat + std::max(Q_heat_new - Q_hp_heat_1, 0.0));
      Elec_cool_t  = Q_cool_new / COP_hp_cool;
      Elec_total_t = Elec_heat_t + Elec_cool_t;
    }

    int Comfort_t = 0;

    // -------------------------------------------------------------
    // 1.7. Comfort evaluation
    // -------------------------------------------------------------
    {
      Comfort_t = (Ti_new > comfort_low_t && Ti_new < comfort_high_t) ? 1 : 0;
    }

    // -------------------------------------------------------------
    // 1.8. Storage
    // -------------------------------------------------------------
    {
      Ti[CONT_001]         = Ti_new;
      Te[CONT_001]         = Te_new;
      Act_heat[CONT_001]   = Act_heat_new;
      Act_cool[CONT_001]   = Act_cool_new;
      Q_heat[CONT_001]     = Q_heat_new;
      Q_cool[CONT_001]     = Q_cool_new;
      Elec_heat[CONT_001]  = Elec_heat_t;
      Elec_cool[CONT_001]  = Elec_cool_t;
      Elec_total[CONT_001] = Elec_total_t;
      Comfort[CONT_001]    = Comfort_t;
    }
  }

  // -------------------------------------------------------------
  // 2. Return results
  // -------------------------------------------------------------
  return List::create(
    Named("Ti")         = Ti,
    Named("Te")         = Te,
    Named("Act_heat")   = Act_heat,
    Named("Act_cool")   = Act_cool,
    Named("Q_heat")     = Q_heat,
    Named("Q_cool")     = Q_cool,
    Named("Elec_heat")  = Elec_heat,
    Named("Elec_cool")  = Elec_cool,
    Named("Elec_total") = Elec_total,
    Named("Comfort")    = Comfort
  );
}
