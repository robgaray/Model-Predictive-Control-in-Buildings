# -------------------------------------------------------------
# Function: build_market_timeline.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds the market timeline (bid time, period begin/end,
# optimization horizon, aim) for one market role (Scheduling or
# Piloting) and writes it into the role's Sched_*/Pilot_* columns of
# Main_df. Supports two modes:
#   - Basic  (complex_market_config == "no")  : deterministic market
#     timeline from the role's optimisation horizon parameters.
#   - Complex (complex_market_config == "yes") : timeline built from
#     the role's market-config table. The optimization horizon is
#     computed from end_optimization.
# This is the logic shared by the Scheduling and Piloting blocks of
# prepare_market_calendar(), parametrized by role.
# Every time is clipped to the simulation range. A market whose
# control period is left with no length, because it falls at the
# edge of the simulation or outside it, controls no time step and
# trades nothing, so it is not placed.
# -------------------------------------------------------------
# Inputs
# role                   : Character. Column prefix for this market
#                          role, "Sched" or "Pilot".
# config_table           : Data frame. The role's market config table
#                          (parameters$market_config_scheduling or
#                          parameters$market_config_piloting), used
#                          only when complex_market_config == "yes".
# implementation_horizon : Numeric (hours). The role's
#                          Implementation_horizon_scheduling/piloting.
# optimization_horizon   : Numeric (hours). The role's
#                          Optimization_horizon_scheduling/piloting.
# anticipation           : Numeric (hours). The role's
#                          Anticipation_scheduling/piloting.
# optimization_aim       : Character. The role's
#                          optimization_aim_scheduling/piloting, already
#                          resolved by map_optimization_aim() to
#                          "energy"/"flexibility" (Scheduling) or
#                          "operation"/"operationflex" (Piloting).
# aim_label_energy       : Character. Market_Aim label used in basic
#                          mode when optimization_aim is neither
#                          "flexibility" nor "operationflex" ("E" for
#                          Scheduling, "O" for Piloting).
# aim_label_flex         : Character. Market_Aim label used in basic
#                          mode when optimization_aim is "flexibility"
#                          (Scheduling) or "operationflex" (Piloting)
#                          ("E+F" for Scheduling, "O+F" for Piloting).
# complex_market_config  : Character. "yes" or "no" (already validated
#                          by the caller).
# time_min, time_max     : POSIXct scalars. Main_df$time range.
# Main_df                : Data frame. The main simulation data frame.
# -------------------------------------------------------------
# Outputs
# Main_df : Data frame. Updated with the role's
#           <role>_Market_Name/Bid_time/Period_Begin/Period_End/
#           Optimization_Horizon/Market_Aim columns.
# -------------------------------------------------------------
# Code outline
# 1. Build the role's market timeline (basic or complex mode)
# 2. Leave out the markets whose control period has no length
# 3. Write the timeline into Main_df at each market's bid time
# -------------------------------------------------------------
# Usage instructions
# Main_df <- build_market_timeline(
#   role                   = "Sched",
#   config_table           = parameters$market_config_scheduling,
#   implementation_horizon =
#     parameters$market$Implementation_horizon_scheduling,
#   optimization_horizon   = parameters$market$Optimization_horizon_scheduling,
#   anticipation           = parameters$market$Anticipation_scheduling,
#   optimization_aim       = parameters$market$optimization_aim_scheduling,
#   aim_label_energy       = "E",
#   aim_label_flex         = "E+F",
#   complex_market_config  = complex_market_config,
#   time_min               = time_min,
#   time_max               = time_max,
#   Main_df                = Main_df
# )
# -------------------------------------------------------------

