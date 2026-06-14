# -------------------------------------------------------------
# Script: price_emulation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This script overwrites the flexibility price columns in Main_df with
# randomly generated values based on the parameters in 20_Flex_price_simulation.csv.
# It is sourced from Main.R and Main_SCC.R only when
#   parameters$debug_and_config$Price_emulation == 1
# -------------------------------------------------------------
# Columns overwritten in Main_df:
#   Flex_unit_cost_down_com  – flexibility commitment price (down), EUR/kWh
#   Flex_unit_cost_down_exec – flexibility execution price (down), EUR/kWh
#   Flex_unit_cost_up_com    – flexibility commitment price (up), EUR/kWh
#   Flex_unit_cost_up_exec   – flexibility execution price (up), EUR/kWh
#   Flex_Probab              – flexibility execution probability (0–1)
# -------------------------------------------------------------
# Algorithm (per simulation day):
#   1. Draw random parameters:
#      - Flex_periods       = round(U[0,1] * Max_flex_periods_day)
#      - Flex_price_com     = U[0,1] * Max_flex_com_price
#      - Flex_price_exec    = U[0,1] * Max_flex_exec_price
#      - Flex_period_duration[p]
#                           = U[0,1] * Max_flex_period_duration (one per period)
#      - Flex_period_init_time[p]: derived from Flex_periods+1 uniform randoms so
#                                  that init times span [0, 24)
#      - Flex_Probab        = U[0,1] * Max_flex_probability
#   2. Build per-timestep scaling signal (0/1):
#      signal = 0 by default; set to 1 for each timestep whose hour-of-day
#      falls within [init_time[p], init_time[p] + duration[p]) for any period p
#   3. Write to Main_df:
#      - Flex_unit_cost_*_com/_exec
#                           = price_value * signal   (scaled by signal)
#      - Flex_Probab        = Flex_Probab_val        (constant per day)
# -------------------------------------------------------------
# Inputs
# Main_df : Data frame. Must contain time column.
# paths$flex_price_sim_file : Character. Path to 20_Flex_price_simulation.csv.
# -------------------------------------------------------------
# Outputs
# Main_df : Data frame. Updated with randomized flexibility price columns.
# -------------------------------------------------------------
# Code outline
# 1. Load flex price simulation parameters from CSV
# 2. For each simulation day:
#    2.1 Generate random daily flex parameters
#    2.2 Build per-timestep scaling signal
#    2.3 Write scaled prices to Main_df
# 3. Clean up temporary variables
# -------------------------------------------------------------
# Usage
# source(file.path("30_Simulation", "04_Scripts", "price_emulation.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by Main.R and Main_SCC.R when Price_emulation == 1.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

{
  # Load flex price simulation parameters
  flex_params              <- read.csv(paths$flex_price_sim_file,
                                       comment.char = "#",
                                       strip.white = TRUE,
                                       stringsAsFactors = FALSE)
  flex_values              <- as.list(flex_params$value)
  names(flex_values)       <- trimws(flex_params$parameter)
  flex_values              <- lapply(flex_values, function(x) as.numeric(trimws(as.character(x))))
  
  Max_flex_periods_day     <- flex_values$Max_flex_periods_day
  Max_flex_com_price       <- flex_values$Max_flex_com_price
  Max_flex_exec_price      <- flex_values$Max_flex_exec_price
  Max_flex_period_duration <- flex_values$Max_flex_period_duration
  Max_flex_probability     <- flex_values$Max_flex_probability
  
  rm(flex_params, flex_values)
  
  # Extract hour-of-day (decimal) for every timestep in Main_df
  Main_df_hours           <- as.numeric(format(Main_df$time, "%H")) +
                             as.numeric(format(Main_df$time, "%M")) / 60
  
  # Get unique simulation dates
  Main_df_dates <- as.Date(Main_df$time)
  unique_days   <- unique(Main_df_dates)
  
  for (CONT_001 in unique_days) {
    CONT_001  <- as.Date(CONT_001, origin = "1970-01-01")
    day_idx   <- which(Main_df_dates == CONT_001)
    n_steps   <- length(day_idx)
    if (n_steps == 0) next
    
    hours_of_day <- Main_df_hours[day_idx]
    
    # ---- Step 1: generate random daily parameters ----
    Flex_periods <- round(runif(1) * Max_flex_periods_day)
    
    # Same random draw for up and down commitment prices
    Flex_price_com  <- runif(1) * Max_flex_com_price
    # Same random draw for up and down execution prices
    Flex_price_exec <- runif(1) * Max_flex_exec_price
    
    Flex_Probab_val <- runif(1) * Max_flex_probability
    
    if (Flex_periods > 0) {
      # One duration per period
      Flex_period_duration <- runif(Flex_periods) * Max_flex_period_duration
      
      # Init times via Dirichlet-like split of the 24 h window:
      # generate Flex_periods+1 uniforms; cumulative sum / total gives proportions
      init_randoms       <- runif(Flex_periods + 1)
      sum_init_randoms   <- sum(init_randoms)
      cumsum_init_randoms <- cumsum(init_randoms)
      Flex_period_init_time <- 24 * cumsum_init_randoms[seq_len(Flex_periods)] /
                                    sum_init_randoms
      rm(init_randoms, sum_init_randoms, cumsum_init_randoms)
    }
    
    # ---- Step 2: build per-timestep scaling signal ----
    scaling_signal <- rep(0L, n_steps)
    
    if (Flex_periods > 0) {
      for (CONT_002 in seq_len(Flex_periods)) {
        t_start <- Flex_period_init_time[CONT_002]
        t_end   <- t_start + Flex_period_duration[CONT_002]
        scaling_signal[hours_of_day >= t_start & hours_of_day < t_end] <- 1L
      }
    }
    
    # ---- Step 3: write scaled prices to Main_df ----
    Main_df$Flex_unit_cost_down_com[day_idx]  <- Flex_price_com  * scaling_signal
    Main_df$Flex_unit_cost_down_exec[day_idx] <- Flex_price_exec * scaling_signal
    Main_df$Flex_unit_cost_up_com[day_idx]    <- Flex_price_com  * scaling_signal
    Main_df$Flex_unit_cost_up_exec[day_idx]   <- Flex_price_exec * scaling_signal
    
    # ---- Step 4: write Flex_Probab directly (constant per day) ----
    Main_df$Flex_Probab[day_idx] <- Flex_Probab_val
  }
  
  # Clean up
  rm(Max_flex_periods_day, Max_flex_com_price, Max_flex_exec_price,
     Max_flex_period_duration, Max_flex_probability,
     Main_df_hours, Main_df_dates, unique_days,
     CONT_001, day_idx, n_steps, hours_of_day,
     Flex_periods, Flex_price_com, Flex_price_exec, Flex_Probab_val,
     scaling_signal)
  if (exists("Flex_period_duration"))  rm(Flex_period_duration)
  if (exists("Flex_period_init_time")) rm(Flex_period_init_time)
  if (exists("CONT_002"))                     rm(CONT_002)
  if (exists("t_start"))               rm(t_start)
  if (exists("t_end"))                 rm(t_end)
  
  cat("Price emulation completed\n")
}
