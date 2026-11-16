# -------------------------------------------------------------
# Function: period_calculation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# This function performs the physical simulation of the
# building for a given period based on climate data and
# setpoint values.
# This function:
#    - runs over a dataframe
#    - defines control signals for each timestep and
#    - activates heating and cooling systems accordingly
#    - computes changes to the building thermal state
#    - calculates comfort level
# This function performs no economic calculation: the cost of the
# electricity it computes is resolved elsewhere, by the reward of the
# planning contexts and by the settlement of the execution.
# A 2C simplified model is used, with a pseudo-static approach.
# Histeresis-based thermostatic control is used for heating and
# cooling systems.
# Occupancy-based ventilation is performed: the occupied rows are
# ventilated, and the unoccupied rows take infiltration or reinforced
# ventilation depending on T_ext_24h.
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
#                                      Read in the "execution" context.
#                        Text        - Numeric. External air temperature
#                                      (°C). Read in the "execution"
#                                      context.
#                        SolarR_forec and Text_forec - Numeric. Their
#                                      forecasts, read instead of SolarR
#                                      and Text in the "plan",
#                                      "plan_flex_down" and
#                                      "plan_flex_up" contexts.
#                        T_ext_24h   - Numeric. Mean external temperature
#                                      of the previous day (°C), held
#                                      constant over the day. It is not
#                                      a running mean. It
#                                      selects the shading coefficient
#                                      and the ventilation of the
#                                      unoccupied rows. Read in the
#                                      "execution" context.
#                        T_ext_24h_forec - Numeric. The T_ext_24h the
#                                      plan knows (°C): the mean Text
#                                      of the day before the clearing
#                                      date of the market, constant
#                                      over the period. Read instead of
#                                      T_ext_24h in the "plan",
#                                      "plan_flex_down" and
#                                      "plan_flex_up" contexts.
#                        Occupancy   - Integer (0/1). Building occupancy flag.
#                                      The C++ core runs the occupied
#                                      ventilation while it is 1.
#                        MarketUTC   - POSIXct. Market period timestamps for
#                                      setpoint lookup.
#                        Ti          - Numeric. Initial internal temperature
#                                      (°C) at row 1. (Prefix applies based on
#                                      context)
#                        Te          - Numeric. Initial envelope temperature
#                                      (°C) at row 1. (Prefix applies based on
#                                      context)
#                        Act_heat    - Integer (0/1/2). Initial heating
#                                      activation at row 1. (Prefix
#                                      applies based on context)
#                        Act_cool    - Integer (0/1/2). Initial cooling
#                                      activation at row 1. (Prefix
#                                      applies based on context)
#                        Thermostat_heat and Thermostat_cool - Integer
#                                      (0/1). Initial state of the two
#                                      thermostats at row 1, which the
#                                      hysteresis of row 2 starts from.
#                                      (Prefix applies based on context.)
#                                      A chunk without these columns
#                                      takes the state of Act_heat and
#                                      Act_cool of row 1, which must
#                                      then be 0 or 1.
#                        Service_T_Low and Service_T_High - Numeric. Comfort
#                                    band, required when calculation_context is
#                                    "execution".
#                        Scheduling_T_Low and Scheduling_T_High - Numeric.
#                                    Comfort band, required when
#                                    calculation_context is "plan",
#                                    "plan_flex_down" or "plan_flex_up".
#                        For "plan_flex_down" and "plan_flex_up", also
#                        Service_T_Low, Service_T_High and the phase column
#                        of the leg (Flex_phase_down_plan or
#                        Flex_phase_up_plan): on the rows of a flexibility
#                        window (phase above 0) the occupancy band
#                        Service_T_* is used instead of Scheduling_T_*.
#                      If set_point_df is NULL, must ALSO contain (with context
#                      suffix):
#                        - STP_heat_low
#                        - STP_heat_high
#                        - STP_cool_low
#                        - STP_cool_high
#                      In the "execution" context, the STP_*_exec
#                      columns are first overwritten with the STP_*_plan
#                      columns, so period_chunk must hold the six
#                      STP_*_plan columns: the execution always runs the
#                      setpoints of the plan.
#                      Optional columns (carried over from period_chunk if
#                      present, NA treated as 0, initialized to 0 if absent):
#                        - Q_heat
#                        - Q_cool
#                        - Elec_heat
#                        - Elec_cool
#                        - Elec_total
#                        - Comfort
#   set_point_df     : Optional Data frame (Default: NULL). Setpoint schedule
#                      with columns:
#                        period        - POSIXct. Market period timestamps.
#                        STP_heat      - Numeric. Heating setpoint (°C).
#                        STP_heat_low  - Numeric. Lower heating threshold (°C).
#                        STP_heat_high - Numeric. Upper heating threshold (°C).
#                        STP_cool      - Numeric. Cooling setpoint (°C).
#                        STP_cool_low  - Numeric. Lower cooling threshold (°C).
#                        STP_cool_high - Numeric. Upper cooling threshold (°C).
#                      If provided, overwrites corresponding context-suffixed
#                      values in period_chunk, on rows 2 to n only: row
#                      1 keeps the setpoints it already had. Each row
#                      takes the setpoints of the period equal to its
#                      MarketUTC.
#   asset            : Named list. The parameters of the building, its
#                      entry of parameters$assets. Must include the group
#                      model, the thermal model coefficients, among them:
#                                            - Ci
#                                            - Ce
#                                            - Rie
#                                            - Rea
#                                            - Aw
#                                            - Ae
#                                            - the heat pump coefficients
#                                            - Rvent01
#                                            - Rvent1
#                                            - Rvent2
#                                            - Rvent2_HR
#                                            - Setpoint_Rvent1
#                                            - inertial_fact
#                      (Comfort thresholds are read from period_chunk, not from
#                      the parameters - see period_chunk columns above.)
#   calculation_mode : Integer scalar or vector. Computation mode per timestep:
#                        1 - Setpoint mode: Q_heat and Q_cool are computed from
#                            histeresis control logic.
#                        2 - Heat Input mode: Q_heat and Q_cool are read
#                            directly from period_chunk columns.
#                        3 - Setpoint with a per-step power cap: as mode 1, but
#                            the decision of every step is bounded by
#                            Q_heat_cap/Q_cool_cap before the RC equations, so
#                            the bound propagates to the next step's state.
#                      If a scalar is provided, it is expanded to all timesteps.
#                      Default: 1.
#   Q_heat_cap       : Numeric vector or NULL. Per-step upper bound on the
#                      heating energy of the timesteps in mode 3 (kWh per step,
#                      the same unit as the Q_heat columns). Must have one value
#                      per row of period_chunk. NULL (the default) means no
#                      bound anywhere, which leaves mode 3 identical to mode 1.
#                      Ignored by the timesteps in modes 1 and 2.
#   Q_cool_cap       : Numeric vector or NULL. Same as Q_heat_cap, for cooling.
#   calculation_context: Character. Determines the dataframe columns to read
#                      from/write to.
#                      Valid options: "execution" (default), "plan",
#                      "plan_flex_down", "plan_flex_up".
#                      "execution" reads/writes with "_exec" suffix (e.g.
#                      Ti_exec, Q_heat_exec, STP_heat_low_exec).
#                      "plan" reads/writes with "_plan" suffix (e.g. Ti_plan,
#                      STP_heat_low_plan).
#                      "plan_flex_down" reads/writes with "_plan_flex_down"
#                      suffix (downward flexibility itinerary).
#                      "plan_flex_up" reads/writes with "_plan_flex_up" suffix
#                      (upward flexibility itinerary).
# -------------------------------------------------------------
# Outputs
#   period_chunk : Data frame. The input data frame with the following columns
#                  added or updated (depending on calculation_context):
#                    Ti         - Numeric. Internal temperature time series
#                                 (°C).
#                    Te         - Numeric. Envelope temperature time series
#                                 (°C).
#                    Q_heat     - Numeric. Heating energy per timestep (kWh).
#                    Q_cool     - Numeric. Cooling energy per timestep (kWh).
#                    Elec_heat  - Numeric. Heating electricity consumption per
#                                 timestep (kWh).
#                    Elec_cool  - Numeric. Cooling electricity consumption per
#                                 timestep (kWh).
#                    Elec_total - Numeric. Total electricity consumption per
#                                 timestep (kWh).
#                    Comfort    - Integer (0/1). Comfort flag per timestep:
#                                 1 when Ti is strictly inside the
#                                 comfort band of the row.
#                    Act_heat   - Integer (0/1/2). Heating activation per
#                                 timestep: 0 off, 1 on by the
#                                 thermostat, 2 imposed (calculation_mode
#                                 2 with a heating above 0).
#                    Act_cool   - Integer (0/1/2). Cooling activation per
#                                 timestep, with the same codes.
#                    Thermostat_heat and Thermostat_cool - Integer (0/1).
#                                 State of each thermostat at the end of
#                                 each timestep, also while the heat is
#                                 imposed.
#                    STP_*      - Numeric. The six setpoint columns of the
#                                 context, as used by the simulation.
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
# result_df <- period_calculation(period_chunk, asset)
# result_df <- period_calculation(period_chunk, asset, calculation_mode =
# 2, calculation_context = "plan", set_point_df = sp_df)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - If period_chunk has fewer than 2 rows, the function returns the input
#     data frame unchanged (no simulation is performed).
#   - If set_point_df is NULL and suffixed setpoint columns are missing in 
#     period_chunk, an error is raised via stop().
#   - calculation_mode can be a per-timestep vector; invalid values (not 1, 2
#     or 3) raise an error via stop(). A length mismatch with the number of
#     timesteps also raises an error.
#   - Q_heat_cap/Q_cool_cap are accepted whatever the modes in use, and are
#     only read by the timesteps in mode 3. A non-NULL cap whose length does
#     not match the number of timesteps raises an error via stop(); NA values
#     inside a cap vector are treated as "no bound", the same as Inf.
#   - The system lock these caps implement is an interpretation of the legal
#     regulation of HVAC systems, which does not allow energy management
#     through the alternating use of heating and cooling. See
#     build_hvac_lock_caps.R.
#   - Invalid calculation_context value will raise an error via stop().
#   - If a MarketUTC value in period_chunk has no matching 'period' entry in
#     set_point_df, the function raises an error via stop().
#   - If set_point_df$period contains duplicated values, the function raises an
#     error via stop() before applying setpoints.
#   - Heating and cooling are mutually exclusive: if heating is active, cooling
#     is forced off regardless of the temperature relative to the cooling
#     setpoint.
#   - Setpoints are applied using hysteresis: heating activates when Ti drops
#     below STP_heat_low and deactivates when Ti rises above STP_heat_high;
#     cooling applies the same logic with STP_cool_low and STP_cool_high.
#   - The optional columns listed under Inputs are carried over from
#     period_chunk's existing
#     value at row 1 (the initial-condition row, never recomputed by the
#     simulation loop) whenever the column is already present, and
#     initialized to 0 if absent from period_chunk; NA values in these
#     columns are also treated as 0.
#   - If required initial states or setpoint values are missing, the function
#     stops with an error so the simulation does not continue with undefined
#     control logic.
#   - inertial_fact is read from asset$model and always used in the
#     internal temperature calculation: a fraction inertial_fact of the
#     heat of each step reaches the indoor air one step later (the power
#     of the previous step), and the rest in the step itself.
# -------------------------------------------------------------
period_calculation <- function(period_chunk,
                               asset,
                               calculation_mode = 1,
                               calculation_context = "execution",
                               set_point_df = NULL,
                               Q_heat_cap = NULL,
                               Q_cool_cap = NULL) {
  # Validations
  {
    # Validate calculation_context
    if (!calculation_context %in% c("execution", "plan", "plan_flex_down", "plan_flex_up")) {
      stop("Invalid calculation_context. Must be 'execution', 'plan', ",
           "'plan_flex_down' or 'plan_flex_up'.")
    }
    
    # Ensure that there is actually something to simulate (2 or more rows)
    # otherwise, end.
    if (nrow(period_chunk) < 2) return(period_chunk)
    
    # Handle calculation_mode: expand scalar to vector if needed
    {
      # calculation_mode: 1 = Setpoint, 2 = Heat Input,
      #                   3 = Setpoint with a per-step power cap
      # Each timestep can have a different value
      if (length(calculation_mode) == 1) {
        calculation_mode_vec <- rep(calculation_mode, nrow(period_chunk))
      } else {
        calculation_mode_vec <- calculation_mode
      }
    }
    
    # Validate all calculation_mode values in the vector
    invalid_vals <- unique(calculation_mode_vec[!(calculation_mode_vec %in% c(1, 2, 3))])
    if (length(invalid_vals) > 0) {
      stop("Invalid calculation_mode value(s): ", paste(invalid_vals, collapse = ", "),
           ". Must be 1 (Setpoint), 2 (Heat Input) or 3 (Setpoint with cap).")
    }
    
    # Validate vector length matches number of timesteps
    if (length(calculation_mode_vec) != nrow(period_chunk)) {
      stop("calculation_mode vector length (", length(calculation_mode_vec),
           ") does not match number of timesteps (", nrow(period_chunk), ").")
    }
    
    # Normalize the per-step power caps of calculation_mode 3. The C++ loop
    # indexes them row by row, so they are always passed as full-length
    # numeric vectors; the absence of a cap is expressed as Inf, which the
    # loop's min() leaves without effect and which therefore makes mode 3
    # behave exactly as mode 1.
    {
      normalize_power_cap <- function(cap, cap_name) {
        if (is.null(cap)) return(rep(Inf, nrow(period_chunk)))
        if (!is.numeric(cap)) {
          stop(cap_name, " must be numeric or NULL.")
        }
        if (length(cap) != nrow(period_chunk)) {
          stop(cap_name, " length (", length(cap),
               ") does not match number of timesteps (", nrow(period_chunk), ").")
        }
        cap[is.na(cap)] <- Inf
        return(cap)
      }

      Q_heat_cap_vec <- normalize_power_cap(Q_heat_cap, "Q_heat_cap")
      Q_cool_cap_vec <- normalize_power_cap(Q_cool_cap, "Q_cool_cap")

      rm(list = "normalize_power_cap")
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
                    "plan_flex_down" = "_plan_flex_down",
                    "plan_flex_up"   = "_plan_flex_up")
  
  n <- nrow(period_chunk)
  
  # Extract model parameters one by one
  {
    Ci                  <- asset$model$Ci
    Ce                  <- asset$model$Ce
    Rie                 <- asset$model$Rie
    Rea                 <- asset$model$Rea
    Aw                  <- asset$model$Aw
    Ae                  <- asset$model$Ae
    Shading_0           <- asset$model$Shading_0
    Shading_1           <- asset$model$Shading_1
    Setpoint_Shading1   <- asset$model$Setpoint_Shading1
    AT_hp_heat_1        <- asset$model$AT_hp_heat_1
    AT_hp_heat_2        <- asset$model$AT_hp_heat_2
    Q_hp_heat_1         <- asset$model$Q_hp_heat_1
    Q_hp_heat_2         <- asset$model$Q_hp_heat_2
    COP_hp_heat_1_coef1 <- asset$model$COP_hp_heat_1_coef1
    COP_hp_heat_1_coef2 <- asset$model$COP_hp_heat_1_coef2
    COP_hp_heat_1_coef3 <- asset$model$COP_hp_heat_1_coef3
    Tsup_hp_heat        <- asset$model$Tsup_hp_heat
    Text_ref_hp_heat    <- asset$model$Text_ref_hp_heat
    Tsup_ref_hp_heat    <- asset$model$Tsup_ref_hp_heat
    Q_hp_cool           <- asset$model$Q_hp_cool
    COP_hp_cool         <- asset$model$COP_hp_cool
    Rvent01             <- asset$model$Rvent01
    Rvent1              <- asset$model$Rvent1
    Rvent2              <- asset$model$Rvent2
    Rvent2_HR           <- asset$model$Rvent2_HR
    Setpoint_Rvent1     <- asset$model$Setpoint_Rvent1
    inertial_fact       <- asset$model$inertial_fact
    if (calculation_context == "execution" &&
        all(c("Service_T_Low", "Service_T_High") %in% names(period_chunk))) {
      comfort_low  <- period_chunk$Service_T_Low
      comfort_high <- period_chunk$Service_T_High
    } else if (calculation_context == "plan" &&
               all(c("Scheduling_T_Low", "Scheduling_T_High") %in% names(period_chunk))) {
      comfort_low  <- period_chunk$Scheduling_T_Low
      comfort_high <- period_chunk$Scheduling_T_High
    } else if (calculation_context %in% c("plan_flex_down", "plan_flex_up") &&
               all(c("Scheduling_T_Low", "Scheduling_T_High",
                     "Service_T_Low", "Service_T_High",
                     paste0("Flex_phase_", sub("^plan_flex_", "", calculation_context), "_plan"))
                   %in% names(period_chunk))) {
      # A flexibility itinerary is measured against the occupancy band
      # on the rows of its window (Commitment, Neutral and Recovery
      # Phases), and against the plan band everywhere else.
      in_window    <- period_chunk[[paste0("Flex_phase_",
                                           sub("^plan_flex_", "", calculation_context),
                                           "_plan")]] > 0
      comfort_low  <- ifelse(in_window, period_chunk$Service_T_Low,  period_chunk$Scheduling_T_Low)
      comfort_high <- ifelse(in_window, period_chunk$Service_T_High, period_chunk$Scheduling_T_High)
      rm(list = "in_window")
    } else {
      stop("Comfort temperature columns not found in period_chunk for the given calculation_context. Expected columns: ",
           if (calculation_context == "execution") {
             "Service_T_Low and Service_T_High"
           } else if (calculation_context == "plan") {
             "Scheduling_T_Low and Scheduling_T_High"
           } else {
             "Scheduling_T_Low, Scheduling_T_High, Service_T_Low, Service_T_High and the Flex_phase_<leg>_plan column"
           })
    }
  }
  
  # Create vectors for faster operation
  {
    # Invariable vectors selected by calculation_context
    {
      if (calculation_context == "execution") {
        SolarR    <- period_chunk$SolarR
        Text      <- period_chunk$Text
        T_ext_24h <- period_chunk$T_ext_24h
      } else {
        # Use forecast columns for the plan and both flexibility
        # contexts. T_ext_24h_forec holds only what is known when the
        # market clears, never the temperature of a later day.
        SolarR    <- period_chunk$SolarR_forec
        Text      <- period_chunk$Text_forec
        T_ext_24h <- period_chunk$T_ext_24h_forec
      }
      if (length(T_ext_24h) != nrow(period_chunk)) {
        stop("period_calculation: period_chunk has no column ",
             if (calculation_context == "execution") {
               "T_ext_24h"
             } else {
               "T_ext_24h_forec"
             },
             " for the context ", calculation_context)
      }

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
      Thermostat_heat <- rep(NA_integer_, n)
      Thermostat_cool <- rep(NA_integer_, n)
      
      # Determine specific column names based on calculation_context
      col_Q_heat    <- paste0("Q_heat", col_sfx)
      col_Q_cool    <- paste0("Q_cool", col_sfx)
      col_Elec_heat <- paste0("Elec_heat", col_sfx)
      col_Elec_cool <- paste0("Elec_cool", col_sfx)
      
      # Initialize Q_heat, Q_cool, Elec_heat, Elec_cool from period_chunk if
      # available, with NA values turned into 0
      
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

      # The hysteresis of row 2 starts from the state of the thermostats
      # at row 1. A chunk that does not hold their columns takes it from
      # the activation of row 1, which is then the state of the
      # thermostat only if no heat was imposed there (0 or 1, not 2).
      col_Thermostat_heat <- paste0("Thermostat_heat", col_sfx)
      col_Thermostat_cool <- paste0("Thermostat_cool", col_sfx)
      if (col_Thermostat_heat %in% names(period_chunk)) {
        Thermostat_heat[1] <- period_chunk[[col_Thermostat_heat]][1]
      } else if (Act_heat[1] %in% c(0, 1)) {
        Thermostat_heat[1] <- Act_heat[1]
      }
      if (col_Thermostat_cool %in% names(period_chunk)) {
        Thermostat_cool[1] <- period_chunk[[col_Thermostat_cool]][1]
      } else if (Act_cool[1] %in% c(0, 1)) {
        Thermostat_cool[1] <- Act_cool[1]
      }

      if (is.na(Thermostat_heat[1])) {
        stop("Initial state ", col_Thermostat_heat, " is missing at row 1")
      }

      if (is.na(Thermostat_cool[1])) {
        stop("Initial state ", col_Thermostat_cool, " is missing at row 1")
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
    
    # Special logic for execution: Copy plan setpoints to current context
    # columns
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
      # Fallback: check that the required context-specific columns exist in
      # period_chunk
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
      Thermostat_heat      = Thermostat_heat,
      Thermostat_cool      = Thermostat_cool,
      Q_heat               = Q_heat,
      Q_cool               = Q_cool,
      Elec_heat            = Elec_heat,
      Elec_cool            = Elec_cool,
      Elec_total           = Elec_total,
      Comfort              = Comfort,
      SolarR               = SolarR,
      Text                 = Text,
      T_ext_24h            = T_ext_24h,
      Occupancy            = Occupancy,
      time                 = as.numeric(time),
      comfort_low          = comfort_low,
      comfort_high         = comfort_high,
      STP_heat_low         = STP_heat_low,
      STP_heat_high        = STP_heat_high,
      STP_cool_low         = STP_cool_low,
      STP_cool_high        = STP_cool_high,
      calculation_mode_vec = as.integer(calculation_mode_vec),
      Q_heat_cap           = Q_heat_cap_vec,
      Q_cool_cap           = Q_cool_cap_vec,
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
      Text_ref_hp_heat     = Text_ref_hp_heat,
      Tsup_ref_hp_heat     = Tsup_ref_hp_heat,
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
    Thermostat_heat <- sim_results$Thermostat_heat
    Thermostat_cool <- sim_results$Thermostat_cool
    Q_heat     <- sim_results$Q_heat
    Q_cool     <- sim_results$Q_cool
    Elec_heat  <- sim_results$Elec_heat
    Elec_cool  <- sim_results$Elec_cool
    Elec_total <- sim_results$Elec_total
    Comfort    <- sim_results$Comfort

    rm(list = "sim_results")
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
    period_chunk[[col_Thermostat_heat]]           <- Thermostat_heat
    period_chunk[[col_Thermostat_cool]]           <- Thermostat_cool
    
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
      "Tsup_hp_heat", "Text_ref_hp_heat", "Tsup_ref_hp_heat",
      "Q_hp_cool", "COP_hp_cool",
      "Rvent01", "Rvent1", "Rvent2", "Rvent2_HR", "Setpoint_Rvent1",
      "inertial_fact", "comfort_low", "comfort_high",
      "col_sfx", "n",
      "SolarR", "Text", "T_ext_24h", "Occupancy", "time", "MarketUTC",
      "Ti", "Te", "Act_heat", "Act_cool",
      "Thermostat_heat", "Thermostat_cool",
      "col_Thermostat_heat", "col_Thermostat_cool",
      "col_Q_heat", "col_Q_cool", "col_Elec_heat", "col_Elec_cool",
      "Q_heat", "Q_cool", "Elec_heat", "Elec_cool",
      "col_Elec_total", "col_Comfort", "Elec_total", "Comfort",
      "col_Ti", "col_Te", "col_Act_heat", "col_Act_cool",
      "col_STP_heat", "col_STP_heat_low", "col_STP_heat_high",
      "col_STP_cool", "col_STP_cool_low", "col_STP_cool_high",
      "rows_to_update", "idx",
      "STP_heat", "STP_heat_low", "STP_heat_high",
      "STP_cool", "STP_cool_low", "STP_cool_high",
      "calculation_mode_vec", "Q_heat_cap_vec", "Q_cool_cap_vec",
      "req_sp_cols", "missing_sp_cols", "req_stp_cols", "missing_cols", "missing_rows",
      "invalid_vals"),
    ls()
  ))

  return(period_chunk)
}
