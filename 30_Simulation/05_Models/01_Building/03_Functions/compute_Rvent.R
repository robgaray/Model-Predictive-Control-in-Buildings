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
# equivalent resistances for the heat recovery mode (RventXX_HR).
# -------------------------------------------------------------
# Inputs
#   model_parameters    : Named list. Must include:
#                           RENvent01    - Infiltration ACH rate (1/h),
#                                          unoccupied and T_ext_24h below
#                                          Setpoint_Rvent1
#                           RENvent1     - Reinforced ventilation ACH rate
#                                          (1/h), unoccupied and T_ext_24h
#                                          at or above Setpoint_Rvent1
#                           RENvent2     - Occupied ventilation ACH rate
#                                          (1/h)
#                           Efi_Vent_Rec - Heat recovery efficiency (0-1)
#                           Volume       - Building volume (m3)
#   physical_properties : Named list. Must include:
#                           Cp_air   - Specific heat of air (kJ/(kg·K))
#                           dens_air - Density of air (kg/m3)
# -------------------------------------------------------------
# Outputs
#   model_parameters : Named list. The input list extended with:
#                        Rvent01    - Thermal resistance, infiltration (K/kW)
#                        Rvent1     - Thermal resistance, reinforced
#                                     ventilation (K/kW)
#                        Rvent2     - Thermal resistance, occupied
#                                     ventilation (K/kW)
#                        Rvent01_HR - Rvent01 with heat recovery (K/kW)
#                        Rvent1_HR  - Rvent1 with heat recovery (K/kW)
#                        Rvent2_HR  - Rvent2 with heat recovery (K/kW)
#                      The building simulation reads Rvent01, Rvent1,
#                      Rvent2 and Rvent2_HR: heat recovery only runs
#                      with the occupied ventilation.
#                      A rate of 0, or a recovery efficiency of 1,
#                      gives an infinite resistance (Inf): no
#                      ventilation at all.
# -------------------------------------------------------------
# Code outline
# 1. Extract conversion constants from physical_properties
# 2. Compute RventXX for each ACH rate
# 3. Compute RventXX_HR using heat recovery efficiency
# -------------------------------------------------------------
# Usage instructions
# model_parameters <- compute_Rvent(model_parameters, physical_properties)
# -------------------------------------------------------------

compute_Rvent <- function(model_parameters,
                          physical_properties) {

  # -------------------------------------------------------------
  # 1. Extract conversion constants from physical_properties
  # Thermal ventilation resistance Rvent (K/kW) is derived from the
  # Air Change rate (ACH, 1/h) using:
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
  # Zero ACH gives an infinite resistance (Inf), so the ventilation
  # term of the simulation, (Text - Ti) / Rvent, is exactly 0.
  # -------------------------------------------------------------
  {
    RENvent_params <- c("RENvent01", "RENvent1", "RENvent2")
    Rvent_names    <- c("Rvent01",   "Rvent1",   "Rvent2")

    for (CONT_001 in seq_along(RENvent_params)) {
      ren_val <- model_parameters[[RENvent_params[CONT_001]]]

      if (!is.null(ren_val) && !is.na(ren_val) && ren_val > 0) {
        model_parameters[[Rvent_names[CONT_001]]] <- 3600 / (ren_val * conversion_factor)
      } else {
        model_parameters[[Rvent_names[CONT_001]]] <- Inf
      }
    }

    rm(list = c("RENvent_params", "Rvent_names", "CONT_001", "ren_val"))
  }

  # -------------------------------------------------------------
  # 3. Compute RventXX_HR using heat recovery efficiency
  # RventXX_HR = RventXX / (1 - Efi_Vent_Rec)
  # Heat recovery increases effective thermal resistance.
  # If Efi_Vent_Rec = 1 (perfect recovery), the resistance is
  # infinite (Inf), and the ventilation term is exactly 0.
  # -------------------------------------------------------------
  {
    HR_factor <- 1 - Efi_Vent_Rec

    Rvent_base_names <- c("Rvent01", "Rvent1", "Rvent2")
    Rvent_HR_names   <- c("Rvent01_HR", "Rvent1_HR", "Rvent2_HR")

    for (CONT_002 in seq_along(Rvent_base_names)) {
      base_val <- model_parameters[[Rvent_base_names[CONT_002]]]

      if (!is.null(base_val) && !is.na(base_val) && HR_factor > 0) {
        model_parameters[[Rvent_HR_names[CONT_002]]] <- base_val / HR_factor
      } else {
        model_parameters[[Rvent_HR_names[CONT_002]]] <- Inf
      }
    }

    rm(list = c("Rvent_base_names", "Rvent_HR_names", "CONT_002", "base_val",
                "HR_factor", "Volume", "Cp_air", "dens_air", "Efi_Vent_Rec",
                "conversion_factor"))
  }

  return(model_parameters)
}
