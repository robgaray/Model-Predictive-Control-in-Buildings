# -------------------------------------------------------------
# Function: prepare_flexibility_prices.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Emulates the flexibility market when there is no real data for it:
# decides where and when flexibility events happen, and overwrites the
# flexibility price and probability columns of Main_df with generated
# values for them. Main.R calls it only when
# parameters$debug_and_config$Price_emulation == 1, so the events
# exist before any market can sell flexibility on them.
# -------------------------------------------------------------
# Columns overwritten in Main_df:
#   Flex_unit_cost_down_com  - flexibility commitment price (down), EUR/kWh
#   Flex_unit_cost_down_exec - flexibility execution price (down), EUR/kWh
#   Flex_unit_cost_up_com    - flexibility commitment price (up), EUR/kWh
#   Flex_unit_cost_up_exec   - flexibility execution price (up), EUR/kWh
#   Flex_Probab_down         - downward flexibility execution probability (0-1)
#   Flex_Probab_up           - upward flexibility execution probability (0-1)
#   Flex_Act                 - 1 for every row covered by an accepted
#                              flexibility event, 0 otherwise
# An event covers the rows whose market interval (MarketUTC) it
# spans, which are the rows whose time step falls inside it.
# -------------------------------------------------------------
# Two modes
# Both place the start and the duration of every event on slots of
# market$market_resolution.
#   Complex_Market_Config == "no" (basic): one independent candidate
#     per period and calendar day, placed anywhere in the day's
#     [0, 24 h) window by place_flex_candidate(), with these
#     parameters of market:
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
# The random numbers are drawn in a fixed order, so a run with a fixed
# seed generates the same events every time.
# -------------------------------------------------------------
# Inputs
#   Main_df                     : data frame. Must contain time,
#                                 MarketUTC and, in complex mode, the
#                                 Sched_*/Pilot_* market timeline
#                                 columns.
#   market                      : List, parameters$market:
#                                 - market_resolution
#                                 - Complex_Market_Config
#                                 - the Max_flex_* limits
#   flexibility_price_emulation : List,
#                                 parameters$flexibility_price_emulation.
#                                 Used in complex mode only.
#   computing                   : List, parameters$computing. Used in
#                                 complex mode only.
# -------------------------------------------------------------
# Outputs
#   Main_df, as received, with the flexibility price, probability and
#   activation columns overwritten with the generated values.
# -------------------------------------------------------------
# Code outline
# 1. Draw the flexibility events of the whole period, place each on
#    the calendar and write the resulting events into Main_df.
# -------------------------------------------------------------
# Usage instructions
# Main_df <- prepare_flexibility_prices(
#   Main_df                     = Main_df,
#   market                      = parameters$market,
#   flexibility_price_emulation = parameters$flexibility_price_emulation,
#   computing                   = parameters$computing
# )
# -------------------------------------------------------------
prepare_flexibility_prices <- function(Main_df,
                                       market,
                                       flexibility_price_emulation,
                                       computing
                                       ) {

  # -------------------------------------------------------------
  # 1. Draw and place the flexibility events
  # -------------------------------------------------------------
  {
    complex_market_config <- tolower(trimws(as.character(market$Complex_Market_Config)))

    if (complex_market_config == "yes") {

      # generate_flexibility_events is called to build the full
      # market-aware flexibility timeline (Scheduling echo + candidates,
      # Piloting exponential-decay candidates) and overwrite Main_df's
      # flexibility price/probability/activation columns with it. It
      # reads only the three parameter groups passed here.
      Main_df <- generate_flexibility_events(
        Main_df    = Main_df,
        parameters = list(
          market                      = market,
          flexibility_price_emulation = flexibility_price_emulation,
          computing                   = computing
        )
      )

    } else {

      market_resolution_sec <- market$market_resolution * 60

      Max_flex_periods_day     <- market$Max_flex_periods_day
      Max_flex_com_price       <- market$Max_flex_com_price
      Max_flex_exec_price      <- market$Max_flex_exec_price
      Max_flex_period_duration <- market$Max_flex_period_duration
      Max_flex_probability_down <- market$Max_flex_probability_down
      Max_flex_probability_up   <- market$Max_flex_probability_up

      time_num      <- as.numeric(Main_df$time)
      slot_num      <- as.numeric(Main_df$MarketUTC)
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
            candidate <- place_flex_candidate(
              available_segments    = day_segment,
              market_resolution_sec = market_resolution_sec,
              max_duration_hours    = Max_flex_period_duration
            )
            if (is.null(candidate)) next

            # The event covers the rows whose time step falls in it,
            # which are the rows of the market intervals it spans.
            rows <- which(slot_num >= candidate$t_start_sec &
                           slot_num <  candidate$t_start_sec + candidate$duration_sec)
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

      rm(list = c("market_resolution_sec", "Max_flex_periods_day",
                  "Max_flex_com_price", "Max_flex_exec_price",
                  "Max_flex_period_duration", "Max_flex_probability_down",
                  "Max_flex_probability_up", "time_num", "slot_num",
                  "Main_df_dates", "unique_days", "n_rows", "down_com",
                  "down_exec", "up_com", "up_exec", "probab_down", "probab_up",
                  "flex_act", "CONT_001", "day_idx", "day_start_sec",
                  "day_segment", "n_periods", "price_com", "price_exec",
                  "probab_val_down", "probab_val_up"))
      if (exists("CONT_002", inherits = FALSE)) rm(list = "CONT_002")
      if (exists("candidate", inherits = FALSE)) rm(list = "candidate")
      if (exists("rows", inherits = FALSE)) rm(list = "rows")
    }

    rm(list = "complex_market_config")
  }

  return(Main_df)
}
