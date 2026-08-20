# -------------------------------------------------------------
# Script: flexibility_generation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overwrites the flexibility price columns in Main_df with generated
# values. Replaces the former price_emulation.R (renamed to reflect
# its widened scope: it no longer just emulates prices, it also
# decides where/when flexibility events happen). It is sourced from
# Main.R only when parameters$debug_and_config$Price_emulation == 1.
# See 01_Agent_Comments/20260723_Plan_Generacion_Flexibilidad.md.
# -------------------------------------------------------------
# Columns overwritten in Main_df:
#   Flex_unit_cost_down_com  – flexibility commitment price (down), EUR/kWh
#   Flex_unit_cost_down_exec – flexibility execution price (down), EUR/kWh
#   Flex_unit_cost_up_com    – flexibility commitment price (up), EUR/kWh
#   Flex_unit_cost_up_exec   – flexibility execution price (up), EUR/kWh
#   Flex_Probab              – flexibility execution probability (0–1)
#   Flex_Act                 – 1 for every row covered by an accepted
#                              flexibility event, 0 otherwise
# -------------------------------------------------------------
# Two modes, both discretizing event start/duration to slots of
# parameters$market$market_resolution (Parte B.0 of the plan document
# above - "en todos los casos"):
#   - Complex_Market_Config == "no" (basic): one independent candidate
#     per period per calendar day (same Max_flex_periods_day/
#     Max_flex_com_price/Max_flex_exec_price/Max_flex_period_duration/
#     Max_flex_probability parameters as before, now read from
#     parameters$market instead of a standalone CSV), placed anywhere
#     in the day's [0, 24h) window via place_flex_candidate() - no
#     longer a continuous Dirichlet-style split, see Parte D.4.
#   - Complex_Market_Config == "yes" (market-aware): delegates to
#     generate_flexibility_events() - see that function's header for
#     the full algorithm (Scheduling echo + candidates, Piloting
#     exponential-decay candidates).
# -------------------------------------------------------------
# Inputs
# Main_df    : Data frame. Must contain time and, in complex mode, the
#              Sched_*/Pilot_* market timeline columns.
# parameters : List. Uses parameters$market (market_resolution,
#              Complex_Market_Config, Max_flex_*) and, in complex mode,
#              parameters$flexibility_generation.
# -------------------------------------------------------------
# Outputs
# Main_df : Data frame. Updated with generated flexibility price columns.
# -------------------------------------------------------------
# Usage
# source(file.path("30_Simulation", "04_Scripts", "flexibility_generation.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by Main.R when Price_emulation == 1.
# -------------------------------------------------------------
# functions/scripts called
#   place_flex_candidate() (basic mode), generate_flexibility_events()
#   (complex mode) -- from 30_Simulation/03_Functions/
# -------------------------------------------------------------

{
  complex_market_config <- tolower(trimws(as.character(parameters$market$Complex_Market_Config)))

  if (complex_market_config == "yes") {

    # generate_flexibility_events is called to build the full
    # market-aware flexibility timeline (Scheduling echo + candidates,
    # Piloting exponential-decay candidates) and overwrite Main_df's
    # flexibility price/probability/activation columns with it.
    Main_df <- generate_flexibility_events(Main_df, parameters)

  } else {

    market_resolution_sec <- parameters$market$market_resolution * 60

    Max_flex_periods_day     <- parameters$market$Max_flex_periods_day
    Max_flex_com_price       <- parameters$market$Max_flex_com_price
    Max_flex_exec_price      <- parameters$market$Max_flex_exec_price
    Max_flex_period_duration <- parameters$market$Max_flex_period_duration
    Max_flex_probability     <- parameters$market$Max_flex_probability

    time_num      <- as.numeric(Main_df$time)
    Main_df_dates <- as.Date(Main_df$time)
    unique_days   <- unique(Main_df_dates)

    n_rows    <- nrow(Main_df)
    down_com  <- rep(0, n_rows)
    down_exec <- rep(0, n_rows)
    up_com    <- rep(0, n_rows)
    up_exec   <- rep(0, n_rows)
    probab    <- rep(0, n_rows)
    flex_act  <- rep(0, n_rows)

    for (CONT_001 in unique_days) {
      CONT_001 <- as.Date(CONT_001, origin = "1970-01-01")
      day_idx  <- which(Main_df_dates == CONT_001)
      if (length(day_idx) == 0) next

      day_start_sec <- min(time_num[day_idx])
      day_segment   <- data.frame(start = day_start_sec, end = day_start_sec + 24 * 3600)

      n_periods  <- round(runif(1) * Max_flex_periods_day)
      price_com  <- runif(1) * Max_flex_com_price
      price_exec <- runif(1) * Max_flex_exec_price
      probab_val <- runif(1) * Max_flex_probability

      if (n_periods > 0) {
        for (CONT_002 in seq_len(n_periods)) {
          # place_flex_candidate is called to draw a single random
          # flexibility candidate (start/duration, discretized to
          # market_resolution slots) within the current day's window.
          candidate <- place_flex_candidate(day_segment, market_resolution_sec, Max_flex_period_duration)
          if (is.null(candidate)) next

          rows <- which(time_num >= candidate$t_start_sec &
                         time_num <  candidate$t_start_sec + candidate$duration_sec)
          if (length(rows) == 0) next

          down_com[rows]  <- price_com
          down_exec[rows] <- price_exec
          up_com[rows]    <- price_com
          up_exec[rows]   <- price_exec
          probab[rows]    <- probab_val
          flex_act[rows]  <- 1
        }
      }
    }

    Main_df$Flex_unit_cost_down_com  <- down_com
    Main_df$Flex_unit_cost_down_exec <- down_exec
    Main_df$Flex_unit_cost_up_com    <- up_com
    Main_df$Flex_unit_cost_up_exec   <- up_exec
    Main_df$Flex_Probab              <- probab
    Main_df$Flex_Act                 <- flex_act

    rm(market_resolution_sec, Max_flex_periods_day, Max_flex_com_price, Max_flex_exec_price,
       Max_flex_period_duration, Max_flex_probability, time_num, Main_df_dates, unique_days,
       n_rows, down_com, down_exec, up_com, up_exec, probab, flex_act,
       CONT_001, day_idx, day_start_sec, day_segment, n_periods, price_com, price_exec, probab_val)
    if (exists("CONT_002")) rm(CONT_002)
    if (exists("candidate")) rm(candidate)
    if (exists("rows")) rm(rows)
  }

  rm(complex_market_config)

  cat("Flexibility generation completed\n")
}
