# -------------------------------------------------------------
# Function: resolve_marginal_context.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Computes the baseline commitment (E_orig) and current-market prices
# needed to value a candidate control schedule at its marginal
# (differential) cost, per target market interval of the horizon
# about to be optimized. This is called once per market process
# (Scheduling or Piloting), before the GA runs, so that every
# candidate evaluated by the fitness function is priced against the
# same fixed baseline and prices.
# Both the base-energy track and the explicit-flexibility track are
# always resolved: reward_function() selects which of them it needs
# based on parameters$control$optimization_aim ("energy" only needs
# the base track; "flexibility"/"operationflex" also need the
# explicit-flexibility track), not on whether the market is
# Scheduling or Piloting - unlike integrate_market_process(), which
# only ever commits the explicit-flexibility track economically for
# Piloting, reward_function() has no such prefix-based distinction:
# a Scheduling market configured with a "flexibility" aim explores
# flexibility exactly the same way Piloting does.
# Reuses exactly the same row/column resolution as
# integrate_market_process.R (row_m_full on the full market-resolution
# grid for column offsets; row_m, the sparse row of the current event
# in full_market_information's own row set, for price lookups) and the
# same per-interval SUM aggregation of Main_df's existing *_plan
# columns, so that the baseline priced here is guaranteed to match
# what integrate_market_process() will later treat as E_orig for the
# same market event.
# -------------------------------------------------------------
# Inputs
# row_index               : Integer. Current simulation row index
#                           (CONT_003).
# Main_df                 : Data frame. The main simulation data
#                           frame, in its state before this market's
#                           optimization overwrites any *_plan columns.
# simulation_control      : Named list. Must contain
#                           indexes_global$idx_horizon, the current
#                           market's optimization horizon, which is
#                           what gets valued, and
#                           indexes_global$idx_ctrl, its control
#                           horizon, which is where the published
#                           prices stop.
# market_time             : POSIXct vector. Sorted unique MarketUTC
#                           intervals on the full market-resolution
#                           grid; used only to compute future-step
#                           column offsets (col_j).
# full_market_information : Named list of 13 market-event price data
#                           frames (read-only), as built by
#                           11_full_market_information_setup.R.
# parameters              : Named list. Only parameters$forecast is
#                           read, for the price forecast:
#                           price_forecast_type, and when it is
#                           "inaccurate", price_forecast_n_days_back
#                           and price_forecast_weight_history.
# -------------------------------------------------------------
# What is valued and what is committed
# These are two different sets of market intervals, and keeping them
# apart is the whole point of this function's shape.
# The intervals returned here are those of the OPTIMIZATION HORIZON,
# because the optimizer decides the setpoints of that whole horizon and
# every energy flow and unit cost of it has to reach the reward. Their
# prices are the published ones inside the control horizon and a
# forecast beyond it.
# The intervals that are COMMITTED are only those of the control
# horizon, and they are built inside integrate_market_process() from
# idx_ctrl, not here. The stretch valued with forecast prices therefore
# never reaches the settlement: the next market finds those hours with
# nothing booked on them and values them again with prices it does
# know, which is what keeps the double counting away with no artifice.
# -------------------------------------------------------------
# Outputs
# Named list with:
#   market_utc               : POSIXct vector. MarketUTC of each
#                              target interval, in the same order as
#                              every other element below.
#   E_orig_base_by_market    : Numeric vector. Main_df$Elec_total_plan
#                              summed per target interval, before this
#                              market's optimization.
#   E_orig_expflex_down_by_market :
#                              Numeric vector. Main_df$Elec_flex_down_plan
#                              summed per target interval, before this
#                              market's optimization.
#   E_orig_expflex_up_by_market :
#                              Numeric vector. Main_df$Elec_flex_up_plan
#                              summed per target interval, before this
#                              market's optimization. One baseline per
#                              leg: both signals are non-negative by
#                              construction, so they cannot be told
#                              apart by sign once added together.
#   P_import_buy_by_market, P_import_sell_by_market,
#   P_export_buy_by_market, P_export_sell_by_market :
#                              Numeric vectors. Current-market energy
#                              prices per target interval, ready to pass
#                              straight into calc_differential_cost()/
#                              compute_marginal_energy_cost() for the
#                              base-energy and flex-adjusted-energy terms.
#   distribution_rate_by_market :
#                              Numeric vector. Current-market
#                              Elec_unit_cost_distribution rate per target
#                              interval, ready to pass into
#                              compute_marginal_distribution_cost() for
#                              the base-energy term only (not used for
#                              flexibility).
#   p_up_buy_by_market, p_up_sell_by_market,
#   p_down_buy_by_market, p_down_sell_by_market :
#                              Numeric vectors. Effective up/down
#                              flexibility prices per target interval
#                              (commitment + execution * probability),
#                              ready to pass into the same functions for
#                              the explicit-flexibility term.
#   p_down_com_buy_by_market, p_down_com_sell_by_market,
#   p_up_com_buy_by_market, p_up_com_sell_by_market,
#   p_down_exec_buy_by_market, p_down_exec_sell_by_market,
#   p_up_exec_buy_by_market, p_up_exec_sell_by_market :
#                              Numeric vectors. The two halves of those
#                              effective prices, unbundled: the
#                              commitment price, which is paid for
#                              certain, and the execution price, which is
#                              only paid if the operator calls the
#                              service.
#   flex_probab_down_by_market, flex_probab_up_by_market :
#                              Numeric vectors in [0, 1]. Activation
#                              probability of each leg per target
#                              interval. Together with the two price
#                              families above they let the caller value
#                              the certain and the conditional halves of
#                              the service separately, which the bundled
#                              effective price cannot express: the
#                              execution of a commitment also moves the
#                              building's energy during the
#                              Recovery Phase, and that cost is
#                              conditional on the same probability.
#   revenue_discount_by_market :
#                              Numeric vector. Revenue discount factor
#                              of each target interval, as returned by
#                              revenue_discount_factor(). It weighs down
#                              income that is far from the decision
#                              instant, and only income.
#   revenue_discount_per_hour  : Numeric scalar (%). The rate those
#                              factors were built from, carried so that
#                              the caller can build the same factors for
#                              instants outside the target set.
#   discount_origin_time       : POSIXct scalar. The decision instant H
#                              the factors are counted from, this
#                              market event's own market interval.
# -------------------------------------------------------------
# Code outline
# 1. Market row (full grid and sparse) and target market intervals
# 2. Baseline commitments before this market (SUM aggregation)
# 3. Current-market prices per target interval
# 4. Price forecast beyond the control horizon
# 5. Revenue discount factors of the horizon
# -------------------------------------------------------------
# Usage instructions
# marginal_context <- resolve_marginal_context(row_index, Main_df, simulation_control, market_time, full_market_information)
# -------------------------------------------------------------
# Where this function/script is used
# Called by 14_simulation.R, once per Scheduling/Piloting market process,
# right before run_market_process(), using Main_df in its
# pre-optimization state. The result is passed into
# run_market_process() as marginal_context.
# -------------------------------------------------------------
# functions/scripts called
#   is_market_active() - tells which of the two market families the
#                        current event belongs to
#   imperfect_price_forecast() - degrades the prices of the intervals
#                        beyond the control horizon
#   revenue_discount_factor() - builds the revenue discount factor of
#                        each target interval
# -------------------------------------------------------------

