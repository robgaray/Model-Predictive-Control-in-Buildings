# -------------------------------------------------------------
# Function: period_calculation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This function performs the physical simulation of the
# building for a given period based on climate data and
# setpoint values.
# This function:
#    - runs over a dataframe
#    - defines control signals for each timestep and
#    - activates heating and cooling systems accordingly
#    - computes changes to the building thermal state
#    - calculates energy costs and comfort level
# A 2C simplified model is used, with a pseudo-static approach.
# Histeresis-based thermostatic control is used for heating and
# cooling systems.
# Schedule-based ventilation is performed.
# Details of all this can be found in the readme file.
#
# This function takes and returns dataframes, but uses vectors
# internally for faster computation.
# -------------------------------------------------------------
# Inputs
#   period_chunk     : Data frame. Time series data for the simulation period.
#                      Must contain the following columns:
#                        time        - POSIXct. Simulation timestamps.
#                        SolarR      - Numeric. Solar radiation (W/m²).
#                        Text        - Numeric. External air temperature (°C).
#                        T_ext_24h   - Numeric. 24-hour running mean of external temperature (°C).
#                        Act_vent    - Integer (0/1). Ventilation activation flag.
#                        Elec_unit_cost_buy - Numeric. Electricity buy price (€/kWh or equivalent).
#                        Occupancy   - Integer (0/1). Building occupancy flag.
#                        MarketUTC   - POSIXct. Market period timestamps for setpoint lookup.
#                        Ti          - Numeric. Initial internal temperature (°C) at row 1. (Prefix applies based on context)
#                        Te          - Numeric. Initial envelope temperature (°C) at row 1. (Prefix applies based on context)
#                        Act_heat    - Integer (0/1). Initial heating activation at row 1. (Prefix applies based on context)
#                        Act_cool    - Integer (0/1). Initial cooling activation at row 1. (Prefix applies based on context)
#                      If set_point_df is NULL, must ALSO contain (with context suffix):
#                        STP_heat_low, STP_heat_high, STP_cool_low, STP_cool_high
#                      Optional columns (initialized to 0 if absent):
#                        Q_heat, Q_cool, Elec_heat, Elec_cool
#   set_point_df     : Optional Data frame (Default: NULL). Setpoint schedule with columns:
#                        period        - POSIXct. Market period timestamps.
#                        STP_heat_low  - Numeric. Lower heating threshold (°C).
#                        STP_heat_high - Numeric. Upper heating threshold (°C).
#                        STP_cool_low  - Numeric. Lower cooling threshold (°C).
#                        STP_cool_high - Numeric. Upper cooling threshold (°C).
#                      If provided, overwrites corresponding context-suffixed values in period_chunk.
#   parameters       : List. Model and reward parameters. Must include sub-lists:
#                        model_parameters  - thermal model coefficients (Ci, Ce, Rie,
#                                            Rea, Aw, Ae, heat pump coefficients, etc.)
#                        reward_parameters - reward function weights (Alpha_confort,
#                                            confort_low, confort_high).
#   calculation_mode : Integer scalar or vector. Computation mode per timestep:
#                        1 - Setpoint mode: Q_heat and Q_cool are computed from
#                            histeresis control logic.
#                        2 - Heat Input mode: Q_heat and Q_cool are read directly
#                            from period_chunk columns.
#                      If a scalar is provided, it is expanded to all timesteps.
#                      Default: 1.
#   calculation_context: Character. Determines the dataframe columns to read from/write to.
#                      Valid options: "execution" (default), "plan", "plan_flex".
#                      "execution" reads/writes base columns (e.g. Ti, Q_heat, STP_heat_low).
#                      "plan" reads/writes with "_plan" suffix (e.g. Ti_plan, STP_heat_low_plan).
#                      "plan_flex" reads/writes with "_plan_flex" suffix.
# -------------------------------------------------------------
# Outputs
#   period_chunk : Data frame. The input data frame with the following columns
#                  added or updated (depending on calculation_context):
#                    Ti         - Numeric. Internal temperature time series (°C).
#                    Te         - Numeric. Envelope temperature time series (°C).
#                    Q_heat     - Numeric. Heating energy per timestep (kWh or equivalent).
#                    Q_cool     - Numeric. Cooling energy per timestep.
#                    Elec_heat  - Numeric. Heating electricity consumption per timestep.
#                    Elec_cool  - Numeric. Cooling electricity consumption per timestep.
#                    Elec_total - Numeric. Total electricity consumption per timestep.
#                    Elec_Cost  - Numeric. Total electricity cost per timestep.
#                    Comfort    - Integer (0/1). Comfort flag per timestep.
#                    Act_heat   - Integer (0/1). Heating activation per timestep.
#                    Act_cool   - Integer (0/1). Cooling activation per timestep.
# -------------------------------------------------------------
# Code outline
# 1. Validate inputs and calculation context
# 2. Extract model parameters
# 3. Create internal vectors for fast computation
# 4. Apply setpoints from set_point_df if provided
# 5. Simulation loop: hysteresis control, thermal dynamics, energy
# 6. Write results back to data frame
# -------------------------------------------------------------
# Usage instructions
# result_df <- period_calculation(period_chunk, parameters)
# result_df <- period_calculation(period_chunk, parameters, calculation_mode = 2, calculation_context = "plan", set_point_df = sp_df)
# -------------------------------------------------------------
# Where this function/script is used
# Called by evaluate_control.R, implement_control_step.R, and fitness functions.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If period_chunk has fewer than 2 rows, the function returns the input
#     data frame unchanged (no simulation is performed).
#   - If set_point_df is NULL and suffixed setpoint columns are missing in 
#     period_chunk, an error is raised via stop().
#   - calculation_mode can be a per-timestep vector; invalid values (not 1 or 2)
#     raise an error via stop(). A length mismatch with the number of timesteps
#     also raises an error.
#   - Invalid calculation_context value will raise an error via stop().
#   - If a MarketUTC value in period_chunk has no matching 'period' entry in
#     set_point_df, the function raises an error via stop().
#   - Heating and cooling are mutually exclusive: if heating is active, cooling
#     is forced off regardless of the temperature relative to the cooling setpoint.
#   - Setpoints are applied using hysteresis: heating activates when Ti drops
#     below STP_heat_low and deactivates when Ti rises above STP_heat_high;
#     cooling applies the same logic with STP_cool_low and STP_cool_high.
#   - Optional columns Q_heat, Q_cool, Elec_heat, Elec_cool are initialized
#     to 0 if absent from period_chunk; NA values in these columns are also
#     treated as 0.
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
period_calculation <- function(period_chunk,
                               parameters,
                               calculation_mode = 1,
                               calculation_context = "execution",
                               set_point_df = NULL) {
  # Validations
  {
    # Validate calculation_context
    if (!calculation_context %in% c("execution", "plan", "plan_flex")) {
      stop("Invalid calculation_context. Must be 'execution', 'plan', or 'plan_flex'.")
    }
    
    # Ensure that there is actually something to simulate (2 or more rows)
    # otherwise, end.
    if (nrow(period_chunk) < 2) return(period_chunk)
    
    # Handle calculation_mode: expand scalar to vector if needed
    {
      # calculation_mode: 1 = Setpoint, 2 = Heat Input
      # Each timestep can have a different value
      if (length(calculation_mode) == 1) {
        calculation_mode_vec <- rep(calculation_mode, nrow(period_chunk))
      } else {
        calculation_mode_vec <- calculation_mode
      }
    }
    
    # Validate all calculation_mode values in the vector
    invalid_vals <- unique(calculation_mode_vec[!(calculation_mode_vec %in% c(1, 2))])
    if (length(invalid_vals) > 0) {
      stop("Invalid calculation_mode value(s): ", paste(invalid_vals, collapse = ", "),
           ". Must be 1 (Setpoint) or 2 (Heat Input).")
    }
    
    # Validate vector length matches number of timesteps
    if (length(calculation_mode_vec) != nrow(period_chunk)) {
      stop("calculation_mode vector length (", length(calculation_mode_vec),
           ") does not match number of timesteps (", nrow(period_chunk), ").")
    }
  }
  
  # Determine column suffix based on context
  col_sfx <- switch(calculation_context,
                    "execution" = "",
                    "plan"      = "_plan",
                    "plan_flex" = "_plan_flex")
  
  n <- nrow(period_chunk)
  
  # Extract model parameters one by one
  {
    Ci                  <- parameters$model$Ci
    Ce                  <- parameters$model$Ce
    Rie                 <- parameters$model$Rie
    Rea                 <- parameters$model$Rea
    Aw                  <- parameters$model$Aw
    Ae                  <- parameters$model$Ae
    Shading_0           <- parameters$model$Shading_0
    Shading_1           <- parameters$model$Shading_1
    Setpoint_Shading1   <- parameters$model$Setpoint_Shading1
    AT_hp_heat_1        <- parameters$model$AT_hp_heat_1
    AT_hp_heat_2        <- parameters$model$AT_hp_heat_2
    Q_hp_heat_1         <- parameters$model$Q_hp_heat_1
    Q_hp_heat_2         <- parameters$model$Q_hp_heat_2
    COP_hp_heat_1_coef1 <- parameters$model$COP_hp_heat_1_coef1
    COP_hp_heat_1_coef2 <- parameters$model$COP_hp_heat_1_coef2
    COP_hp_heat_1_coef3 <- parameters$model$COP_hp_heat_1_coef3
    Tsup_hp_heat        <- parameters$model$Tsup_hp_heat
    Q_hp_cool           <- parameters$model$Q_hp_cool
    COP_hp_cool         <- parameters$model$COP_hp_cool
    Rvent01             <- parameters$model$Rvent01
    Rvent1              <- parameters$model$Rvent1
    Rvent2              <- parameters$model$Rvent2
    Setpoint_Rvent1     <- parameters$model$Setpoint_Rvent1
    confort_low         <- parameters$reward$confort_low
    confort_high        <- parameters$reward$confort_high
  }
  
  # Create vectors for faster operation
  {
    # Invariable vectors selected by calculation_context
    {
      if (calculation_context == "execution") {
        SolarR <- period_chunk$SolarR
        Text   <- period_chunk$Text
      } else {
        # Use forecast columns for plan or plan_flex
        SolarR <- period_chunk$SolarR_forec
        Text   <- period_chunk$Text_forec
      }	   
      
      Act_vent      <- period_chunk$Act_vent
      T_ext_24h     <- period_chunk$T_ext_24h
      Elec_price    <- period_chunk$Elec_unit_cost_buy
      Occupancy     <- period_chunk$Occupancy
      time          <- period_chunk$time
      MarketUTC     <- period_chunk$MarketUTC
    }
    
    # variable vectors (empty or initialized from period_chunk)
    {
      Ti            <- rep(NA_real_, n) 
      Te            <- rep(NA_real_, n)
      Act_heat      <- rep(NA_integer_, n)
      Act_cool      <- rep(NA_integer_, n)
      
      # Determine specific column names based on calculation_context
      col_Q_heat    <- paste0("Q_heat", col_sfx)
      col_Q_cool    <- paste0("Q_cool", col_sfx)
      col_Elec_heat <- paste0("Elec_heat", col_sfx)
      col_Elec_cool <- paste0("Elec_cool", col_sfx)
      
      # Initialize Q_heat, Q_cool, Elec_heat, Elec_cool from period_chunk if available
      # Convert NA or 0 values to 0
      
      # Look for Q_heat context column
      if (col_Q_heat %in% names(period_chunk)) {
        Q_heat <- period_chunk[[col_Q_heat]]
      } else {
        Q_heat <- rep(0, n)
      }
      Q_heat[is.na(Q_heat)] <- 0
      
      # Look for Q_cool context column
      if (col_Q_cool %in% names(period_chunk)) {
        Q_cool <- period_chunk[[col_Q_cool]]
      } else {
        Q_cool <- rep(0, n)
      }
      Q_cool[is.na(Q_cool)] <- 0
      
      # Look for Elec_heat context column
      if (col_Elec_heat %in% names(period_chunk)) {
        Elec_heat <- period_chunk[[col_Elec_heat]]
      } else {
        Elec_heat <- rep(0, n)
      }
      Elec_heat[is.na(Elec_heat)] <- 0
      
      # Look for Elec_cool context column
      if (col_Elec_cool %in% names(period_chunk)) {
        Elec_cool <- period_chunk[[col_Elec_cool]]
      } else {
        Elec_cool <- rep(0, n)
      }
      Elec_cool[is.na(Elec_cool)] <- 0
      
      Elec_total  <- rep(0, n)
      Elec_Cost   <- rep(0, n)
      Comfort     <- rep(0, n)
    }
    
    # initialization
    {
      col_Ti       <- paste0("Ti", col_sfx)
      col_Te       <- paste0("Te", col_sfx)
      col_Act_heat <- paste0("Act_heat", col_sfx)
      col_Act_cool <- paste0("Act_cool", col_sfx)
      
      Ti[1]        <- period_chunk[[col_Ti]][1]
      Te[1]        <- period_chunk[[col_Te]][1]
      Act_heat[1]  <- period_chunk[[col_Act_heat]][1]
      Act_cool[1]  <- period_chunk[[col_Act_cool]][1]
    }
  }
  
  # setpoints
  {
    # Determine specific column names based on calculation_context
    col_STP_heat_low  <- paste0("STP_heat_low", col_sfx)
    col_STP_heat_high <- paste0("STP_heat_high", col_sfx)
    col_STP_cool_low  <- paste0("STP_cool_low", col_sfx)
    col_STP_cool_high <- paste0("STP_cool_high", col_sfx)
    
    # Special logic for execution: Copy plan setpoints to current context columns
    if (calculation_context == "execution") {
      period_chunk[[col_STP_heat_low]]  <- period_chunk$STP_heat_low_plan
      period_chunk[[col_STP_heat_high]] <- period_chunk$STP_heat_high_plan
      period_chunk[[col_STP_cool_low]]  <- period_chunk$STP_cool_low_plan
      period_chunk[[col_STP_cool_high]] <- period_chunk$STP_cool_high_plan
    }
    
    if (!is.null(set_point_df)) {
      # Populate setpoints from the provided dataframe
      for (CONT_001 in 2:n) {
        date_period <- MarketUTC[CONT_001]
        idx <- which(set_point_df$period == date_period)
        
        if (length(idx) == 0) {
          stop("Setpoint not found for MarketUTC in row ", CONT_001)
        }
        
        period_chunk[[col_STP_heat_low]][CONT_001]  <- set_point_df$STP_heat_low[idx]
        period_chunk[[col_STP_heat_high]][CONT_001] <- set_point_df$STP_heat_high[idx]
        period_chunk[[col_STP_cool_low]][CONT_001]  <- set_point_df$STP_cool_low[idx]
        period_chunk[[col_STP_cool_high]][CONT_001] <- set_point_df$STP_cool_high[idx]
      }
    } else {
      # Fallback: check that the required context-specific columns exist in period_chunk
      req_stp_cols <- c(col_STP_heat_low, col_STP_heat_high, col_STP_cool_low, col_STP_cool_high)
      missing_cols <- req_stp_cols[!req_stp_cols %in% names(period_chunk)]
      if (length(missing_cols) > 0) {
        stop("set_point_df is NULL, but period_chunk is missing setpoint columns: ", paste(missing_cols, collapse = ", "))
      }
    }
    
    # Create vectors for easy access
    {
      STP_heat_low  <- period_chunk[[col_STP_heat_low]]
      STP_heat_high <- period_chunk[[col_STP_heat_high]]
      STP_cool_low  <- period_chunk[[col_STP_cool_low]]
      STP_cool_high <- period_chunk[[col_STP_cool_high]]
    }
  }
  
  # Simulation loop
  for (CONT_002 in 2:n) {
    # previous values
    {
      Ti_prev       <- Ti[CONT_002-1]
      Te_prev       <- Te[CONT_002-1]
      Act_heat_prev <- Act_heat[CONT_002-1]
      Act_cool_prev <- Act_cool[CONT_002-1]
    }
    
    # current values
    {
      SolarR_t                <- SolarR[CONT_002]
      Act_vent_t              <- Act_vent[CONT_002]
      Text_t                  <- Text[CONT_002]
      STP_heat_low_t          <- STP_heat_low[CONT_002]
      STP_heat_high_t         <- STP_heat_high[CONT_002]
      STP_cool_low_t          <- STP_cool_low[CONT_002]
      STP_cool_high_t         <- STP_cool_high[CONT_002]
      T_ext_24h_t             <- T_ext_24h[CONT_002]
      Elec_price_t            <- Elec_price[CONT_002]
      Occupancy_t             <- Occupancy[CONT_002]
    }
    
    # delta time (minutes)
    delta_t <- as.numeric(time[CONT_002] - time[CONT_002-1]) / 60
    
    # Heating and Cooling control
    {
      # Act_heat calculation (histeresis)
      if (Ti_prev < STP_heat_low_t) {
        Act_heat_new <- 1L
      } else if (Ti_prev > STP_heat_high_t) {
        Act_heat_new <- 0L
      } else {
        Act_heat_new <- Act_heat_prev
      }
      
      # Act_cool calculation (histeresis)
      # Depends on Act_heat_new to avoid double activation
      if (Act_heat_new == 1L) {
        Act_cool_new <- 0L
      } else if (Ti_prev > STP_cool_high_t) {
        Act_cool_new <- 1L
      } else if (Ti_prev < STP_cool_low_t) {
        Act_cool_new <- 0L
      } else {
        Act_cool_new <- Act_cool_prev
      }
      rm(Act_heat_prev, Act_cool_prev)
    }
    
    # Heating and Cooling energy
    # Check calculation_mode at current timestep
    {
      calculation_mode_t <- calculation_mode_vec[CONT_002]
      
      if (calculation_mode_t == 1) {
        # Setpoint mode: calculate Q_heat and Q_cool based on setpoints
        # Q_heat calculation (piecewise)
        Delta_temp_h <- STP_heat_high_t - Ti_prev
        if (Act_heat_new == 1L) {
          if (Delta_temp_h < AT_hp_heat_1) {
            Q_heat_new <- Q_hp_heat_1
          } else if (Delta_temp_h > AT_hp_heat_2) {
            Q_heat_new <- Q_hp_heat_2
          } else {
            Q_heat_new <- Q_hp_heat_1 + 
              (Q_hp_heat_2 - Q_hp_heat_1) * (Delta_temp_h - AT_hp_heat_1) / (AT_hp_heat_2 - AT_hp_heat_1)
          }
        } else {
          Q_heat_new <- 0
        }
        rm(Delta_temp_h)
        
        # Q_cool calculation
        if (Act_cool_new == 1L) {
          Q_cool_new <- Q_hp_cool
        } else {
          Q_cool_new <- 0
        }
      } else if (calculation_mode_t == 2) {
        # Heat Input mode: get Q_heat and Q_cool directly from period_chunk
        # Divides by delta_t to avoid unit problems since
        # the rest of the calculations expect power (kW or equivalent)
        # rather than energy (kWh or equivalent)
        Q_heat_new <- Q_heat[CONT_002] / delta_t
        Q_cool_new <- Q_cool[CONT_002] / delta_t
      }
      rm(calculation_mode_t)
    }
    
    # Ventilation and Shading
    {
      # Rvent calculation
      if (Act_vent_t == 1) {
        Rvent_t <- Rvent2
      } else if (!is.na(T_ext_24h_t) && T_ext_24h_t >= Setpoint_Rvent1) {
        Rvent_t <- Rvent1
      } else {
        Rvent_t <- Rvent01
      }
      
      # Shading
      Shading_t <- ifelse(!is.na(T_ext_24h_t) && T_ext_24h_t > Setpoint_Shading1, Shading_1, Shading_0)
    }
    
    # Internal temperature calculations
    {
      Ti_new <- Ti_prev + 
        ((Te_prev - Ti_prev) / Rie + 
           (Text_t - Ti_prev) / Rvent_t + 
           (Aw * SolarR_t * Shading_t / 1000) + 
           (Q_heat_new - Q_cool_new)) * (1 / Ci) * delta_t
      Te_new <- Te_prev + 
        ((Ti_prev - Te_prev) / Rie + 
           (Text_t - Te_prev) / Rea + 
           (Ae * SolarR_t / 1000)) * (1 / Ce) * delta_t
      rm(Ti_prev, Te_prev, Rvent_t, Shading_t)
    }
    
    # Heat pump power to energy conversion for proper storage
    {
      Q_heat_new <- Q_heat_new * delta_t
      Q_cool_new <- Q_cool_new * delta_t
    }
    
    # Electricity calculations
    {
      # COP for heating
      COP_heat <- COP_hp_heat_1_coef1 + 
        COP_hp_heat_1_coef2 * Text_t + 
        COP_hp_heat_1_coef3 * Tsup_hp_heat
      
      # Electricity cost
      Elec_heat_t <- (min(Q_heat_new, Q_hp_heat_1) / COP_heat + max(Q_heat_new - Q_hp_heat_1, 0))
      rm(COP_heat)
      Elec_cool_t <- (Q_cool_new / COP_hp_cool) * delta_t
      Elec_total_t   <- Elec_heat_t + Elec_cool_t
      Elec_Cost_t    <- Elec_total_t * Elec_price_t
      rm(Elec_price_t)
    }
    
    # Comfort
    {
      Comfort_t <- ifelse(Ti_new > confort_low & Ti_new < confort_high, 1, 0)
      rm(Occupancy_t, delta_t)
    }
    
    # Assign results to vectors
    {
      Ti[CONT_002]               <- Ti_new
      Te[CONT_002]               <- Te_new
      Act_heat[CONT_002]         <- Act_heat_new
      Act_cool[CONT_002]         <- Act_cool_new
      Q_heat[CONT_002]           <- Q_heat_new
      Q_cool[CONT_002]           <- Q_cool_new
      Elec_heat[CONT_002]        <- Elec_heat_t
      Elec_cool[CONT_002]        <- Elec_cool_t
      Elec_total[CONT_002]       <- Elec_total_t
      Elec_Cost[CONT_002]        <- Elec_Cost_t
      Comfort[CONT_002]          <- Comfort_t
      rm(Ti_new, Te_new, Act_heat_new, Act_cool_new, Q_heat_new, Q_cool_new,
         SolarR_t, Act_vent_t, Text_t,
         STP_heat_low_t, STP_heat_high_t, STP_cool_low_t, STP_cool_high_t, T_ext_24h_t,
         Elec_heat_t, Elec_cool_t, Elec_total_t, Elec_Cost_t, Comfort_t)
    }
    
  }
  
  # Write back to data frame
  {
    period_chunk[[paste0("Ti", col_sfx)]]         <- Ti
    period_chunk[[paste0("Te", col_sfx)]]         <- Te
    period_chunk[[paste0("Q_heat", col_sfx)]]     <- Q_heat
    period_chunk[[paste0("Q_cool", col_sfx)]]     <- Q_cool
    period_chunk[[paste0("Elec_heat", col_sfx)]]  <- Elec_heat
    period_chunk[[paste0("Elec_cool", col_sfx)]]  <- Elec_cool
    period_chunk[[paste0("Elec_total", col_sfx)]] <- Elec_total
    period_chunk[[paste0("Elec_Cost", col_sfx)]]  <- Elec_Cost
    period_chunk[[paste0("Comfort", col_sfx)]]    <- Comfort
    period_chunk[[paste0("Act_heat", col_sfx)]]   <- Act_heat
    period_chunk[[paste0("Act_cool", col_sfx)]]   <- Act_cool
    
    # Write back the setpoints used for the calculation
    period_chunk[[col_STP_heat_low]]  <- STP_heat_low
    period_chunk[[col_STP_heat_high]] <- STP_heat_high
    period_chunk[[col_STP_cool_low]]  <- STP_cool_low
    period_chunk[[col_STP_cool_high]] <- STP_cool_high
  }
  
  return(period_chunk)
}