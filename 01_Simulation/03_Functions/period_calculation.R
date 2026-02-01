# -------------------------------------------------------------
# Function: period_calculation.R
# Part of the Model Predictive Control in buildings repository
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function performs the physical simulation of the
# building for a given period based on climate data and
# sepoint values.
# This scripts:
#    - runs over a dataframe
#    - defines control signals for each timestep and 
#    - activates heating and cooling systems accordingly
#    - computes changes to the building
#    - calculates energy costs, confort level, and the overall
#      reward function
# A 2C simplified model is used, with a pseudo-static approach.
# Histeresis-based thermostatic control is used for heating and
# cooling systems
# schedule-based ventilation is performed.
# Details of all this can be found in the readme file.
#
# This function takes and returns dataframes, but uses vectors
# internally for faster computation.
# -------------------------------------------------------------
period_calculation <- function(period_chunk,
                                  set_point_df,
                                  parameters) {
  with(parameters,{
    
    # Ensure that there is actually something to simulate (2 or more rows)
    # otherwise, end.
    if (nrow(period_chunk) < 2) return(period_chunk)
    
    n <- nrow(period_chunk)
    
    # Create vectors for faster operation
    {
      # invariable vectors
      {
        solar_radiation               <- period_chunk$solar_radiation
        act_vent          <- period_chunk$act_vent
        external_temperature   <- period_chunk$external_temperature
        mean_temp_24h     <- period_chunk$mean_temp_24h
        electricity_cost      <- period_chunk$electricity_cost
        building_occupied <- period_chunk$building_occupied
        time              <- period_chunk$time
        MarketUTC         <- period_chunk$MarketUTC
      }
      
      # variable vectors (empty)
      {
        Ti                <- rep(NA_real_, n) 
        Te                <- rep(NA_real_, n)
        act_heat          <- rep(NA_integer_, n)
        act_cool          <- rep(NA_integer_, n)
        Qh                <- rep(0, n)
        Qc                <- rep(0, n)
        elec_heating      <- rep(0, n)
        elec_cooling      <- rep(0, n)
        elec_total        <- rep(0, n)
        elec_cost         <- rep(0, n)
        building_comfort  <- rep(0, n)
        reward            <- rep(0, n)
      }
      
      # initialization
      {
        Ti[1]             <- period_chunk$Ti[1]
        Te[1]             <- period_chunk$Te[1]
        act_heat[1]       <- period_chunk$act_heat[1]
        act_cool[1]       <- period_chunk$act_cool[1]
      }
    }
    
    # setpoints
    {
      # If signals are not already in the dataframe, create this
      {
        if (!"set_point_heating_low" %in% names(period_chunk)) period_chunk$set_point_heating_low <- NA_real_
        if (!"set_point_heating_high" %in% names(period_chunk)) period_chunk$set_point_heating_high <- NA_real_
        if (!"set_point_cooling_low" %in% names(period_chunk)) period_chunk$set_point_cooling_low <- NA_real_
        if (!"set_point_cooling_high" %in% names(period_chunk)) period_chunk$set_point_cooling_high <- NA_real_
      }
      
      # Assign setpoints (defined for each Market period) to each timestep
      # Timesteps (step) are physical simulation timesteps in period_chunk (about 5')
      # Market periods (idx) are market price variation periods defined in set_point_df (commonly 15' or 1h)
      {
        for (step in 2:n) {
          date_period <- MarketUTC[step]
          idx <- which(set_point_df$period == date_period)
          if (length(idx) == 0) {
            stop("Setpoint not found for MarketUTC = ", as.character(date_period), " in row ", step)
          }
          
          period_chunk$set_point_heating_low[step]  <- set_point_df$set_point_heating_low[idx]
          period_chunk$set_point_heating_high[step] <- set_point_df$set_point_heating_high[idx]
          period_chunk$set_point_cooling_low[step]  <- set_point_df$set_point_cooling_low[idx]
          period_chunk$set_point_cooling_high[step] <- set_point_df$set_point_cooling_high[idx]
        }
      }
      
      # Create vectors for easy access
      {
        set_point_heating_low  <- period_chunk$set_point_heating_low
        set_point_heating_high <- period_chunk$set_point_heating_high
        set_point_cooling_low  <- period_chunk$set_point_cooling_low
        set_point_cooling_high <- period_chunk$set_point_cooling_high
      }
    }
    
    # Simulation loop
    for (step in 2:n) {
      # previous values
      {
        Ti_prev       <- Ti[step-1]
        Te_prev       <- Te[step-1]
        act_heat_prev <- act_heat[step-1]
        act_cool_prev <- act_cool[step-1]
      }
      
      # current values
      {
        solar_radiation_t                    <- solar_radiation[step]
        act_vent_t               <- act_vent[step]
        external_temperature_t        <- external_temperature[step]
        set_point_heating_low_t  <- set_point_heating_low[step]
        set_point_heating_high_t <- set_point_heating_high[step]
        set_point_cooling_low_t  <- set_point_cooling_low[step]
        set_point_cooling_high_t <- set_point_cooling_high[step]
        mean_temp_24h_t          <- mean_temp_24h[step]
        electricity_cost_t           <- electricity_cost[step]
        building_occupied_t      <- building_occupied[step]
      }
      
      # delta time (minutes)
      delta_t <- as.numeric(time[step] - time[step-1]) / 60
      
      # Heating and Cooling control
      {
        # Act_heat calculation (histeresis)
        if (Ti_prev < set_point_heating_low_t) {
          act_heat_new <- 1L
        } else if (Ti_prev > set_point_heating_high_t) {
          act_heat_new <- 0L
        } else {
          act_heat_new <- act_heat_prev
        }
        
        # Act_cool calculation (histeresis)
        # Depends on act_heat_new to avoid double activation
        if (act_heat_new == 1L) {
          act_cool_new <- 0L
        } else if (Ti_prev > set_point_cooling_high_t) {
          act_cool_new <- 1L
        } else if (Ti_prev < set_point_cooling_low_t) {
          act_cool_new <- 0L
        } else {
          act_cool_new <- act_cool_prev
        }
      }
      
      # Heating and Cooling energy
      {
        # Qh calculation (piecewise)
        Delta_temp_h <- set_point_heating_high_t - Ti_prev
        if (act_heat_new == 1L) {
          if (Delta_temp_h < AT_hp_heat_1) {
            Qh_new <- Q_hp_heat_1
          } else if (Delta_temp_h > AT_hp_heat_2) {
            Qh_new <- Q_hp_heat_2
          } else {
            Qh_new <- Q_hp_heat_1 +
              (Q_hp_heat_2 - Q_hp_heat_1) * (Delta_temp_h - AT_hp_heat_1) / (AT_hp_heat_2 - AT_hp_heat_1)
          }
        } else {
          Qh_new <- 0
        }
        
        # Qc calculation
        if (act_cool_new == 1L) {
          Qc_new <- Q_hp_cool
        } else {
          Qc_new <- 0
        }
      }
      
      # Ventilation and Shading
      {
        # Rvent calculation
        if (act_vent_t == 1) {
          Rvent_t <- Rvent2
        } else if (!is.na(mean_temp_24h_t) && mean_temp_24h_t >= Setpoint_Rvent1) {
          Rvent_t <- Rvent1
        } else {
          Rvent_t <- Rvent01
        }
        
        # Shading
        Shading_t <- ifelse(!is.na(mean_temp_24h_t) && mean_temp_24h_t > Setpoint_Shading1, Shading_1, Shading_0)
      }
            
      # Internal temperature calculations
      {
        Ti_new <- Ti_prev +
          ((Te_prev - Ti_prev) / Rie +
             (external_temperature_t - Ti_prev) / Rvent_t +
             (Aw * solar_radiation_t * Shading_t / 1000) +
             (Qh_new - Qc_new)) * (1 / Ci) * delta_t
        Te_new <- Te_prev +
          ((Ti_prev - Te_prev) / Rie +
             (external_temperature_t - Te_prev) / Rea +
             (Ae * solar_radiation_t / 1000)) * (1 / Ce) * delta_t
      }
      
      # Electricity calculations
      {
        # COP for heating
        COP_heat <- COP_hp_heat_1_coef1 +
          COP_hp_heat_1_coef2 * external_temperature_t +
          COP_hp_heat_1_coef3 * Tsup_hp_heat
        
        # Electricity cost
        elec_heating_t <- (min(Qh_new, Q_hp_heat_1) / COP_heat + max(Qh_new - Q_hp_heat_1, 0)) * delta_t
        elec_cooling_t <- (Qc_new / COP_hp_cool) * delta_t
        elec_total_t   <- elec_heating_t + elec_cooling_t
        elec_cost_t    <- elec_total_t * electricity_cost_t
      }
            
      # Comfort and reward
      {
        comfort_t <- ifelse(Ti_new > confort_low & Ti_new < confort_high, 1, 0)
        reward_t <- reward_function(building_occupied_t,
                                    elec_cost_t,
                                    comfort_t,
                                    delta_t,
                                    parameters)
      }
      
      # Assign results to vectors
      {
        Ti[step]               <- Ti_new
        Te[step]               <- Te_new
        act_heat[step]         <- act_heat_new
        act_cool[step]         <- act_cool_new
        Qh[step]               <- Qh_new
        Qc[step]               <- Qc_new
        elec_heating[step]     <- elec_heating_t
        elec_cooling[step]     <- elec_cooling_t
        elec_total[step]       <- elec_total_t
        elec_cost[step]        <- elec_cost_t
        building_comfort[step] <- comfort_t
        reward[step]           <- reward_t
      }
      
    }
    
    # Write back to data frame
    {
      period_chunk$Ti               <- Ti
      period_chunk$Te               <- Te
      period_chunk$Qh               <- Qh
      period_chunk$Qc               <- Qc
      period_chunk$elec_heating     <- elec_heating
      period_chunk$elec_cooling     <- elec_cooling
      period_chunk$elec_total       <- elec_total
      period_chunk$elec_cost        <- elec_cost
      period_chunk$building_comfort <- building_comfort
      period_chunk$act_heat         <- act_heat
      period_chunk$act_cool         <- act_cool
      period_chunk$reward           <- reward
    }
    
    return(period_chunk)
  })
}