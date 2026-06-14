# -------------------------------------------------------------
# Script: simulation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This script implements the main MPC simulation loop.
# For each MarketUTC step (row in Main_df), it performs:
#   1) Scheduling process (if Sched_Market_Name != 0)
#   2) Piloting process   (if Pilot_Market_Name != 0)
#   3) Execution process  (always)
# -------------------------------------------------------------
# Inputs
# Main_df : Data frame. The main simulation data frame.
# parameters : List. Complete parameters list with all sub-lists.
# -------------------------------------------------------------
# Outputs
# Main_df : Data frame. Updated with simulation results.
# execution_time : List. Timing information for the simulation.
# -------------------------------------------------------------
# Code outline
# 1. Data frame formatting (ensure needed columns exist)
# 2. Model initialization (set initial temperatures)
# 3. Compute auxiliary variables and create simulation_control object
# 4. Main simulation loop:
#    4.0 Load Scheduling/Piloting market parameters for each row
#    4.1 Scheduling process (conditional)
#    4.2 Piloting process (conditional)
#    4.3 Execution process (always)
#    4.4 Track execution progress
# -------------------------------------------------------------
# Usage
# source(file.path("30_Simulation", "04_Scripts", "simulation.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by Main.R and Main_SCC.R after parameter loading.
# -------------------------------------------------------------
# functions/scripts called
# is_market_active(), resolve_market_index(), map_optimization_aim(),
# run_market_process(), implement_control_step(), optimize_control_step()
# from 30_Simulation/03_Functions/
# -------------------------------------------------------------

# Data frame formatting
{
  # Ensure all needed columns exist
  for (CONT_001 in parameters$needed_cols) {
    if (!CONT_001 %in% names(Main_df)) {
      Main_df[[CONT_001]] <- 0
    }
  }
  rm(CONT_001)

  # Convert numeric columns to double to ensure compatibility with calculations
  # This is necessary because columns initialized with integer 0 need to accept
  # double values from period_calculation and implement_control_step
  # Automatically detect and convert all numeric columns to double
  numeric_cols <- names(Main_df)[sapply(Main_df, is.numeric)]
  numeric_cols <- setdiff(numeric_cols, c("time", "MarketUTC"))  # Exclude time columns
  for (CONT_002 in numeric_cols) {
    if (!is.double(Main_df[[CONT_002]])) {
      Main_df[[CONT_002]] <- as.double(Main_df[[CONT_002]])
    }
  }
  rm(numeric_cols, CONT_002)
}

# Model initialization
{
  Main_df$Ti[1]           <- parameters$model$Ti_0
  Main_df$Te[1]           <- parameters$model$Te_0
  Main_df$Ti_plan[1]      <- parameters$model$Ti_0
  Main_df$Te_plan[1]      <- parameters$model$Te_0
  Main_df$Ti_plan_flex[1] <- parameters$model$Ti_0
  Main_df$Te_plan_flex[1] <- parameters$model$Te_0
  Main_df$Q_heat[1]       <- parameters$model$Qh_0
  Main_df$Q_cool[1]       <- parameters$model$Qc_0
}

# Auxiliary variables and simulation control object
{
  timestamps <- list()

  timestamps$time_sec <- as.numeric(Main_df$time)
  timestamps$t0       <- timestamps$time_sec[1]

  simulation_control <- list()
  simulation_control$indexes_global <- list(
    n_steps          = nrow(Main_df),
    i0               = 0,
    i1               = 0,
    i_begin_horizon  = 0,
    i_end_horizon    = 0,
    i_end_control    = 0,
    i_impl_end       = 0,
    idx_period       = 0,
    idx_horizon      = 0,
    idx_ctrl         = 0,
    i_flex           = 0
  )
  simulation_control$indexes_local <- list(
    n_steps          = nrow(Main_df),
    i0               = 0,
    i1               = 0,
    i_begin_horizon  = 0,
    idx_period       = 0,
    i_end_horizon    = 0,
    i_end_control    = 0,
    i_impl_end       = 0,
    idx_horizon      = 0,
    idx_ctrl         = 0,
    i_flex           = 0
  )
  simulation_control$parameters <- list(
    Sched_Market_Name          = 0,
    Sched_Market_Bid_time      = 0,
    Sched_Market_Period_Begin  = 0,
    Sched_Market_Period_End    = 0,
    Sched_Optimization_Horizon = 0,
    Sched_Market_Aim           = 0,
    Pilot_Market_Name          = 0,
    Pilot_Market_Bid_time      = 0,
    Pilot_Market_Period_Begin  = 0,
    Pilot_Market_Period_End    = 0,
    Pilot_Optimization_Horizon = 0,
    Pilot_Market_Aim           = 0
  )
  simulation_control$evaluation <- list(
    optimization_aim = "NA"
  )
  simulation_control$flexibility <- list(
    flexibility_event_length = 0,
    flexibility              = 0
  )
  simulation_control$calculation_mode <- 1

  Main_df$MarketUTC <- as.POSIXct(floor(as.numeric(Main_df$time) / (parameters$market$market_resolution * 60)) *
                                  (parameters$market$market_resolution * 60),
                                  origin = "1970-01-01",
                                  tz = "UTC")

}

