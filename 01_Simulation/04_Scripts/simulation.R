# -------------------------------------------------------------
# Script: simulation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This script implements the main MPC simulation loop.
# For each optimization timestep it performs:
#   0) INDICES:  calculate i0, i1, i_begin_horizon, i_end_horizon
#   1) CONTEXT:  obtain weather forecasts for interval [i0, i_end_horizon]
#   2) INITIALIZE: implement previous control strategy [i0, i_begin_horizon)
#   3) OPTIMIZATION: optimize between [i_begin_horizon, i_end_horizon]
#   4) IMPLEMENT: apply optimized control between [i0, min(i_end_control, i1)]
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
# 3. Compute auxiliary indexing variables
# 4. Main simulation loop:
#    4.0 Calculate timestep indices
#    4.1 Generate weather forecasts (CONTEXT)
#    4.2 Initialize optimization with previous control (INITIALIZE)
#    4.3 Optimize control strategy (OPTIMIZATION)
#    4.4 Apply optimized control (IMPLEMENT)
#    4.5 Track execution progress
# -------------------------------------------------------------
# Usage
# source(file.path("01_Simulation", "04_Scripts", "simulation.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by Main.R and Main_SCC.R after parameter loading.
# -------------------------------------------------------------
# functions/scripts called
# context_forecast_step(), implement_control_step(),
# optimize_control_step() from 01_Simulation/03_Functions/
# -------------------------------------------------------------

# Data frame formatting
{
  # Necessary columns - read from parameters (loaded from needed_cols.txt via Main.R)
  needed_cols <- parameters$needed_cols
  
  # Ensure all needed columns exist
  for (CONT_001 in needed_cols) {
    if (!CONT_001 %in% names(Main_df)) {
      Main_df[[CONT_001]] <- 0
    }
  }
  
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
    rm(CONT_002)
  }
  rm(numeric_cols)
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

