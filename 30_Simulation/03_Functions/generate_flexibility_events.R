# -------------------------------------------------------------
# Function: generate_flexibility_events.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Market-aware flexibility generation algorithm (Complex_Market_Config
# == "yes"), implementing Partes B.1-B.7 of
# 01_Agent_Comments/20260723_Plan_Generacion_Flexibilidad.md:
#   1. Scheduling market events, in Bid_time order: for each one, an
#      echo pass (try_flex_echo(), advance/delay of not-yet-displaced
#      prior Scheduling events whose forbidden zone overlaps the new
#      market's horizon) runs before new candidates (B.3) are placed
#      in the segments still available after the echo pass.
#   2. Piloting market events, in Bid_time order, after ALL Scheduling
#      events: candidates are placed anywhere in the market's own
#      horizon (no overlap checking of any kind, no echo) and gated by
#      an exponentially decreasing acceptance probability with the
#      horizon h (hours between Bid_time and the candidate's start).
# Every event's start/duration (and, for Scheduling's echo, its shift)
# is discretized to slots of parameters$market$market_resolution
# (Parte B.0) - this is what makes an event's exact placement always
# representable as a whole number of Main_df rows.
# Writes (overwrites) Flex_unit_cost_down_com/_down_exec/_up_com/
# _up_exec, Flex_Probab and Flex_Act across the whole of Main_df: one
# accepted event sets its covered rows, everything else is 0 (Flex_Act:
# 0/1). Piloting is written after Scheduling, so on any overlap
# Piloting's value prevails (last-write-wins, by design - see Parte
# B.5.4).
# -------------------------------------------------------------
# Inputs
# Main_df    : Data frame. Must already have the Sched_*/Pilot_*
#              market timeline columns (market_columns_setup.R) and
#              the Flex_* columns (from Energy_Prices_df).
# parameters : List. Uses parameters$market (market_resolution,
#              Max_flex_periods_day, Max_flex_com_price,
#              Max_flex_exec_price, Max_flex_period_duration,
#              Max_flex_probability) and parameters$flexibility_generation
#              (Max_shift_hours, P_advance, P_delay, P_event_base,
#              decay_rate).
# -------------------------------------------------------------
# Outputs
# Main_df : Data frame. Flex_unit_cost_down_com/_down_exec/_up_com/
#           _up_exec, Flex_Probab, Flex_Act overwritten as described
#           above.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - A market whose horizon collapses to zero length (clipped at the
#     start/end of the simulated period) is skipped.
#   - A Scheduling market with no prior events to offer an echo to, or
#     whose Available_m is empty, simply skips straight to (or skips
#     entirely) new-candidate placement - no error.
# -------------------------------------------------------------
# Usage instructions
# Main_df <- generate_flexibility_events(Main_df, parameters)
# -------------------------------------------------------------
# Where this function/script is used
# Called by flexibility_generation.R when Complex_Market_Config == "yes".
# -------------------------------------------------------------
# functions/scripts called
#   is_market_active(), compute_available_segments(),
#   place_flex_candidate(), try_flex_echo()
# -------------------------------------------------------------

