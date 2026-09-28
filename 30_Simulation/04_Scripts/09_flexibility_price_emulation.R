# -------------------------------------------------------------
# Script: 09_flexibility_price_emulation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Emulates the flexibility market when there is no real data for it:
# decides where and when flexibility events happen, and overwrites the
# flexibility price and probability columns of Main_df with generated
# values for them. It is sourced from Main.R only when
# parameters$debug_and_config$Price_emulation == 1, the flag its name
# comes from.
# See 01_Agent_Comments/20260723_Plan_Generacion_Flexibilidad.md.
# -------------------------------------------------------------
# Columns overwritten in Main_df:
#   Flex_unit_cost_down_com  – flexibility commitment price (down), EUR/kWh
#   Flex_unit_cost_down_exec – flexibility execution price (down), EUR/kWh
#   Flex_unit_cost_up_com    – flexibility commitment price (up), EUR/kWh
#   Flex_unit_cost_up_exec   – flexibility execution price (up), EUR/kWh
#   Flex_Probab_down         – downward flexibility execution probability (0–1)
#   Flex_Probab_up           – upward flexibility execution probability (0–1)
#   Flex_Act                 – 1 for every row covered by an accepted
#                              flexibility event, 0 otherwise
# -------------------------------------------------------------
# Two modes
# Both place the start and the duration of every event on slots of
# parameters$market$market_resolution.
#   Complex_Market_Config == "no" (basic): one independent candidate
#     per period and calendar day, placed anywhere in the day's
#     [0, 24 h) window by place_flex_candidate(), with these
#     parameters of parameters$market:
#       - Max_flex_periods_day
#       - Max_flex_com_price
#       - Max_flex_exec_price
#       - Max_flex_period_duration
#       - Max_flex_probability_down
#       - Max_flex_probability_up
#   Complex_Market_Config == "yes" (market-aware): delegates to
#     generate_flexibility_events(), whose header describes the full
#     algorithm:
#       - Scheduling echo and candidates
#       - Piloting candidates with exponential decay
# -------------------------------------------------------------
# Inputs
# Main_df    : Data frame. Must contain time and, in complex mode, the
#              Sched_*/Pilot_* market timeline columns.
# parameters : List. Uses:
#                - parameters$market: market_resolution,
#                  Complex_Market_Config and the Max_flex_* limits
#                - parameters$flexibility_price_emulation, in complex mode
# -------------------------------------------------------------
# Outputs
# Main_df : Data frame. Updated with generated flexibility price columns.
# -------------------------------------------------------------
# Usage instructions
# source(file.path("30_Simulation", "04_Scripts", "09_flexibility_price_emulation.R"))
#   Not called: sourced by Main.R before the simulation loop, so the
#   events exist before any market can sell flexibility on them.
# -------------------------------------------------------------
# Where this function/script is used
# Sourced by 30_Simulation/Main.R (step 10) when Price_emulation == 1.
# -------------------------------------------------------------
# functions/scripts called
# From 30_Simulation/03_Functions/:
#   - place_flex_candidate() (basic mode)
#   - generate_flexibility_events() (complex mode)
# -------------------------------------------------------------
# Code outline
# 1. Draw the flexibility events of the whole period.
# 2. Place each drawn event on the calendar, on the segments its
#    day leaves free.
# 3. Write the resulting events into Main_df.
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
    Max_flex_probability_down <- parameters$market$Max_flex_probability_down
    Max_flex_probability_up   <- parameters$market$Max_flex_probability_up

    time_num      <- as.numeric(Main_df$time)
    Main_df_dates <- as.Date(Main_df$time)
    unique_days   <- unique(Main_df_dates)

    n_rows    <- nrow(Main_df)
    down_com  <- rep(0, n_rows)
    down_exec <- rep(0, n_rows)
    up_com    <- rep(0, n_rows)
    up_exec   <- rep(0, n_rows)
    probab_down <- rep(0, n_rows)
    probab_up   <- rep(0, n_rows)
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
      probab_val_down <- runif(1) * Max_flex_probability_down
      probab_val_up   <- runif(1) * Max_flex_probability_up

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
          probab_down[rows] <- probab_val_down
          probab_up[rows]   <- probab_val_up
          flex_act[rows]  <- 1
        }
      }
    }

    Main_df$Flex_unit_cost_down_com  <- down_com
    Main_df$Flex_unit_cost_down_exec <- down_exec
    Main_df$Flex_unit_cost_up_com    <- up_com
    Main_df$Flex_unit_cost_up_exec   <- up_exec
    Main_df$Flex_Probab_down         <- probab_down
    Main_df$Flex_Probab_up           <- probab_up
    Main_df$Flex_Act                 <- flex_act

    rm(market_resolution_sec, Max_flex_periods_day, Max_flex_com_price, Max_flex_exec_price,
       Max_flex_period_duration, Max_flex_probability_down, Max_flex_probability_up,
       time_num, Main_df_dates, unique_days,
       n_rows, down_com, down_exec, up_com, up_exec, probab_down, probab_up, flex_act,
       CONT_001, day_idx, day_start_sec, day_segment, n_periods, price_com, price_exec,
       probab_val_down, probab_val_up)
    if (exists("CONT_002")) rm(CONT_002)
    if (exists("candidate")) rm(candidate)
    if (exists("rows")) rm(rows)
  }

  rm(complex_market_config)

  cat("Flexibility generation completed\n")
}