resolve_marginal_context <- function(row_index,
                                     Main_df,
                                     simulation_control,
                                     market_time,
                                     full_market_information,
                                     parameters) {

  # 1. Market row (full grid and sparse) and target market intervals
  # -------------------------------------------------------------
  # row_m_full: position of the current event on the full
  # market-resolution grid, used only for col_j offsets. row_m: the
  # same event's position within full_market_information's own
  # (sparse, market-event) row set, used for price lookups.
  # -------------------------------------------------------------
  {
    row_m_full <- match(Main_df$MarketUTC[row_index], market_time)
    market_rows <- full_market_information$Elec_unit_cost_import_buy_df$time
    row_m <- match(Main_df$MarketUTC[row_index], market_rows)

    # The intervals to VALUE are those of the whole optimization horizon,
    # not just those of the control horizon. The optimizer decides the
    # setpoints of the whole horizon, so every energy flow and every
    # unit cost of that horizon has to reach the reward; otherwise the
    # tail of the horizon is chosen with no economic consequence at all.
    # What stays bounded to the control horizon is the COMMITMENT, and
    # that lives in integrate_market_process(), which builds its own
    # interval set from idx_ctrl and is not touched by this widening.
    # The separation is what keeps the double counting away without any
    # artifice: the stretch valued with forecast prices never reaches
    # the settlement, so the next market finds those hours with nothing
    # booked on them and values them again with prices it does know.
    idx_target_market <- match(
      sort(unique(Main_df$MarketUTC[simulation_control$indexes_global$idx_horizon])),
      market_time
    )
    market_utc <- market_time[idx_target_market]

    # Close of the control horizon. Everything at or before it has a
    # published price; everything after it has to be forecast.
    end_control_time <- max(Main_df$MarketUTC[simulation_control$indexes_global$idx_ctrl])

    # Which market family this event belongs to, needed by the price
    # forecast to look for the same market on previous days.
    market_role <- if (is_market_active(Main_df$Sched_Market_Name[row_index])) "Sched" else "Pilot"
    market_name <- as.character(Main_df[[paste0(market_role, "_Market_Name")]][row_index])

    rm(market_rows)
  }

  # 2. Baseline commitments before this market (SUM aggregation)
  # -------------------------------------------------------------
  # Same aggregation as integrate_market_process()'s E_orig_*_by_market,
  # over Main_df in its pre-optimization state.
  # -------------------------------------------------------------
  {
    E_orig_base_by_market <- as.numeric(tapply(
      Main_df$Elec_total_plan[simulation_control$indexes_global$idx_horizon],
      Main_df$MarketUTC[simulation_control$indexes_global$idx_horizon], sum
    ))

    # One baseline per leg. The two flexibility signals are independent
    # and both non-negative by construction, so they cannot be added up
    # or told apart by sign: a single baseline would net a downward
    # commitment against an upward one and value the difference as if it
    # were a single service.
    E_orig_expflex_down_by_market <- as.numeric(tapply(
      Main_df$Elec_flex_down_plan[simulation_control$indexes_global$idx_horizon],
      Main_df$MarketUTC[simulation_control$indexes_global$idx_horizon], sum
    ))

    E_orig_expflex_up_by_market <- as.numeric(tapply(
      Main_df$Elec_flex_up_plan[simulation_control$indexes_global$idx_horizon],
      Main_df$MarketUTC[simulation_control$indexes_global$idx_horizon], sum
    ))
  }

  # 3. Current-market prices per target interval
  # -------------------------------------------------------------
  {
    P_import_buy_by_market  <- numeric(length(idx_target_market))
    P_import_sell_by_market <- numeric(length(idx_target_market))
    P_export_buy_by_market  <- numeric(length(idx_target_market))
    P_export_sell_by_market <- numeric(length(idx_target_market))
    distribution_rate_by_market <- numeric(length(idx_target_market))
    p_up_buy_by_market      <- numeric(length(idx_target_market))
    p_up_sell_by_market     <- numeric(length(idx_target_market))
    p_down_buy_by_market    <- numeric(length(idx_target_market))
    p_down_sell_by_market   <- numeric(length(idx_target_market))

    # The commitment and execution halves of those effective prices are
    # also returned on their own, together with each leg's activation
    # probability, because the reward values them separately: the
    # commitment is certain and is paid at the commitment price alone,
    # while the execution is conditional and carries, besides its own
    # price, the energy the building has to move during the
    # Recovery Phase. Bundling them into one effective price, as
    # the p_*_by_market vectors above do, cannot express that.
    p_down_com_buy_by_market   <- numeric(length(idx_target_market))
    p_down_com_sell_by_market  <- numeric(length(idx_target_market))
    p_up_com_buy_by_market     <- numeric(length(idx_target_market))
    p_up_com_sell_by_market    <- numeric(length(idx_target_market))
    p_down_exec_buy_by_market  <- numeric(length(idx_target_market))
    p_down_exec_sell_by_market <- numeric(length(idx_target_market))
    p_up_exec_buy_by_market    <- numeric(length(idx_target_market))
    p_up_exec_sell_by_market   <- numeric(length(idx_target_market))
    flex_probab_down_by_market <- numeric(length(idx_target_market))
    flex_probab_up_by_market   <- numeric(length(idx_target_market))

    # A price matrix has one column per step ahead, up to the widest
    # horizon any configured market needs. An interval of the
    # optimization horizon that falls past the last column has no cell
    # to read, so the last available column is used instead. It is a
    # guard, not a modelling choice: it should not trigger with the
    # horizons of the configuration, and it keeps an NA from reaching
    # the reward if it ever does.
    price_at <- function(signal_df, col_j) {
      if (col_j %in% names(signal_df)) return(signal_df[[col_j]][row_m])
      last_col <- tail(setdiff(names(signal_df), "time"), 1)
      signal_df[row_m, last_col]
    }

    for (CONT_001 in seq_along(idx_target_market)) {
      i_target <- idx_target_market[CONT_001]
      col_j    <- as.character(i_target - row_m_full)

      P_import_buy_by_market[CONT_001]  <- price_at(full_market_information$Elec_unit_cost_import_buy_df, col_j)
      P_import_sell_by_market[CONT_001] <- price_at(full_market_information$Elec_unit_cost_import_sell_df, col_j)
      P_export_buy_by_market[CONT_001]  <- price_at(full_market_information$Elec_unit_cost_export_buy_df, col_j)
      P_export_sell_by_market[CONT_001] <- price_at(full_market_information$Elec_unit_cost_export_sell_df, col_j)
      distribution_rate_by_market[CONT_001] <- price_at(full_market_information$Elec_unit_cost_distribution_df, col_j)

      # Each leg is weighted by its own activation probability: the down
      # leg by Flex_Probab_down and the up leg by Flex_Probab_up. They are
      # independent signals, so a market interval can be very likely to be
      # called for a load reduction and unlikely for a load increase, or
      # the other way round.
      mkt_target              <- market_utc[CONT_001]
      rows_ts                 <- which(Main_df$MarketUTC == mkt_target)
      Flex_Probab_down_target <- Main_df$Flex_Probab_down[rows_ts[1]]
      Flex_Probab_up_target   <- Main_df$Flex_Probab_up[rows_ts[1]]

      p_up_buy_by_market[CONT_001]   <- price_at(full_market_information$Flex_unit_cost_up_com_buy_df, col_j) +
        price_at(full_market_information$Flex_unit_cost_up_exec_buy_df, col_j) * Flex_Probab_up_target
      p_up_sell_by_market[CONT_001]  <- price_at(full_market_information$Flex_unit_cost_up_com_sell_df, col_j) +
        price_at(full_market_information$Flex_unit_cost_up_exec_sell_df, col_j) * Flex_Probab_up_target
      p_down_buy_by_market[CONT_001]  <- price_at(full_market_information$Flex_unit_cost_down_com_buy_df, col_j) +
        price_at(full_market_information$Flex_unit_cost_down_exec_buy_df, col_j) * Flex_Probab_down_target
      p_down_sell_by_market[CONT_001] <- price_at(full_market_information$Flex_unit_cost_down_com_sell_df, col_j) +
        price_at(full_market_information$Flex_unit_cost_down_exec_sell_df, col_j) * Flex_Probab_down_target

      p_down_com_buy_by_market[CONT_001]   <- price_at(full_market_information$Flex_unit_cost_down_com_buy_df, col_j)
      p_down_com_sell_by_market[CONT_001]  <- price_at(full_market_information$Flex_unit_cost_down_com_sell_df, col_j)
      p_up_com_buy_by_market[CONT_001]     <- price_at(full_market_information$Flex_unit_cost_up_com_buy_df, col_j)
      p_up_com_sell_by_market[CONT_001]    <- price_at(full_market_information$Flex_unit_cost_up_com_sell_df, col_j)
      p_down_exec_buy_by_market[CONT_001]  <- price_at(full_market_information$Flex_unit_cost_down_exec_buy_df, col_j)
      p_down_exec_sell_by_market[CONT_001] <- price_at(full_market_information$Flex_unit_cost_down_exec_sell_df, col_j)
      p_up_exec_buy_by_market[CONT_001]    <- price_at(full_market_information$Flex_unit_cost_up_exec_buy_df, col_j)
      p_up_exec_sell_by_market[CONT_001]   <- price_at(full_market_information$Flex_unit_cost_up_exec_sell_df, col_j)
      flex_probab_down_by_market[CONT_001] <- Flex_Probab_down_target
      flex_probab_up_by_market[CONT_001]   <- Flex_Probab_up_target

      rm(mkt_target, rows_ts, Flex_Probab_down_target, Flex_Probab_up_target)
    }
    # intersect with ls(): if idx_target_market were ever empty the
    # loop would not run and CONT_001/i_target/col_j would not exist,
    # and an unconditional rm() would abort with "object not found".
    rm(list = intersect(c("CONT_001", "i_target", "col_j", "price_at"), ls()))
  }

  # 4. Price forecast beyond the control horizon
  # -------------------------------------------------------------
  # Everything read above is the TRUE price of each interval, which for
  # the stretch that exceeds the control horizon is information the
  # optimizer cannot have when it decides. Each signal is therefore
  # passed through imperfect_price_forecast(), which leaves the
  # published stretch untouched and degrades the rest.
  # The activation probabilities are left as they are: they are not a
  # price and the assignment asks for a forecast of prices.
  # -------------------------------------------------------------
  {
    price_forecast_type <- parameters$forecast$price_forecast_type

    if (!is.null(price_forecast_type) && price_forecast_type == "inaccurate") {

      n_days_back    <- parameters$forecast$price_forecast_n_days_back
      weight_history <- parameters$forecast$price_forecast_weight_history

      forecast_signal <- function(values, signal_df) {
        imperfect_price_forecast(
          target_times     = market_utc,
          true_values      = values,
          end_control_time = end_control_time,
          market_name      = market_name,
          role             = market_role,
          signal_df        = signal_df,
          Main_df          = Main_df,
          market_time      = market_time,
          n_days_back      = n_days_back,
          weight_history   = weight_history
        )
      }

      P_import_buy_by_market  <- forecast_signal(P_import_buy_by_market,
                                                 full_market_information$Elec_unit_cost_import_buy_df)
      P_import_sell_by_market <- forecast_signal(P_import_sell_by_market,
                                                 full_market_information$Elec_unit_cost_import_sell_df)
      P_export_buy_by_market  <- forecast_signal(P_export_buy_by_market,
                                                 full_market_information$Elec_unit_cost_export_buy_df)
      P_export_sell_by_market <- forecast_signal(P_export_sell_by_market,
                                                 full_market_information$Elec_unit_cost_export_sell_df)
      distribution_rate_by_market <- forecast_signal(distribution_rate_by_market,
                                                 full_market_information$Elec_unit_cost_distribution_df)

      p_down_com_buy_by_market   <- forecast_signal(p_down_com_buy_by_market,
                                                 full_market_information$Flex_unit_cost_down_com_buy_df)
      p_down_com_sell_by_market  <- forecast_signal(p_down_com_sell_by_market,
                                                 full_market_information$Flex_unit_cost_down_com_sell_df)
      p_up_com_buy_by_market     <- forecast_signal(p_up_com_buy_by_market,
                                                 full_market_information$Flex_unit_cost_up_com_buy_df)
      p_up_com_sell_by_market    <- forecast_signal(p_up_com_sell_by_market,
                                                 full_market_information$Flex_unit_cost_up_com_sell_df)
      p_down_exec_buy_by_market  <- forecast_signal(p_down_exec_buy_by_market,
                                                 full_market_information$Flex_unit_cost_down_exec_buy_df)
      p_down_exec_sell_by_market <- forecast_signal(p_down_exec_sell_by_market,
                                                 full_market_information$Flex_unit_cost_down_exec_sell_df)
      p_up_exec_buy_by_market    <- forecast_signal(p_up_exec_buy_by_market,
                                                 full_market_information$Flex_unit_cost_up_exec_buy_df)
      p_up_exec_sell_by_market   <- forecast_signal(p_up_exec_sell_by_market,
                                                 full_market_information$Flex_unit_cost_up_exec_sell_df)

      # The effective prices are rebuilt from the forecast halves, so
      # that the two families stay consistent with each other.
      p_down_buy_by_market  <- p_down_com_buy_by_market  + p_down_exec_buy_by_market  * flex_probab_down_by_market
      p_down_sell_by_market <- p_down_com_sell_by_market + p_down_exec_sell_by_market * flex_probab_down_by_market
      p_up_buy_by_market    <- p_up_com_buy_by_market    + p_up_exec_buy_by_market    * flex_probab_up_by_market
      p_up_sell_by_market   <- p_up_com_sell_by_market   + p_up_exec_sell_by_market   * flex_probab_up_by_market

      rm(n_days_back, weight_history, forecast_signal)
    }

    rm(price_forecast_type)
  }

  # 5. Revenue discount factors of the horizon
  # -------------------------------------------------------------
  # The decision instant H is this market event's own market interval,
  # the one the optimization is being run at. Every valued interval is
  # then discounted by its distance from it, so that the reward prefers
  # what pays sooner. The factors travel in the context, next to the
  # prices, because they are resolved from the same market row and are
  # constant for every GA candidate of this optimization: computing them
  # here is what keeps them out of the per-candidate inner loop.
  # discount_origin_time travels too, so that reward_function() can
  # build the same factors for the Recovery Phase rows that fall beyond
  # this market's target intervals, exactly as it reads their prices
  # from the period_chunk.
  # -------------------------------------------------------------
  {
    discount_origin_time <- Main_df$MarketUTC[row_index]

    revenue_discount_per_hour <- parameters$reward$Revenue_discount_per_hour
    if (is.null(revenue_discount_per_hour)) {
      stop("resolve_marginal_context: Revenue_discount_per_hour was not ",
           "found in parameters$reward. It is read from ",
           "09_Reward_parameters.csv and has no default: the reward's ",
           "revenue discount cannot be resolved without it.")
    }

    # revenue_discount_factor() is called to turn the hourly rate into
    # one factor per target interval of the horizon.
    revenue_discount_by_market <- revenue_discount_factor(
      target_time       = market_utc,
      origin_time       = discount_origin_time,
      discount_per_hour = revenue_discount_per_hour
    )
  }

  rm(row_m, row_m_full, idx_target_market, end_control_time, market_role,
     market_name)

  return(list(
    market_utc               = market_utc,
    E_orig_base_by_market    = E_orig_base_by_market,
    E_orig_expflex_down_by_market = E_orig_expflex_down_by_market,
    E_orig_expflex_up_by_market   = E_orig_expflex_up_by_market,
    P_import_buy_by_market   = P_import_buy_by_market,
    P_import_sell_by_market  = P_import_sell_by_market,
    P_export_buy_by_market   = P_export_buy_by_market,
    P_export_sell_by_market  = P_export_sell_by_market,
    distribution_rate_by_market = distribution_rate_by_market,
    p_up_buy_by_market       = p_up_buy_by_market,
    p_up_sell_by_market      = p_up_sell_by_market,
    p_down_buy_by_market     = p_down_buy_by_market,
    p_down_sell_by_market    = p_down_sell_by_market,
    p_down_com_buy_by_market   = p_down_com_buy_by_market,
    p_down_com_sell_by_market  = p_down_com_sell_by_market,
    p_up_com_buy_by_market     = p_up_com_buy_by_market,
    p_up_com_sell_by_market    = p_up_com_sell_by_market,
    p_down_exec_buy_by_market  = p_down_exec_buy_by_market,
    p_down_exec_sell_by_market = p_down_exec_sell_by_market,
    p_up_exec_buy_by_market    = p_up_exec_buy_by_market,
    p_up_exec_sell_by_market   = p_up_exec_sell_by_market,
    flex_probab_down_by_market = flex_probab_down_by_market,
    flex_probab_up_by_market   = flex_probab_up_by_market,
    revenue_discount_by_market = revenue_discount_by_market,
    revenue_discount_per_hour  = revenue_discount_per_hour,
    discount_origin_time       = discount_origin_time
  ))
}
