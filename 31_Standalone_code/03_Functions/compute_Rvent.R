# -------------------------------------------------------------
# Function: compute_Rvent.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function converts Air Change per Hour (ACH) ventilation
# rates (RENventXX) into thermal ventilation resistances (RventXX)
# used by the building simulation model. It also computes the
# equivalent resistance of the day ventilation in heat recovery mode
# (Rvent2_HR).
# -------------------------------------------------------------
# Inputs
#   model_parameters    : Named list. Must include:
#                           RENvent01    - Infiltration ACH rate (h-1)
#                           RENvent1     - Night ventilation ACH rate (h-1)
#                           RENvent2     - Day ventilation ACH rate (h-1)
#                           Efi_Vent_Rec - Heat recovery efficiency (0-1)
#                           Volume       - Building volume (m3)
#   physical_properties : Named list. Must include:
#                           Cp_air   - Specific heat of air (kJ/(kg·K))
#                           dens_air - Density of air (kg/m3)
# -------------------------------------------------------------
# Outputs
#   model_parameters : Named list. The input list extended with:
#                        Rvent01    - Thermal resistance, infiltration (K/kW)
#                        Rvent1     - Thermal resistance, night vent (K/kW)
#                        Rvent2     - Thermal resistance, day vent (K/kW)
#                        Rvent2_HR  - Rvent2 with heat recovery (K/kW)
# -------------------------------------------------------------
# Code outline
# 1. Extract conversion constants from physical_properties
# 2. Compute RventXX for each ACH rate
# 3. Compute Rvent2_HR using heat recovery efficiency
# -------------------------------------------------------------
# Usage instructions
# model_parameters <- compute_Rvent(model_parameters, physical_properties)
# -------------------------------------------------------------
# Where this function/script is used
#   - load_parameters()
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------

compute_Rvent <- function(model_parameters,
                          physical_properties) {

  # -------------------------------------------------------------
  # 1. Extract conversion constants from physical_properties
  # Thermal ventilation resistance Rvent (K/kW) is derived from the
  # Air Change rate (ACH, h-1) using:
  #   Rvent = 3600 / (ACH * Volume * dens_air * Cp_air)
  # where:
  #   Volume   [m3]       - building volume
  #   dens_air [kg/m3]    - air density
  #   Cp_air   [kJ/kg·K]  - specific heat of air
  #   3600     [s/h]      - conversion factor (ACH is per hour)
  #   Result: Rvent in [K/kW]
  # -------------------------------------------------------------
  {
    Volume       <- model_parameters$Volume
    Cp_air       <- physical_properties$Cp_air
    dens_air     <- physical_properties$dens_air
    Efi_Vent_Rec <- model_parameters$Efi_Vent_Rec

    conversion_factor <- Volume * dens_air * Cp_air
  }

  # -------------------------------------------------------------
  # 2. Compute RventXX for each ACH rate
  # Zero ACH gives infinite resistance; set to a very large value
  # to represent no ventilation (avoiding division by zero).
  # -------------------------------------------------------------
  {
    RENvent_params <- c("RENvent01", "RENvent1", "RENvent2")
    Rvent_names    <- c("Rvent01",   "Rvent1",   "Rvent2")

    for (CONT_001 in seq_along(RENvent_params)) {
      ren_val <- model_parameters[[RENvent_params[CONT_001]]]

      if (!is.null(ren_val) && !is.na(ren_val) && ren_val > 0) {
        model_parameters[[Rvent_names[CONT_001]]] <- 3600 / (ren_val * conversion_factor)
      } else {
        model_parameters[[Rvent_names[CONT_001]]] <- 1e6
      }
    }

    rm(RENvent_params, Rvent_names, CONT_001, ren_val)
  }

  # -------------------------------------------------------------
  # 3. Compute Rvent2_HR using heat recovery efficiency
  # Rvent2_HR = Rvent2 / (1 - Efi_Vent_Rec)
  # Heat recovery increases effective thermal resistance.
  # If Efi_Vent_Rec = 1 (perfect recovery), resistance is infinite.
  # The building physics (period_simulation_cpp()) only applies heat
  # recovery to the day ventilation, so only Rvent2 has a heat recovery
  # counterpart.
  # -------------------------------------------------------------
  {
    HR_factor <- 1 - Efi_Vent_Rec

    if (HR_factor > 0) {
      model_parameters$Rvent2_HR <- model_parameters$Rvent2 / HR_factor
    } else {
      model_parameters$Rvent2_HR <- 1e6
    }

    rm(HR_factor, Volume, Cp_air, dens_air, Efi_Vent_Rec,
       conversion_factor)
  }

  return(model_parameters)
}
