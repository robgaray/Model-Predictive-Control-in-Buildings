# -------------------------------------------------------------
# Function: period_calculation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
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
#    - calculates comfort level
# This function performs no economic calculation (see EXCEPTIONS below):
# Elec_Cost is resolved elsewhere, through reward_function() for "plan"/
# "plan_flex" and through calc_differential_cost() for "execution".
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
#                        Occupancy   - Integer (0/1). Building occupancy flag.
#                        MarketUTC   - POSIXct. Market period timestamps for setpoint lookup.
#                        Ti          - Numeric. Initial internal temperature (°C) at row 1. (Prefix applies based on context)
#                        Te          - Numeric. Initial envelope temperature (°C) at row 1. (Prefix applies based on context)
#                        Act_heat    - Integer (0/1). Initial heating activation at row 1. (Prefix applies based on context)
#                        Act_cool    - Integer (0/1). Initial cooling activation at row 1. (Prefix applies based on context)
#                        Service_T_Low, Service_T_High     - Numeric. Comfort
#                                    band, required when calculation_context is
#                                    "execution".
#                        Scheduling_T_Low, Scheduling_T_High - Numeric. Comfort
#                                    band, required when calculation_context is
#                                    "plan" or "plan_flex".
#                      If set_point_df is NULL, must ALSO contain (with context suffix):
#                        STP_heat_low, STP_heat_high, STP_cool_low, STP_cool_high
#                      Optional columns (carried over from period_chunk if
#                      present, NA treated as 0, initialized to 0 if absent):
#                        Q_heat, Q_cool, Elec_heat, Elec_cool,
#                        Elec_total, Comfort
#   set_point_df     : Optional Data frame (Default: NULL). Setpoint schedule with columns:
#                        period        - POSIXct. Market period timestamps.
#                        STP_heat      - Numeric. Heating setpoint (°C).
#                        STP_heat_low  - Numeric. Lower heating threshold (°C).
#                        STP_heat_high - Numeric. Upper heating threshold (°C).
#                        STP_cool      - Numeric. Cooling setpoint (°C).
#                        STP_cool_low  - Numeric. Lower cooling threshold (°C).
#                        STP_cool_high - Numeric. Upper cooling threshold (°C).
#                      If provided, overwrites corresponding context-suffixed values in period_chunk.
#   parameters       : List. Model parameters. Must include sub-list:
#                        parameters$model - thermal model coefficients (Ci, Ce, Rie,
#                                            Rea, Aw, Ae, heat pump coefficients,
#                                            Rvent01, Rvent1, Rvent2, Rvent2_HR,
#                                            Setpoint_Rvent1, inertial_fact, etc.)
#                      (Comfort thresholds are read from period_chunk, not from
#                      parameters$reward - see period_chunk columns above.)
#   calculation_mode : Integer scalar or vector. Computation mode per timestep:
#                        1 - Setpoint mode: Q_heat and Q_cool are computed from
#                            histeresis control logic.
#                        2 - Heat Input mode: Q_heat and Q_cool are read directly
#                            from period_chunk columns.
#                      If a scalar is provided, it is expanded to all timesteps.
#                      Default: 1.
#   calculation_context: Character. Determines the dataframe columns to read from/write to.
#                      Valid options: "execution" (default), "plan", "plan_flex".
#                      "execution" reads/writes with "_exec" suffix (e.g. Ti_exec, Q_heat_exec, STP_heat_low_exec).
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
#                    Comfort    - Integer (0/1). Comfort flag per timestep.
#                    Act_heat   - Integer (0/1). Heating activation per timestep.
#                    Act_cool   - Integer (0/1). Cooling activation per timestep.
# -------------------------------------------------------------
# Code outline
# 1. Validate inputs and calculation context
# 2. Extract model parameters
# 3. Create internal vectors for fast computation
# 4. Apply setpoints from set_point_df if provided (vectorized by MarketUTC)
# 5. Validate initial states and setpoint vectors
# 6. Simulation loop: hysteresis control, thermal dynamics, energy
# 7. Write results back to data frame
# -------------------------------------------------------------
# Usage instructions
# result_df <- period_calculation(period_chunk, parameters)
# result_df <- period_calculation(period_chunk, parameters, calculation_mode = 2, calculation_context = "plan", set_point_df = sp_df)
# -------------------------------------------------------------
# Where this function/script is used
# Called directly by evaluate_control(), implement_control_step(),
# flex_evaluation(), and run_market_process() (for the "operation"
# optimization aim, which skips the GA optimizers). fitness_funct_optimize_setpoint()/
# fitness_funct_optimize_mode() only reach it indirectly, via evaluate_control().
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
#   - If set_point_df$period contains duplicated values, the function raises an
#     error via stop() before applying setpoints.
#   - Heating and cooling are mutually exclusive: if heating is active, cooling
#     is forced off regardless of the temperature relative to the cooling setpoint.
#   - Setpoints are applied using hysteresis: heating activates when Ti drops
#     below STP_heat_low and deactivates when Ti rises above STP_heat_high;
#     cooling applies the same logic with STP_cool_low and STP_cool_high.
#   - Optional columns Q_heat, Q_cool, Elec_heat, Elec_cool, Elec_total,
#     and Comfort are carried over from period_chunk's existing
#     value at row 1 (the initial-condition row, never recomputed by the
#     simulation loop) whenever the column is already present, and
#     initialized to 0 if absent from period_chunk; NA values in these
#     columns are also treated as 0.
#   - If required initial states or setpoint values are missing, the function
#     stops with an error so the simulation does not continue with undefined
#     control logic.
#   - inertial_fact is read from parameters$model and used in the internal
#     temperature calculation when the thermal inertia distribution model is active.
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
    
    # Validate set_point_df structure when provided
    if (!is.null(set_point_df)) {
      req_sp_cols <- c("period", "STP_heat", "STP_heat_low", "STP_heat_high",
                       "STP_cool","STP_cool_low", "STP_cool_high")
      missing_sp_cols <- req_sp_cols[!req_sp_cols %in% names(set_point_df)]
      if (length(missing_sp_cols) > 0) {
        stop("set_point_df is missing required columns: ",
             paste(missing_sp_cols, collapse = ", "))
      }
      
      if (any(is.na(set_point_df$period))) {
        stop("set_point_df$period contains NA values")
      }
      
      if (any(is.na(set_point_df$STP_heat_low))) {
        stop("set_point_df$STP_heat_low contains NA values")
      }
      
      if (any(is.na(set_point_df$STP_heat_high))) {
        stop("set_point_df$STP_heat_high contains NA values")
      }
      
      if (any(is.na(set_point_df$STP_cool_low))) {
        stop("set_point_df$STP_cool_low contains NA values")
      }
      
      if (any(is.na(set_point_df$STP_cool_high))) {
        stop("set_point_df$STP_cool_high contains NA values")
      }
    }
  }
  
  # Determine column suffix based on context
  col_sfx <- switch(calculation_context,
                    "execution" = "_exec",
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
    Rvent2_HR           <- parameters$model$Rvent2_HR
    Setpoint_Rvent1     <- parameters$model$Setpoint_Rvent1
    inertial_fact       <- parameters$model$inertial_fact
    if (calculation_context == "execution" &&
        all(c("Service_T_Low", "Service_T_High") %in% names(period_chunk))) {
      comfort_low  <- period_chunk$Service_T_Low
      comfort_high <- period_chunk$Service_T_High
    } else if (calculation_context %in% c("plan", "plan_flex") &&
               all(c("Scheduling_T_Low", "Scheduling_T_High") %in% names(period_chunk))) {
      comfort_low  <- period_chunk$Scheduling_T_Low
      comfort_high <- period_chunk$Scheduling_T_High
    } else {
      stop("Comfort temperature columns not found in period_chunk for the given calculation_context. Expected columns: ",
           if (calculation_context == "execution") {
             "Service_T_Low and Service_T_High"
           } else {
             "Scheduling_T_Low and Scheduling_T_High"
           })
    }
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

      # Look for Elec_total and Comfort context columns.
      # Same carry-over policy as Q_heat/Q_cool/Elec_heat/Elec_cool above:
      # row 1 (the initial-condition row of this call) is never
      # recomputed by the simulation loop, so it must keep whatever
      # value it already had in period_chunk instead of being reset to 0.
      col_Elec_total <- paste0("Elec_total", col_sfx)
      col_Comfort    <- paste0("Comfort", col_sfx)

      if (col_Elec_total %in% names(period_chunk)) {
        Elec_total <- period_chunk[[col_Elec_total]]
      } else {
        Elec_total <- rep(0, n)
      }
      Elec_total[is.na(Elec_total)] <- 0

      if (col_Comfort %in% names(period_chunk)) {
        Comfort <- period_chunk[[col_Comfort]]
      } else {
        Comfort <- rep(0, n)
      }
      Comfort[is.na(Comfort)] <- 0
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
      
      if (is.na(Ti[1])) {
        stop("Initial state ", col_Ti, " contains NA at row 1")
      }
      
      if (is.na(Te[1])) {
        stop("Initial state ", col_Te, " contains NA at row 1")
      }
      
      if (is.na(Act_heat[1])) {
        stop("Initial state ", col_Act_heat, " contains NA at row 1")
      }
      
      if (is.na(Act_cool[1])) {
        stop("Initial state ", col_Act_cool, " contains NA at row 1")
      }
    }
  }
  
  # setpoints
  {
    # Determine specific column names based on calculation_context
    col_STP_heat      <- paste0("STP_heat", col_sfx)
    col_STP_heat_low  <- paste0("STP_heat_low", col_sfx)
    col_STP_heat_high <- paste0("STP_heat_high", col_sfx)
    
    col_STP_cool      <- paste0("STP_cool", col_sfx)
    col_STP_cool_low  <- paste0("STP_cool_low", col_sfx)
    col_STP_cool_high <- paste0("STP_cool_high", col_sfx)
    
    # Special logic for execution: Copy plan setpoints to current context columns
    if (calculation_context == "execution") {
      period_chunk[[col_STP_heat]]  <- period_chunk$STP_heat_plan
      period_chunk[[col_STP_heat_low]]  <- period_chunk$STP_heat_low_plan
      period_chunk[[col_STP_heat_high]] <- period_chunk$STP_heat_high_plan
      
      period_chunk[[col_STP_cool]]  <- period_chunk$STP_cool_plan
      period_chunk[[col_STP_cool_low]]  <- period_chunk$STP_cool_low_plan
      period_chunk[[col_STP_cool_high]] <- period_chunk$STP_cool_high_plan
    }
    
    if (!is.null(set_point_df)) {
      # Populate setpoints from the provided dataframe (rows 2:n, vectorized)
      if (anyDuplicated(set_point_df$period) > 0) {
        stop("set_point_df$period contains duplicated values")
      }
      
      rows_to_update <- 2:n
      idx <- match(MarketUTC[rows_to_update], set_point_df$period)
      
      if (any(is.na(idx))) {
        missing_rows <- rows_to_update[is.na(idx)]
        stop("Setpoint not found for MarketUTC in row(s): ", paste(missing_rows, collapse = ", "))
      }
      
      period_chunk[[col_STP_heat]][rows_to_update]      <- set_point_df$STP_heat[idx]
      period_chunk[[col_STP_heat_low]][rows_to_update]  <- set_point_df$STP_heat_low[idx]
      period_chunk[[col_STP_heat_high]][rows_to_update] <- set_point_df$STP_heat_high[idx]
      
      period_chunk[[col_STP_cool]][rows_to_update]      <- set_point_df$STP_cool[idx]
      period_chunk[[col_STP_cool_low]][rows_to_update]  <- set_point_df$STP_cool_low[idx]
      period_chunk[[col_STP_cool_high]][rows_to_update] <- set_point_df$STP_cool_high[idx]
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
      STP_heat      <- period_chunk[[col_STP_heat]]
      STP_heat_low  <- period_chunk[[col_STP_heat_low]]
      STP_heat_high <- period_chunk[[col_STP_heat_high]]
      
      STP_cool      <- period_chunk[[col_STP_cool]]
      STP_cool_low  <- period_chunk[[col_STP_cool_low]]
      STP_cool_high <- period_chunk[[col_STP_cool_high]]
      
      if (any(is.na(STP_heat_low[2:n]))) {
        stop("Setpoint column ", col_STP_heat_low, " contains NA values in simulated rows")
      }
      
      if (any(is.na(STP_heat_high[2:n]))) {
        stop("Setpoint column ", col_STP_heat_high, " contains NA values in simulated rows")
      }
      
      if (any(is.na(STP_cool_low[2:n]))) {
        stop("Setpoint column ", col_STP_cool_low, " contains NA values in simulated rows")
      }
      
      if (any(is.na(STP_cool_high[2:n]))) {
        stop("Setpoint column ", col_STP_cool_high, " contains NA values in simulated rows")
      }
    }
  }
    
  # -------------------------------------------------------------
  # 6. Simulation loop (Executed in C++ for high performance)
  # -------------------------------------------------------------
  {
    # period_simulation_cpp is called to run the timestep-by-timestep
    # hysteresis control and thermal dynamics loop over the prepared
    # vectors, in compiled C++ instead of an R loop, for performance.
    sim_results <- period_simulation_cpp(
      Ti                   = Ti,
      Te                   = Te,
      Act_heat             = Act_heat,
      Act_cool             = Act_cool,
      Q_heat               = Q_heat,
      Q_cool               = Q_cool,
      Elec_heat            = Elec_heat,
      Elec_cool            = Elec_cool,
      Elec_total           = Elec_total,
      Comfort              = Comfort,
      SolarR               = SolarR,
      Text                 = Text,
      T_ext_24h            = T_ext_24h,
      Act_vent             = Act_vent,
      time                 = as.numeric(time),
      comfort_low          = comfort_low,
      comfort_high         = comfort_high,
      STP_heat_low         = STP_heat_low,
      STP_heat_high        = STP_heat_high,
      STP_cool_low         = STP_cool_low,
      STP_cool_high        = STP_cool_high,
      calculation_mode_vec = as.integer(calculation_mode_vec),
      Ci                   = Ci,
      Ce                   = Ce,
      Rie                  = Rie,
      Rea                  = Rea,
      Aw                   = Aw,
      Ae                   = Ae,
      Shading_0            = Shading_0,
      Shading_1            = Shading_1,
      Setpoint_Shading1    = Setpoint_Shading1,
      AT_hp_heat_1         = AT_hp_heat_1,
      AT_hp_heat_2         = AT_hp_heat_2,
      Q_hp_heat_1          = Q_hp_heat_1,
      Q_hp_heat_2          = Q_hp_heat_2,
      COP_hp_heat_1_coef1  = COP_hp_heat_1_coef1,
      COP_hp_heat_1_coef2  = COP_hp_heat_1_coef2,
      COP_hp_heat_1_coef3  = COP_hp_heat_1_coef3,
      Tsup_hp_heat         = Tsup_hp_heat,
      Q_hp_cool            = Q_hp_cool,
      COP_hp_cool          = COP_hp_cool,
      Rvent01              = Rvent01,
      Rvent1               = Rvent1,
      Rvent2               = Rvent2,
      Rvent2_HR            = Rvent2_HR,
      Setpoint_Rvent1      = Setpoint_Rvent1,
      inertial_fact        = inertial_fact
    )

    # Extract vectors from C++ result
    Ti         <- sim_results$Ti
    Te         <- sim_results$Te
    Act_heat   <- sim_results$Act_heat
    Act_cool   <- sim_results$Act_cool
    Q_heat     <- sim_results$Q_heat
    Q_cool     <- sim_results$Q_cool
    Elec_heat  <- sim_results$Elec_heat
    Elec_cool  <- sim_results$Elec_cool
    Elec_total <- sim_results$Elec_total
    Comfort    <- sim_results$Comfort

    rm(sim_results)
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
    period_chunk[[paste0("Comfort", col_sfx)]]    <- Comfort
    period_chunk[[paste0("Act_heat", col_sfx)]]   <- Act_heat
    period_chunk[[paste0("Act_cool", col_sfx)]]   <- Act_cool
    
    # Write back the setpoints used for the calculation
    period_chunk[[col_STP_heat]]      <- STP_heat
    period_chunk[[col_STP_heat_low]]  <- STP_heat_low
    period_chunk[[col_STP_heat_high]] <- STP_heat_high
    
    period_chunk[[col_STP_cool]]      <- STP_cool
    period_chunk[[col_STP_cool_low]]  <- STP_cool_low
    period_chunk[[col_STP_cool_high]] <- STP_cool_high
  }

  # Release the local vectors and scalars built up for this call.
  # intersect(..., ls()) is used because several of these (the
  # set_point_df validation temporaries, in particular) only exist on
  # some code paths.
  rm(list = intersect(
    c("Ci", "Ce", "Rie", "Rea", "Aw", "Ae", "Shading_0", "Shading_1",
      "Setpoint_Shading1", "AT_hp_heat_1", "AT_hp_heat_2",
      "Q_hp_heat_1", "Q_hp_heat_2",
      "COP_hp_heat_1_coef1", "COP_hp_heat_1_coef2", "COP_hp_heat_1_coef3",
      "Tsup_hp_heat", "Q_hp_cool", "COP_hp_cool",
      "Rvent01", "Rvent1", "Rvent2", "Rvent2_HR", "Setpoint_Rvent1",
      "inertial_fact", "comfort_low", "comfort_high",
      "col_sfx", "n",
      "SolarR", "Text", "Act_vent", "T_ext_24h", "Occupancy", "time", "MarketUTC",
      "Ti", "Te", "Act_heat", "Act_cool",
      "col_Q_heat", "col_Q_cool", "col_Elec_heat", "col_Elec_cool",
      "Q_heat", "Q_cool", "Elec_heat", "Elec_cool",
      "col_Elec_total", "col_Comfort", "Elec_total", "Comfort",
      "col_Ti", "col_Te", "col_Act_heat", "col_Act_cool",
      "col_STP_heat", "col_STP_heat_low", "col_STP_heat_high",
      "col_STP_cool", "col_STP_cool_low", "col_STP_cool_high",
      "rows_to_update", "idx",
      "STP_heat", "STP_heat_low", "STP_heat_high",
      "STP_cool", "STP_cool_low", "STP_cool_high",
      "calculation_mode_vec",
      "req_sp_cols", "missing_sp_cols", "req_stp_cols", "missing_cols", "missing_rows",
      "invalid_vals"),
    ls()
  ))

  return(period_chunk)
}