# Auxiliary variables for indexing
{
  timestamps <- list()
  
  timestamps$time_sec <- as.numeric(Main_df$time)
  timestamps$t0       <- timestamps$time_sec[1]
  
  timestamps$optimization_frequency_sec    <- parameters$optimization$control_implementation_horizon    * 3600
  timestamps$optimization_horizon_sec      <- parameters$optimization$control_optimization_horizon      * 3600
  timestamps$optimization_anticipation_sec <- parameters$optimization$control_optimization_anticipation * 3600
  timestamps$optimization_timesteps        <- which((timestamps$time_sec - timestamps$t0) %%
                                                     timestamps$optimization_frequency_sec == 0)
  
  # Generate anticipated_optimization_timesteps
  timestamps$anticipated_optimization_timesteps <- sapply(timestamps$optimization_timesteps,
                                               function(idx) {
                                                 target_time <- timestamps$time_sec[idx] - timestamps$optimization_anticipation_sec
                                                 if (target_time < timestamps$t0) {
                                                   return(which.min(abs(timestamps$time_sec - timestamps$t0)))
                                                   } else {
                                                   return(which.min(abs(timestamps$time_sec - target_time)))
                                                   }
                                                 }
                                               )

  indexes<-list()
  indexes$n_steps <- length(timestamps$anticipated_optimization_timesteps)
  
  Main_df$MarketUTC <- as.POSIXct(floor(as.numeric(Main_df$time) / (parameters$optimization$market_resolution * 60)) *
                                  (parameters$optimization$market_resolution * 60),
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
    cat("Total timesteps:", indexes$n_steps, "\n" )
    cat("Period to be optimized:\n"               )
    cat("Begins ", format(min(Main_df$time)), "\n")
    cat("Ends "  , format(max(Main_df$time)), "\n")
    cat("======================================\n")
    cat("======================================\n")
  }
  
  for (CONT_003 in seq_len(indexes$n_steps)) {
    # =========================================================
    # 0. INDICES
    # =========================================================
    {
      # i0: start index based on anticipated_optimization_timesteps
      indexes$i0 <- timestamps$anticipated_optimization_timesteps[CONT_003]
      
      # i1: index of next anticipated_optimization_timesteps value
      if (CONT_003 < indexes$n_steps) {
        indexes$i1 <- timestamps$anticipated_optimization_timesteps[CONT_003 + 1]
      } else {
        indexes$i1 <- nrow(Main_df)
      }
      
      # i_begin_horizon: start index of optimization horizon (previously was i0)
      indexes$i_begin_horizon <- timestamps$optimization_timesteps[CONT_003]
      
      # i_end_horizon: end index of optimization horizon
      indexes$i_end_horizon <- max(which(timestamps$time_sec <= timestamps$time_sec[indexes$i_begin_horizon] + timestamps$optimization_horizon_sec))
      
      # i_end_control: end index of control
      indexes$i_end_control <- max(which(timestamps$time_sec <= timestamps$time_sec[indexes$i_begin_horizon] + timestamps$optimization_frequency_sec))
    }
    
    # =========================================================
    # 1. CONTEXT
    # =========================================================
    # forecasts weather
    # Obtain ctx for entire interval [i0, i_end_horizon]
    {
      ctx <- context_forecast_step(i0            = indexes$i0,
                                   time_sec      = timestamps$time_sec,
                                   Main_df       = Main_df,
                                   parameters    = parameters,
                                   i_end_horizon = indexes$i_end_horizon
      )
      
      # Integrate forecasts into Main_df
      idx_main <- match(ctx$forecast_df$time, Main_df$time)
      if (!all(is.na(idx_main))) {
        Main_df$Text_forec[idx_main]   <- ctx$forecast_df$Text_forec
        Main_df$SolarR_forec[idx_main] <- ctx$forecast_df$SolarR_forec
      }
      rm(ctx, idx_main)
    }
    
    # =========================================================
    # 2. INITIALIZE OPTIMIZATION
    # =========================================================
    # Implement previous control strategy between i0 and i_begin_horizon
    # Work on a cloned dataframe to avoid overwriting Main_df
    
    # Will only save the last row of the initialized period in Main_df to be used as initial condition for optimization
    # will save the values under "plan" columns to differentiate them from actual implementation values
    
    {
      if (indexes$i0 < indexes$i_begin_horizon) {
        # 1. Generate period_chunk directly as a subset of Main_df
        period_chunk <- data.frame(Main_df[indexes$i0:(indexes$i_begin_horizon), needed_cols])
        
        
        # 2 & 3. Check for valid setpoint values. 
        # If values are NA or 0, replace them directly with the default parameters.
        {
          # STP_heat_low_plan
          if ("STP_heat_low_plan" %in% colnames(period_chunk)) {
            period_chunk$STP_heat_low_plan[is.na(period_chunk$STP_heat_low_plan)] <- 
              parameters$control$set_point_default_heating - parameters$control$Deadband / 2
          }
          
          # STP_heat_high_plan
          if ("STP_heat_high_plan" %in% colnames(period_chunk)) {
            period_chunk$STP_heat_high_plan[is.na(period_chunk$STP_heat_high_plan)] <- 
              parameters$control$set_point_default_heating + parameters$control$Deadband / 2
          }
          
          # STP_cool_low_plan
          if ("STP_cool_low_plan" %in% colnames(period_chunk)) {
            period_chunk$STP_cool_low_plan[is.na(period_chunk$STP_cool_low_plan)] <- 
              parameters$control$set_point_default_cooling - parameters$control$Deadband / 2
          }
          
          # STP_cool_high_plan
          if ("STP_cool_high_plan" %in% colnames(period_chunk)) {
            period_chunk$STP_cool_high_plan[is.na(period_chunk$STP_cool_high_plan)] <- 
              parameters$control$set_point_default_cooling + parameters$control$Deadband / 2
          }
        }

        # Implement control for initialization on cloned dataframe
        period_chunk <- implement_control_step(period_chunk = period_chunk,
                                                    indexes = indexes,
                                                    timestamps = timestamps,
                                                    parameters = parameters,
                                                    calculation_mode = 1,
                                                    calculation_context = "plan"
                                                    )
        
        # Save only data from last timestep in _plan variables of Main_df
        {
          # Identify columns that end exactly with "_plan"
          # The "$" in the regular expression matches the end of the string,
          # ensuring that columns ending in "_plan_flex" are completely ignored.
          plan_cols <- grep("_plan$", names(period_chunk), value = TRUE)
          plan_cols <- plan_cols[plan_cols %in% needed_cols]
          Main_df[indexes$i_begin_horizon,plan_cols] <- period_chunk[nrow(period_chunk),plan_cols]
          rm(plan_cols)
        }
      }
    }
    
    # =========================================================
    # 3. OPTIMIZATION
    # =========================================================
    # Optimize between i_begin_horizon and i_end_horizon
    {
      # Optimization chunk (with integrated forecasts)
      period_chunk <- Main_df[indexes$i_begin_horizon:indexes$i_end_horizon, ]
      
      # Target periods
      timestamps$target_periods <- sort(unique(Main_df$MarketUTC[indexes$i_begin_horizon:indexes$i_end_horizon]))
      
      # Optimization
      period_chunk <- optimize_control_step(period_chunk = period_chunk,
                                            timestamps   = timestamps,
                                            parameters   = parameters,
                                            indexes      = indexes
                                            )$period_chunk

      # Inject updated optimization chunk back into Main_df
      Main_df[match(period_chunk$time, Main_df$time),
              needed_cols] <- period_chunk[, needed_cols]
      
      rm(period_chunk)
    }
    
    # =========================================================
    # 4. IMPLEMENT
    # =========================================================
    {
      # Implement between i0 and first to occur: i_end_control or i1
      indexes$i_impl_end <- min(indexes$i_end_control, indexes$i1)
      indexes$idx_ctrl   <- indexes$i0:indexes$i_impl_end
      
      # Use original data (not forecast)
      period_chunk <- Main_df[indexes$idx_ctrl, needed_cols]
      
      # Initialize set_point_actual for implementation with all timestamps from period_chunk_control
      timestamps$ctrl_periods          <- sort(unique(Main_df$MarketUTC[indexes$idx_ctrl]))
      
      # Note: optimization_frequency_sec parameter here represents the actual implementation
      # duration (time_sec[i_impl_end] - time_sec[i0]), not the optimization frequency
      period_chunk <- implement_control_step(period_chunk        = period_chunk,
                                             indexes             = indexes,
                                             timestamps          = timestamps,
                                             parameters          = parameters,
                                             calculation_mode    = 1,
                                             calculation_context = "execution"
                                             )
      
      # Inject updated implementation chunk back into Main_df
      Main_df[match(period_chunk$time, Main_df$time),
              needed_cols] <- period_chunk[, needed_cols]

      rm(period_chunk)
    }
    
    # =========================================================
    # Progress tracking
    # =========================================================
    {
      execution_time$t_elapsed <- as.numeric(difftime(Sys.time(), execution_time$t_begin, units = "secs"))
      execution_time$t_estimated_total <- execution_time$t_elapsed / CONT_003 * indexes$n_steps
      execution_time$t_remaining <- execution_time$t_estimated_total - execution_time$t_elapsed
      
      if (parameters$debug_and_config$verbose) {
        cat("Step", CONT_003,"/", indexes$n_steps, " completed. \n")
        cat("Elapsed time:", execution_time$t_elapsed, "Estimated remaining time:", execution_time$t_remaining, "\n")
        cat("======================================\n")
      }
    }
  }
}

rm(indexes, needed_cols, CONT_003)

execution_time$t_end <- Sys.time()
execution_time$t_process <- as.numeric(difftime(execution_time$t_end, execution_time$t_begin, units = "secs"))

if (parameters$debug_and_config$verbose) {
  cat("Simulation ended at", format(execution_time$t_end), "\n")
  cat("Total time:", execution_time$t_process, "seconds\n")
}