generate_flexibility_events <- function(Main_df, parameters) {

  margin_sec            <- 3 * 3600
  market_resolution_sec <- parameters$market$market_resolution * 60

  Max_flex_periods_day     <- parameters$market$Max_flex_periods_day
  Max_flex_com_price       <- parameters$market$Max_flex_com_price
  Max_flex_exec_price      <- parameters$market$Max_flex_exec_price
  Max_flex_period_duration <- parameters$market$Max_flex_period_duration
  Max_flex_probability     <- parameters$market$Max_flex_probability

  Max_shift_hours <- parameters$flexibility_generation$Max_shift_hours
  P_advance       <- parameters$flexibility_generation$P_advance
  P_delay         <- parameters$flexibility_generation$P_delay
  P_event_base    <- parameters$flexibility_generation$P_event_base
  decay_rate      <- parameters$flexibility_generation$decay_rate

  time_num <- as.numeric(Main_df$time)

  # ---- 1. Enumerate market events (Bid_time order) ----
  extract_market_events <- function(role) {
    name_col   <- paste0(role, "_Market_Name")
    begin_col  <- paste0(role, "_Market_Period_Begin")
    horizon_col <- paste0(role, "_Optimization_Horizon")

    # is_market_active is applied to every row of this role's Market_Name
    # column to identify the rows where a market event actually fires,
    # so only those rows are turned into events below.
    active_idx <- which(vapply(Main_df[[name_col]], is_market_active, logical(1)))
    if (length(active_idx) == 0) {
      return(data.frame(bid_time_sec = numeric(0), horizon_begin_sec = numeric(0),
                        horizon_end_sec = numeric(0)))
    }

    events <- data.frame(
      bid_time_sec      = time_num[active_idx],
      horizon_begin_sec = as.numeric(as.POSIXct(Main_df[[begin_col]][active_idx], tz = "UTC")),
      horizon_end_sec   = as.numeric(as.POSIXct(Main_df[[horizon_col]][active_idx], tz = "UTC"))
    )
    events[order(events$bid_time_sec), ]
  }

  sched_events <- extract_market_events("Sched")
  pilot_events <- extract_market_events("Pilot")

  # ---- 2. Scheduling: echo pass + new candidates, per market event ----
  E_sched <- data.frame(
    id = integer(0), t_start_sec = numeric(0), duration_sec = numeric(0),
    price_com = numeric(0), price_exec = numeric(0), probab = numeric(0),
    displaced = logical(0)
  )
  next_id <- 1L

  if (nrow(sched_events) > 0) {
    for (CONT_001 in seq_len(nrow(sched_events))) {
      horizon_begin <- sched_events$horizon_begin_sec[CONT_001]
      horizon_end   <- sched_events$horizon_end_sec[CONT_001]
      if (horizon_end <= horizon_begin) next

      # -- 2a. Echo pass (Parte B.4), only over not-yet-displaced events
      #    whose forbidden zone overlaps this market's horizon --
      if (nrow(E_sched) > 0) {
        eligible <- !E_sched$displaced &
          (E_sched$t_start_sec - margin_sec) < horizon_end &
          (E_sched$t_start_sec + E_sched$duration_sec + margin_sec) > horizon_begin
        eligible_ids <- E_sched$id[eligible][order(E_sched$t_start_sec[eligible])]

        for (eid in eligible_ids) {
          row_idx <- which(E_sched$id == eid)
          other_idx <- which(E_sched$id != eid)
          other_events <- lapply(other_idx, function(CONT_002) {
            list(t_start_sec = E_sched$t_start_sec[CONT_002],
                duration_sec = E_sched$duration_sec[CONT_002])
          })

          # try_flex_echo is called to test advancing or delaying this
          # not-yet-displaced prior event so it no longer conflicts with
          # the current market's horizon, before any new candidate is
          # placed in that horizon.
          echo_result <- try_flex_echo(
            event = list(t_start_sec = E_sched$t_start_sec[row_idx],
                        duration_sec = E_sched$duration_sec[row_idx]),
            horizon_begin = horizon_begin, horizon_end = horizon_end,
            other_events = other_events,
            P_advance = P_advance, P_delay = P_delay,
            Max_shift_hours = Max_shift_hours,
            market_resolution_sec = market_resolution_sec,
            margin_sec = margin_sec
          )

          if (echo_result$accepted) {
            E_sched$t_start_sec[row_idx] <- echo_result$t_start_sec
            E_sched$displaced[row_idx]   <- TRUE
          }
        }
      }

      # -- 2b. New candidates (Parte B.3) --
      forbidden <- if (nrow(E_sched) > 0) {
        lapply(seq_len(nrow(E_sched)), function(CONT_003) {
          c(E_sched$t_start_sec[CONT_003] - margin_sec,
            E_sched$t_start_sec[CONT_003] + E_sched$duration_sec[CONT_003] + margin_sec)
        })
      } else {
        list()
      }
      # compute_available_segments is called to work out which parts of
      # this market's horizon are still free for new candidates once the
      # forbidden zones of already-placed Scheduling events (possibly
      # shifted by the echo pass above) are removed.
      available <- compute_available_segments(horizon_begin, horizon_end, forbidden)

      n_periods  <- round(runif(1) * Max_flex_periods_day)
      price_com  <- runif(1) * Max_flex_com_price
      price_exec <- runif(1) * Max_flex_exec_price
      probab_val <- runif(1) * Max_flex_probability

      if (n_periods > 0 && nrow(available) > 0) {
        for (CONT_004 in seq_len(n_periods)) {
          # place_flex_candidate is called to draw one random Scheduling
          # candidate (start/duration) inside the segments still
          # available after the echo pass, discretized to the market
          # resolution.
          candidate <- place_flex_candidate(available, market_resolution_sec, Max_flex_period_duration)
          if (!is.null(candidate)) {
            E_sched <- rbind(E_sched, data.frame(
              id = next_id, t_start_sec = candidate$t_start_sec,
              duration_sec = candidate$duration_sec,
              price_com = price_com, price_exec = price_exec, probab = probab_val,
              displaced = FALSE
            ))
            next_id <- next_id + 1L
          }
        }
      }
    }
  }

  # ---- 3. Piloting: candidates gated by exponential decay, no overlap check ----
  E_pilot <- data.frame(
    t_start_sec = numeric(0), duration_sec = numeric(0),
    price_com = numeric(0), price_exec = numeric(0), probab = numeric(0)
  )

  if (nrow(pilot_events) > 0) {
    for (CONT_005 in seq_len(nrow(pilot_events))) {
      horizon_begin <- pilot_events$horizon_begin_sec[CONT_005]
      horizon_end   <- pilot_events$horizon_end_sec[CONT_005]
      if (horizon_end <= horizon_begin) next

      full_horizon <- data.frame(start = horizon_begin, end = horizon_end)

      n_periods  <- round(runif(1) * Max_flex_periods_day)
      price_com  <- runif(1) * Max_flex_com_price
      price_exec <- runif(1) * Max_flex_exec_price
      probab_val <- runif(1) * Max_flex_probability

      if (n_periods > 0) {
        for (CONT_006 in seq_len(n_periods)) {
          # place_flex_candidate is called to draw one random Piloting
          # candidate (start/duration) anywhere in the market's own
          # horizon, since Piloting placement has no overlap checking.
          candidate <- place_flex_candidate(full_horizon, market_resolution_sec, Max_flex_period_duration)
          if (is.null(candidate)) next

          h_hours  <- (candidate$t_start_sec - pilot_events$bid_time_sec[CONT_005]) / 3600
          p_event  <- P_event_base * exp(-decay_rate * h_hours)

          if (runif(1) < p_event) {
            E_pilot <- rbind(E_pilot, data.frame(
              t_start_sec = candidate$t_start_sec, duration_sec = candidate$duration_sec,
              price_com = price_com, price_exec = price_exec, probab = probab_val
            ))
          }
        }
      }
    }
  }

  # ---- 4. Write final state into Main_df (Parte B.6) ----
  n_rows    <- nrow(Main_df)
  down_com  <- rep(0, n_rows)
  down_exec <- rep(0, n_rows)
  up_com    <- rep(0, n_rows)
  up_exec   <- rep(0, n_rows)
  probab    <- rep(0, n_rows)
  flex_act  <- rep(0, n_rows)

  write_events <- function(events_df) {
    if (nrow(events_df) == 0) return(invisible(NULL))
    for (CONT_007 in seq_len(nrow(events_df))) {
      rows <- which(time_num >= events_df$t_start_sec[CONT_007] &
                     time_num <  events_df$t_start_sec[CONT_007] + events_df$duration_sec[CONT_007])
      if (length(rows) == 0) next
      down_com[rows]  <<- events_df$price_com[CONT_007]
      down_exec[rows] <<- events_df$price_exec[CONT_007]
      up_com[rows]    <<- events_df$price_com[CONT_007]
      up_exec[rows]   <<- events_df$price_exec[CONT_007]
      probab[rows]    <<- events_df$probab[CONT_007]
      flex_act[rows]  <<- 1
    }
  }

  write_events(E_sched)
  write_events(E_pilot)

  Main_df$Flex_unit_cost_down_com  <- down_com
  Main_df$Flex_unit_cost_down_exec <- down_exec
  Main_df$Flex_unit_cost_up_com    <- up_com
  Main_df$Flex_unit_cost_up_exec   <- up_exec
  Main_df$Flex_Probab              <- probab
  Main_df$Flex_Act                 <- flex_act

  Main_df
}
