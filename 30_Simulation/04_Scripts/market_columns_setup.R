# -------------------------------------------------------------
# Script: market_columns_setup.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK5
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Initialises and populates the Sched_* and Pilot_* market
# columns in Main_df using the already-loaded parameters
# (parameters$market, parameters$market_config_scheduling,
# parameters$market_config_piloting).
# Supports two modes:
#   - Basic  (Complex_Market_Config == "no") : deterministic
#     market timeline from optimisation horizons.
#   - Complex (Complex_Market_Config == "yes") : timeline built
#     from the market-config tables. In complex mode, the
#     optimization horizon is computed from end_optimization.
# Sourced from Main.R and Main_SCC.R after price emulation.
# -------------------------------------------------------------

# -----------------------------------------------------------
# Initialise / overwrite market columns in Main_df
# -----------------------------------------------------------
{
  market_cols <- c(
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

  for (CONT_001 in market_cols) {
    Main_df[[CONT_001]] <- 0
  }
  rm(market_cols, CONT_001)
}

# -----------------------------------------------------------
# Configure Scheduling market values based on Complex_Market_Config
# -----------------------------------------------------------
{
  complex_market_config <- "no"
  if (!is.null(parameters$market$Complex_Market_Config)) {
    complex_market_config <- tolower(trimws(as.character(parameters$market$Complex_Market_Config)))
  }

  if (!complex_market_config %in% c("yes", "no")) {
    stop("Complex_Market_Config must be 'yes' or 'no'")
  }

  time_min <- min(Main_df$time)
  time_max <- max(Main_df$time)

  if (complex_market_config == "no") {
    begin_seq <- seq(
      from = time_min,
      to   = time_max,
      by   = parameters$market$Implementation_horizon_scheduling * 3600
    )

    Sched_markets_in_time <- data.frame(
      Market_Name          = rep("Basic_Market", length(begin_seq)),
      Market_Bid_time      = as.POSIXct(begin_seq, origin = "1970-01-01", tz = "UTC"),
      Market_Period_Begin  = as.POSIXct(begin_seq, origin = "1970-01-01", tz = "UTC"),
      Market_Period_End    = as.POSIXct(begin_seq, origin = "1970-01-01", tz = "UTC"),
      Optimization_Horizon = as.POSIXct(begin_seq, origin = "1970-01-01", tz = "UTC"),
      Market_Aim           = rep("E", length(begin_seq)),
      stringsAsFactors     = FALSE
    )

    Sched_markets_in_time$Market_Period_End <- Sched_markets_in_time$Market_Period_Begin +
      parameters$market$Implementation_horizon_scheduling * 3600
    Sched_markets_in_time$Optimization_Horizon <- Sched_markets_in_time$Market_Period_Begin +
      parameters$market$Optimization_horizon_scheduling * 3600
    Sched_markets_in_time$Market_Bid_time <- Sched_markets_in_time$Market_Period_Begin -
      parameters$market$Anticipation_scheduling * 3600

    Sched_markets_in_time$Market_Bid_time <- pmin(pmax(Sched_markets_in_time$Market_Bid_time, time_min), time_max)
    Sched_markets_in_time$Market_Period_Begin <- pmin(pmax(Sched_markets_in_time$Market_Period_Begin, time_min), time_max)
    Sched_markets_in_time$Market_Period_End <- pmin(pmax(Sched_markets_in_time$Market_Period_End, time_min), time_max)
    Sched_markets_in_time$Optimization_Horizon <- pmin(pmax(Sched_markets_in_time$Optimization_Horizon, time_min), time_max)

    optimization_aim <- parameters$market$optimization_aim_scheduling
    if (optimization_aim == "flexibility") {
      Sched_markets_in_time$Market_Aim <- "E+F"
    } else {
      Sched_markets_in_time$Market_Aim <- "E"
    }
    rm(optimization_aim)

  } else {
    Sched_markets_in_time <- data.frame(
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

    for (CONT_003 in seq_len(nrow(parameters$market_config_scheduling))) {
      market_name      <- as.character(parameters$market_config_scheduling$Market[CONT_003])
      begin_hour       <- as.numeric(parameters$market_config_scheduling$begin[CONT_003])
      closure_hour     <- as.numeric(parameters$market_config_scheduling$closure[CONT_003])
      end_hour         <- as.numeric(parameters$market_config_scheduling$end[CONT_003])
      end_optimization <- as.numeric(parameters$market_config_scheduling$end_optimization[CONT_003])
      market_aim       <- as.character(parameters$market_config_scheduling$aim[CONT_003])

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

      Sched_markets_in_time <- rbind(Sched_markets_in_time, new_rows)
    }
    rm(CONT_003, market_name, begin_hour, closure_hour, end_hour, end_optimization, market_aim,
       market_period_begin_seq, market_period_end_seq, optimization_horizon_seq,
       market_bid_time_seq, new_rows, time_min_day, time_max_day, days_sequence)
  }

  for (CONT_002 in seq_len(nrow(Sched_markets_in_time))) {
    idx <- which(Main_df$time == Sched_markets_in_time$Market_Bid_time[CONT_002])
    if (length(idx) == 0) next
    Main_df$Sched_Market_Name[idx]          <- Sched_markets_in_time$Market_Name[CONT_002]
    Main_df$Sched_Market_Bid_time[idx]      <- format(Sched_markets_in_time$Market_Bid_time[CONT_002], "%Y-%m-%d %H:%M:%S")
    Main_df$Sched_Market_Period_Begin[idx]  <- format(Sched_markets_in_time$Market_Period_Begin[CONT_002], "%Y-%m-%d %H:%M:%S")
    Main_df$Sched_Market_Period_End[idx]    <- format(Sched_markets_in_time$Market_Period_End[CONT_002], "%Y-%m-%d %H:%M:%S")
    Main_df$Sched_Optimization_Horizon[idx] <- format(Sched_markets_in_time$Optimization_Horizon[CONT_002], "%Y-%m-%d %H:%M:%S")
    Main_df$Sched_Market_Aim[idx]           <- Sched_markets_in_time$Market_Aim[CONT_002]
  }

  sched_internal_vars <- c("begin_seq", "Sched_markets_in_time", "optimization_aim",
                           "time_min_day", "time_max_day", "days_sequence",
                           "CONT_002", "CONT_003", "idx", "market_name",
                           "begin_hour", "closure_hour", "end_hour",
                           "end_optimization", "market_aim",
                           "market_period_begin_seq", "market_period_end_seq",
                           "optimization_horizon_seq", "market_bid_time_seq",
                           "new_rows")
  rm(list = intersect(sched_internal_vars, ls()))
  rm(sched_internal_vars)
}

# -----------------------------------------------------------
# Configure Piloting market values based on Complex_Market_Config
# -----------------------------------------------------------
{
  if (complex_market_config == "no") {
    begin_seq <- seq(
      from = time_min,
      to   = time_max,
      by   = parameters$market$Implementation_horizon_piloting * 3600
    )

    Pilot_markets_in_time <- data.frame(
      Market_Name          = rep("Basic_Market", length(begin_seq)),
      Market_Bid_time      = as.POSIXct(begin_seq, origin = "1970-01-01", tz = "UTC"),
      Market_Period_Begin  = as.POSIXct(begin_seq, origin = "1970-01-01", tz = "UTC"),
      Market_Period_End    = as.POSIXct(begin_seq, origin = "1970-01-01", tz = "UTC"),
      Optimization_Horizon = as.POSIXct(begin_seq, origin = "1970-01-01", tz = "UTC"),
      Market_Aim           = rep("E", length(begin_seq)),
      stringsAsFactors     = FALSE
    )

    Pilot_markets_in_time$Market_Period_End <- Pilot_markets_in_time$Market_Period_Begin +
      parameters$market$Implementation_horizon_piloting * 3600
    Pilot_markets_in_time$Optimization_Horizon <- Pilot_markets_in_time$Market_Period_Begin +
      parameters$market$Optimization_horizon_piloting * 3600
    Pilot_markets_in_time$Market_Bid_time <- Pilot_markets_in_time$Market_Period_Begin -
      parameters$market$Anticipation_piloting * 3600

    Pilot_markets_in_time$Market_Bid_time <- pmin(pmax(Pilot_markets_in_time$Market_Bid_time, time_min), time_max)
    Pilot_markets_in_time$Market_Period_Begin <- pmin(pmax(Pilot_markets_in_time$Market_Period_Begin, time_min), time_max)
    Pilot_markets_in_time$Market_Period_End <- pmin(pmax(Pilot_markets_in_time$Market_Period_End, time_min), time_max)
    Pilot_markets_in_time$Optimization_Horizon <- pmin(pmax(Pilot_markets_in_time$Optimization_Horizon, time_min), time_max)

    optimization_aim <- parameters$market$optimization_aim_piloting
    if (optimization_aim == "flexibility") {
      Pilot_markets_in_time$Market_Aim <- "O+F"
    } else {
      Pilot_markets_in_time$Market_Aim <- "O"
    }
    rm(optimization_aim)

  } else {
    Pilot_markets_in_time <- data.frame(
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

    for (CONT_004 in seq_len(nrow(parameters$market_config_piloting))) {
      market_name      <- as.character(parameters$market_config_piloting$Market[CONT_004])
      begin_hour       <- as.numeric(parameters$market_config_piloting$begin[CONT_004])
      closure_hour     <- as.numeric(parameters$market_config_piloting$closure[CONT_004])
      end_hour         <- as.numeric(parameters$market_config_piloting$end[CONT_004])
      end_optimization <- as.numeric(parameters$market_config_piloting$end_optimization[CONT_004])
      market_aim       <- as.character(parameters$market_config_piloting$aim[CONT_004])

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

      Pilot_markets_in_time <- rbind(Pilot_markets_in_time, new_rows)
    }
    rm(CONT_004, market_name, begin_hour, closure_hour, end_hour, end_optimization, market_aim,
       market_period_begin_seq, market_period_end_seq, optimization_horizon_seq,
       market_bid_time_seq, new_rows, time_min_day, time_max_day, days_sequence)
  }

  for (CONT_005 in seq_len(nrow(Pilot_markets_in_time))) {
    idx <- which(Main_df$time == Pilot_markets_in_time$Market_Bid_time[CONT_005])
    if (length(idx) == 0) next
    Main_df$Pilot_Market_Name[idx]          <- Pilot_markets_in_time$Market_Name[CONT_005]
    Main_df$Pilot_Market_Bid_time[idx]      <- format(Pilot_markets_in_time$Market_Bid_time[CONT_005], "%Y-%m-%d %H:%M:%S")
    Main_df$Pilot_Market_Period_Begin[idx]  <- format(Pilot_markets_in_time$Market_Period_Begin[CONT_005], "%Y-%m-%d %H:%M:%S")
    Main_df$Pilot_Market_Period_End[idx]    <- format(Pilot_markets_in_time$Market_Period_End[CONT_005], "%Y-%m-%d %H:%M:%S")
    Main_df$Pilot_Optimization_Horizon[idx] <- format(Pilot_markets_in_time$Optimization_Horizon[CONT_005], "%Y-%m-%d %H:%M:%S")
    Main_df$Pilot_Market_Aim[idx]           <- Pilot_markets_in_time$Market_Aim[CONT_005]
  }

  pilot_internal_vars <- c("complex_market_config", "time_min", "time_max",
                           "begin_seq", "Pilot_markets_in_time", "optimization_aim",
                           "time_min_day", "time_max_day", "days_sequence",
                           "CONT_004", "CONT_005", "idx", "market_name",
                           "begin_hour", "closure_hour", "end_hour",
                           "end_optimization", "market_aim",
                           "market_period_begin_seq", "market_period_end_seq",
                           "optimization_horizon_seq", "market_bid_time_seq",
                           "new_rows")
  rm(list = intersect(pilot_internal_vars, ls()))
  rm(pilot_internal_vars)
}