build_market_timeline <- function(role,
                                  config_table,
                                  implementation_horizon,
                                  optimization_horizon,
                                  anticipation,
                                  optimization_aim,
                                  aim_label_energy,
                                  aim_label_flex,
                                  complex_market_config,
                                  time_min,
                                  time_max,
                                  Main_df) {

  # 1. Build the role's market timeline (basic or complex mode)
  {
    if (complex_market_config == "no") {
      begin_seq <- seq(
        from = time_min,
        to   = time_max,
        by   = implementation_horizon * 3600
      )

      markets_in_time <- data.frame(
        Market_Name          = rep("Basic_Market", length(begin_seq)),
        Market_Bid_time      = as.POSIXct(begin_seq, origin = "1970-01-01", tz = "UTC"),
        Market_Period_Begin  = as.POSIXct(begin_seq, origin = "1970-01-01", tz = "UTC"),
        Market_Period_End    = as.POSIXct(begin_seq, origin = "1970-01-01", tz = "UTC"),
        Optimization_Horizon = as.POSIXct(begin_seq, origin = "1970-01-01", tz = "UTC"),
        Market_Aim           = rep(aim_label_energy, length(begin_seq)),
        stringsAsFactors     = FALSE
      )

      markets_in_time$Market_Period_End <- markets_in_time$Market_Period_Begin +
        implementation_horizon * 3600
      markets_in_time$Optimization_Horizon <- markets_in_time$Market_Period_Begin +
        optimization_horizon * 3600
      markets_in_time$Market_Bid_time <- markets_in_time$Market_Period_Begin -
        anticipation * 3600

      markets_in_time$Market_Bid_time <- pmin(pmax(markets_in_time$Market_Bid_time, time_min), time_max)
      markets_in_time$Market_Period_Begin <- pmin(pmax(markets_in_time$Market_Period_Begin, time_min), time_max)
      markets_in_time$Market_Period_End <- pmin(pmax(markets_in_time$Market_Period_End, time_min), time_max)
      markets_in_time$Optimization_Horizon <- pmin(pmax(markets_in_time$Optimization_Horizon, time_min), time_max)

      if (optimization_aim %in% c("flexibility", "operationflex")) {
        markets_in_time$Market_Aim <- aim_label_flex
      } else {
        markets_in_time$Market_Aim <- aim_label_energy
      }

      rm(list = "begin_seq")

    } else {
      markets_in_time <- data.frame(
        Market_Name          = character(0),
        Market_Bid_time      = as.POSIXct(character(0), tz = "UTC"),
        Market_Period_Begin  = as.POSIXct(character(0), tz = "UTC"),
        Market_Period_End    = as.POSIXct(character(0), tz = "UTC"),
        Optimization_Horizon = as.POSIXct(character(0), tz = "UTC"),
        Market_Aim           = character(0),
        stringsAsFactors     = FALSE
      )

      time_min_day  <- as.POSIXct(trunc(time_min, "days"), tz = "UTC")
      time_max_day  <- as.POSIXct(trunc(time_max, "days"), tz = "UTC")
      days_sequence <- seq(from = time_min_day, to = time_max_day, by = "1 day")

      for (CONT_001 in seq_len(nrow(config_table))) {
        market_name      <- as.character(config_table$Market[CONT_001])
        begin_hour       <- as.numeric(config_table$begin[CONT_001])
        closure_hour     <- as.numeric(config_table$closure[CONT_001])
        end_hour         <- as.numeric(config_table$end[CONT_001])
        end_optimization <- as.numeric(config_table$end_optimization[CONT_001])
        market_aim       <- as.character(config_table$aim[CONT_001])

        market_period_begin_seq  <- days_sequence + begin_hour * 3600
        market_period_end_seq    <- market_period_begin_seq + end_hour * 3600
        optimization_horizon_seq <- market_period_end_seq + end_optimization * 3600
        market_bid_time_seq      <- market_period_begin_seq - closure_hour * 3600

        market_bid_time_seq      <- pmin(pmax(market_bid_time_seq, time_min), time_max)
        market_period_begin_seq  <- pmin(pmax(market_period_begin_seq, time_min), time_max)
        market_period_end_seq    <- pmin(pmax(market_period_end_seq, time_min), time_max)
        optimization_horizon_seq <- pmin(pmax(optimization_horizon_seq, time_min), time_max)

        new_rows <- data.frame(
          Market_Name          = rep(market_name, length(market_period_begin_seq)),
          Market_Bid_time      = market_bid_time_seq,
          Market_Period_Begin  = market_period_begin_seq,
          Market_Period_End    = market_period_end_seq,
          Optimization_Horizon = optimization_horizon_seq,
          Market_Aim           = rep(market_aim, length(market_period_begin_seq)),
          stringsAsFactors     = FALSE
        )

        markets_in_time <- rbind(markets_in_time, new_rows)
      }
      rm(list = c("CONT_001", "market_name", "begin_hour", "closure_hour",
                  "end_hour", "end_optimization", "market_aim",
                  "market_period_begin_seq", "market_period_end_seq",
                  "optimization_horizon_seq", "market_bid_time_seq", "new_rows",
                  "time_min_day", "time_max_day", "days_sequence"))
    }
  }

  # 2. Leave out the markets whose control period has no length
  # A row holds the energy of the time step that ends at it, so a
  # market controls the time steps after Period_Begin up to
  # Period_End. When clipping leaves both at the same instant, there
  # is no time step to control.
  {
    has_length <- markets_in_time$Market_Period_End >
      markets_in_time$Market_Period_Begin
    markets_in_time <- markets_in_time[has_length, , drop = FALSE]
    rm(list = "has_length")
  }

  # 3. Write the timeline into Main_df at each market's bid time
  {
    name_col     <- paste0(role, "_Market_Name")
    bid_time_col <- paste0(role, "_Market_Bid_time")
    period_begin_col <- paste0(role, "_Market_Period_Begin")
    period_end_col   <- paste0(role, "_Market_Period_End")
    horizon_col      <- paste0(role, "_Optimization_Horizon")
    aim_col          <- paste0(role, "_Market_Aim")

    for (CONT_002 in seq_len(nrow(markets_in_time))) {
      idx <- which(Main_df$time == markets_in_time$Market_Bid_time[CONT_002])
      if (length(idx) == 0) {
        warning(
          role, " market '", markets_in_time$Market_Name[CONT_002],
          "' bid time not found in Main_df$time: ",
          format(markets_in_time$Market_Bid_time[CONT_002], "%Y-%m-%d %H:%M:%S"),
          " - this market event is skipped.",
          call. = FALSE
        )
        next
      }
      Main_df[[name_col]][idx]         <- markets_in_time$Market_Name[CONT_002]
      Main_df[[bid_time_col]][idx]     <- format(markets_in_time$Market_Bid_time[CONT_002], "%Y-%m-%d %H:%M:%S")
      Main_df[[period_begin_col]][idx] <- format(markets_in_time$Market_Period_Begin[CONT_002], "%Y-%m-%d %H:%M:%S")
      Main_df[[period_end_col]][idx]   <- format(markets_in_time$Market_Period_End[CONT_002], "%Y-%m-%d %H:%M:%S")
      Main_df[[horizon_col]][idx]      <- format(markets_in_time$Optimization_Horizon[CONT_002], "%Y-%m-%d %H:%M:%S")
      Main_df[[aim_col]][idx]          <- markets_in_time$Market_Aim[CONT_002]
    }

    rm(list = c("name_col", "bid_time_col", "period_begin_col",
                "period_end_col", "horizon_col", "aim_col", "CONT_002", "idx",
                "markets_in_time"))
  }

  return(Main_df)
}