# Simulation loop
{
  execution_time <- list()
  execution_time$t_begin <- Sys.time()

  if (parameters$debug_and_config$verbose) {
    cat("======================================\n")
    cat("======================================\n")
    cat("Simulation started.\n"                   )
    cat("Total timesteps:", simulation_control$indexes_global$n_steps, "\n" )
    cat("Period to be optimized:\n"               )
    cat("Begins ", format(min(Main_df$time)), "\n")
    cat("Ends "  , format(max(Main_df$time)), "\n")
    cat("======================================\n")
    cat("======================================\n")
  }

  for (CONT_003 in seq_len(simulation_control$indexes_global$n_steps)) {
    # =========================================================
    # 0. LOAD MARKET PARAMETERS FOR CURRENT ROW
    # =========================================================
    {
      market_parameter_fields <- c(
        "Sched_Market_Name",
        "Sched_Market_Bid_time",
        "Sched_Market_Period_Begin",
        "Sched_Market_Period_End",
        "Sched_Optimization_Horizon",
        "Sched_Market_Aim",
        "Pilot_Market_Name",
        "Pilot_Market_Bid_time",
        "Pilot_Market_Period_Begin",
        "Pilot_Market_Period_End",
        "Pilot_Optimization_Horizon",
        "Pilot_Market_Aim"
      )

      for (CONT_004 in market_parameter_fields) {
        simulation_control$parameters[[CONT_004]] <- Main_df[[CONT_004]][CONT_003]
      }
      rm(CONT_004,market_parameter_fields)
    }

    # =========================================================
    # 1. SCHEDULING PROCESS (CONDITIONAL)
    # =========================================================
    {
      market_parameters <- simulation_control$parameters[grep("^Sched_", names(simulation_control$parameters))]

      if (is_market_active(market_parameters$Sched_Market_Name)) {
        
        # 0 Get indexes
        {
          # Global indexes (relative to full Main_df)
          {
            simulation_control$indexes_global$i0 <- resolve_market_index(
              time_raw     = market_parameters$Sched_Market_Bid_time,
              column_name  = "Sched_Market_Bid_time",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i_begin_horizon <- resolve_market_index(
              time_raw     = market_parameters$Sched_Market_Period_Begin,
              column_name  = "Sched_Market_Period_Begin",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i_end_horizon <- resolve_market_index(
              time_raw     = market_parameters$Sched_Optimization_Horizon,
              column_name  = "Sched_Optimization_Horizon",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            simulation_control$indexes_global$i_end_control <- resolve_market_index(
              time_raw     = market_parameters$Sched_Market_Period_End,
              column_name  = "Sched_Market_Period_End",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i1          <- simulation_control$indexes_global$i_end_horizon
            simulation_control$indexes_global$idx_period  <- simulation_control$indexes_global$i0:simulation_control$indexes_global$i_end_horizon
            simulation_control$indexes_global$idx_horizon <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_horizon
            simulation_control$indexes_global$idx_ctrl    <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_control
            simulation_control$indexes_global$i_flex      <- simulation_control$indexes_global$i0
            
          }
          
          # Adapt to local indexes
          {
            simulation_control$indexes_local$i0              <- 1
            simulation_control$indexes_local$i1              <- simulation_control$indexes_global$i1              - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_begin_horizon <- simulation_control$indexes_global$i_begin_horizon - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_end_horizon   <- simulation_control$indexes_global$i_end_horizon   - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_end_control   <- simulation_control$indexes_global$i_end_control   - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$idx_period      <- simulation_control$indexes_global$idx_period      - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$idx_horizon     <- simulation_control$indexes_global$idx_horizon     - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$idx_ctrl        <- simulation_control$indexes_global$idx_ctrl        - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_flex          <- simulation_control$indexes_local$i0
          }
        }
        
        # 1. Forecast context
        {
          ctx <- context_forecast_step(
            simulation_control = simulation_control,
            time_sec           = timestamps$time_sec,
            Main_df            = Main_df,
            parameters         = parameters
          )
          
          Main_df$Text_forec[simulation_control$indexes_global$idx_period]   <- ctx$forecast_df$Text_forec
          Main_df$SolarR_forec[simulation_control$indexes_global$idx_period] <- ctx$forecast_df$SolarR_forec
          
          rm(ctx)
        }
        
        # 2. Subset
        {
          period_chunk <- Main_df[simulation_control$indexes_global$idx_period,]
          
          sched_timestamps <- list(
            time_sec = timestamps$time_sec[simulation_control$indexes_global$idx_period]
          )
        }

        # 3. Run market
        {
          scheduling_results <- run_market_process(
            prefix             = "Sched",
            row_index          = CONT_003,
            period_chunk       = period_chunk,
            market_parameters  = market_parameters,
            simulation_control = simulation_control,
            timestamps         = sched_timestamps,
            parameters         = parameters
          )
        }
        
        # 4. Integrate results (only _plan and _plan_flex columns)
        {
          inject_cols <- grep("(_plan$|_plan_flex$)", names(scheduling_results), value = TRUE)
          Main_df[simulation_control$indexes_global$idx_ctrl, inject_cols] <- scheduling_results[simulation_control$indexes_local$idx_ctrl, inject_cols]
          
          rm(
            period_chunk,
            sched_timestamps, scheduling_results, inject_cols
          )
        }
        
        # 5. Reset indexes
        {
          simulation_control$indexes_global$i0 <- 0
          simulation_control$indexes_global$i1 <- 0
          simulation_control$indexes_global$i_begin_horizon <- 0
          simulation_control$indexes_global$i_end_horizon <- 0
          simulation_control$indexes_global$i_end_control <- 0
          simulation_control$indexes_global$idx_period <-0
          simulation_control$indexes_global$idx_horizon <- 0
          simulation_control$indexes_global$idx_ctrl <- 0
          simulation_control$indexes_global$i_flex <-0
          
          simulation_control$indexes_local$i0 <- 0
          simulation_control$indexes_local$i1 <- 0
          simulation_control$indexes_local$i_begin_horizon <- 0
          simulation_control$indexes_local$i_end_horizon <- 0
          simulation_control$indexes_local$i_end_control <- 0
          simulation_control$indexes_local$idx_period <-0
          simulation_control$indexes_local$idx_horizon <- 0
          simulation_control$indexes_local$idx_ctrl <- 0
          simulation_control$indexes_local$i_flex <-0
        }
      }

      rm(market_parameters)
    }

    # =========================================================
    # 2. PILOTING PROCESS (CONDITIONAL)
    # =========================================================
    {
      market_parameters <- simulation_control$parameters[grep("^Pilot_", names(simulation_control$parameters))]

      if (is_market_active(market_parameters$Pilot_Market_Name)) {
        
        # 0 Get indexes
        {
          # Global indexes (relative to full Main_df)
          {
            simulation_control$indexes_global$i0 <- resolve_market_index(
              time_raw     = market_parameters$Pilot_Market_Bid_time,
              column_name  = "Pilot_Market_Bid_time",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i_begin_horizon <- resolve_market_index(
              time_raw     = market_parameters$Pilot_Market_Period_Begin,
              column_name  = "Pilot_Market_Period_Begin",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i_end_horizon <- resolve_market_index(
              time_raw     = market_parameters$Pilot_Optimization_Horizon,
              column_name  = "Pilot_Optimization_Horizon",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i_end_control <- resolve_market_index(
              time_raw     = market_parameters$Pilot_Market_Period_End,
              column_name  = "Pilot_Market_Period_End",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i1          <- simulation_control$indexes_global$i_end_horizon
            simulation_control$indexes_global$idx_period  <- simulation_control$indexes_global$i0:simulation_control$indexes_global$i_end_horizon
            simulation_control$indexes_global$idx_horizon <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_horizon
            simulation_control$indexes_global$idx_ctrl    <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_control
            simulation_control$indexes_global$i_flex      <- simulation_control$indexes_global$i0
            
          }
          
          # Adapt to local indexes
          {
            simulation_control$indexes_local$i0              <- 1
            simulation_control$indexes_local$i1              <- simulation_control$indexes_global$i1              - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_begin_horizon <- simulation_control$indexes_global$i_begin_horizon - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_end_horizon   <- simulation_control$indexes_global$i_end_horizon   - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_end_control   <- simulation_control$indexes_global$i_end_control   - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$idx_period      <- simulation_control$indexes_global$idx_period      - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$idx_horizon     <- simulation_control$indexes_global$idx_horizon     - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$idx_ctrl        <- simulation_control$indexes_global$idx_ctrl        - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_flex          <- simulation_control$indexes_local$i0
          }
        }

        # 1. Forecast context
        {
          ctx <- context_forecast_step(
            simulation_control = simulation_control,
            time_sec           = timestamps$time_sec,
            Main_df            = Main_df,
            parameters         = parameters
          )
          
          Main_df$Text_forec[simulation_control$indexes_global$idx_period]   <- ctx$forecast_df$Text_forec
          Main_df$SolarR_forec[simulation_control$indexes_global$idx_period] <- ctx$forecast_df$SolarR_forec

          rm(ctx)
        }
        
        # 2. Subset
        {
          period_chunk <- Main_df[simulation_control$indexes_global$idx_period, ]
          
          pilot_timestamps <- list(
            time_sec = timestamps$time_sec[simulation_control$indexes_global$idx_period]
          )
        }
        
        # 3. Run market
        {
          piloting_results <- run_market_process(
            prefix             = "Pilot",
            row_index          = CONT_003,
            period_chunk       = period_chunk,
            market_parameters  = market_parameters,
            simulation_control = simulation_control,
            timestamps         = pilot_timestamps,
            parameters         = parameters
          )
        }
        
        # 4. Integrate results (only _plan and _plan_flex columns)
        {
          inject_cols <- grep("(_plan$|_plan_flex$)", names(piloting_results), value = TRUE)
          Main_df[simulation_control$indexes_global$idx_ctrl, inject_cols] <- piloting_results[simulation_control$indexes_local$idx_ctrl, inject_cols]
          
          rm(
            period_chunk,
            pilot_timestamps, piloting_results, inject_cols
          )
        }
        
        # 5. Reset indexes
        {
          simulation_control$indexes_global$i0 <- 0
          simulation_control$indexes_global$i1 <- 0
          simulation_control$indexes_global$i_begin_horizon <- 0
          simulation_control$indexes_global$i_end_horizon <- 0
          simulation_control$indexes_global$i_end_control <- 0
          simulation_control$indexes_global$idx_period <-0
          simulation_control$indexes_global$idx_horizon <- 0
          simulation_control$indexes_global$idx_ctrl <- 0
          simulation_control$indexes_global$i_flex <-0
          
          simulation_control$indexes_local$i0 <- 0
          simulation_control$indexes_local$i1 <- 0
          simulation_control$indexes_local$i_begin_horizon <- 0
          simulation_control$indexes_local$i_end_horizon <- 0
          simulation_control$indexes_local$i_end_control <- 0
          simulation_control$indexes_local$idx_period <-0
          simulation_control$indexes_local$idx_horizon <- 0
          simulation_control$indexes_local$idx_ctrl <- 0
          simulation_control$indexes_local$i_flex <-0
        }
      }

      rm(market_parameters)
    }

    # =========================================================
    # 3. EXECUTION PROCESS (ALWAYS)
    # =========================================================
    {
      # 0 Get indexes
      {
        # Global indexes (relative to full Main_df)
        {
          simulation_control$indexes_global$i0              <- CONT_003
          simulation_control$indexes_global$i_begin_horizon <-simulation_control$indexes_global$i0
          simulation_control$indexes_global$i1              <- min(CONT_003 + 1L, simulation_control$indexes_global$n_steps)
          simulation_control$indexes_global$i_end_horizon   <- simulation_control$indexes_global$i1
          simulation_control$indexes_global$i_end_control   <- simulation_control$indexes_global$i1
          simulation_control$indexes_global$idx_period      <- simulation_control$indexes_global$i0:simulation_control$indexes_global$i_end_horizon
          simulation_control$indexes_global$idx_horizon     <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_horizon
          simulation_control$indexes_global$idx_ctrl        <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_control
          simulation_control$indexes_global$i_flex          <- simulation_control$indexes_global$i0
        }
        
        # Adapt to local indexes
        {
          simulation_control$indexes_local$i0              <- 1
          simulation_control$indexes_local$i1              <- simulation_control$indexes_global$i1              - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$i_begin_horizon <- simulation_control$indexes_global$i_begin_horizon - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$i_end_horizon   <- simulation_control$indexes_global$i_end_horizon   - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$i_end_control   <- simulation_control$indexes_global$i_end_control   - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$idx_period      <- simulation_control$indexes_global$idx_period      - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$idx_horizon     <- simulation_control$indexes_global$idx_horizon     - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$idx_ctrl        <- simulation_control$indexes_global$idx_ctrl        - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$i_flex          <- simulation_control$indexes_local$i0
        }
      }

      # 1. Forecast context
      # Not needed, we just use real context
      
      # 2. Subset
      {
        period_chunk <- Main_df[simulation_control$indexes_global$idx_period, ]
        
        timestamps$ctrl_periods <- sort(unique(Main_df$MarketUTC[simulation_control$indexes_global$idx_period]))
      }
      
      # 3. Run market
      {
        period_chunk <- implement_control_step(period_chunk        = period_chunk,
                                               simulation_control  = simulation_control,
                                               timestamps          = timestamps,
                                               parameters          = parameters,
                                               calculation_context = "execution"
        )
      }
      
      # 4. Integrate results (only execution columns, not _plan or _plan_flex)
      {
        exec_cols <- setdiff(
          names(period_chunk),
          grep("(_plan$|_plan_flex$)", names(period_chunk), value = TRUE)
        )
        Main_df[simulation_control$indexes_global$idx_ctrl, exec_cols] <- period_chunk[, exec_cols]
        
        rm(period_chunk, exec_cols)
      }

      # 5. Reset indexes
      {
        simulation_control$indexes_global$i0 <- 0
        simulation_control$indexes_global$i1 <- 0
        simulation_control$indexes_global$i_begin_horizon <- 0
        simulation_control$indexes_global$i_end_horizon <- 0
        simulation_control$indexes_global$i_end_control <- 0
        simulation_control$indexes_global$idx_period <-0
        simulation_control$indexes_global$idx_horizon <- 0
        simulation_control$indexes_global$idx_ctrl <- 0
        simulation_control$indexes_global$i_flex <-0
        
        simulation_control$indexes_local$i0 <- 0
        simulation_control$indexes_local$i1 <- 0
        simulation_control$indexes_local$i_begin_horizon <- 0
        simulation_control$indexes_local$i_end_horizon <- 0
        simulation_control$indexes_local$i_end_control <- 0
        simulation_control$indexes_local$idx_period <-0
        simulation_control$indexes_local$idx_horizon <- 0
        simulation_control$indexes_local$idx_ctrl <- 0
        simulation_control$indexes_local$i_flex <-0
      }
    }

    # =========================================================
    # Progress tracking
    # =========================================================
    {
      execution_time$t_elapsed <- as.numeric(difftime(Sys.time(), execution_time$t_begin, units = "secs"))
      execution_time$t_estimated_total <- execution_time$t_elapsed / CONT_003 * simulation_control$indexes_global$n_steps
      execution_time$t_remaining <- execution_time$t_estimated_total - execution_time$t_elapsed

      if (parameters$debug_and_config$verbose) {
        cat("Step", CONT_003,"/", simulation_control$indexes_global$n_steps, " completed. \n")
        cat("Elapsed time:", execution_time$t_elapsed, "Estimated remaining time:", execution_time$t_remaining, "\n")
        cat("======================================\n")
      }
    }
  }
}

rm(
  list = intersect(
    c(
      "simulation_control",
      "needed_cols",
      "CONT_003",
      "CONT_004",
      "timestamps",
      "market_parameter_fields",
      "inspection_step",
      "inspection_proc",
      "inspection_phase"
    ),
    ls()
  )
)

execution_time$t_end <- Sys.time()
execution_time$t_process <- as.numeric(difftime(execution_time$t_end, execution_time$t_begin, units = "secs"))

if (parameters$debug_and_config$verbose) {
  cat("Simulation ended at", format(execution_time$t_end), "\n")
  cat("Total time:", execution_time$t_process, "seconds\n")
}
