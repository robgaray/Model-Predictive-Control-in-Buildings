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
# always resolved, and reward_function() values both whatever the
# aim and whatever the market family. A market with the "energy"
# aim places no new window, but the flexibility earlier markets
# sold is restated over its plan: inside the control horizon any
# change of it is settled at this market's prices, and beyond it the
# part the plan can no longer hold is valued as the re-purchase a
# later market will have to make. The explicit-flexibility track is
# what values that obligation. A Scheduling market with a
# "flexibility" aim explores flexibility exactly the same way
# Piloting does.
# Reuses exactly the same row/column resolution as
# settle_market.R (row_m_full on the full market-resolution
# grid for column offsets; row_m, the sparse row of the current event
# in full_market_information's own row set, for price lookups) and the
# same per-interval SUM aggregation of Main_df's existing *_plan
# columns, so that the baseline priced here is guaranteed to match
# what settle_market() will later treat as E_orig for the
# same market event.
# The event is keyed by the market interval its clearing instant
# falls in (instant_market_slot()), and every target interval is a
# MarketUTC interval: the interval of the time steps the market
# values. The row at Period_Begin is not one of them, since its time
# step ends the interval before the market's period.
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
# market_index            : Data frame. The market events of both
#                           families and the periods they trade, as
#                           market_event_index() lists them for
#                           "Sched" and "Pilot", one after the other.
#                           It is where the earlier prices are looked
#                           up beyond the control horizon.
# full_market_information : Named list of 13 market-event price data
#                           frames (read-only), as built by
#                           prepare_market_information().
# parameters              : Named list. Reads:
#                             - parameters$market$market_resolution,
#                               to key the market events
#                             - parameters$reward$Revenue_discount_per_hour
#                             - parameters$forecast$price_forecast_type:
#                               with "inaccurate", the prices beyond
#                               the control horizon are estimated from
#                               what the markets already know
# -------------------------------------------------------------
# What is valued and what is committed
# These are two different sets of market intervals, and keeping them
# apart is the whole point of this function's shape.
# The intervals returned here are those of the OPTIMIZATION HORIZON,
# because the optimizer decides the setpoints of that whole horizon and
# every energy flow and unit cost of it has to reach the reward. Their
# prices are the published ones inside the control horizon and an
# estimate beyond it.
# The intervals that are COMMITTED are only those of the control
# horizon, and they are built inside settle_market() from
# idx_ctrl, not here. The stretch valued with estimated prices therefore
# never reaches the settlement: the next market finds those hours with
# nothing booked on them and values them again with prices it does
# know, which is what keeps the double counting away with no artifice.
# The flexibility earlier markets sold beyond the control horizon is
# the exception: it is booked, and no market changes it until it
# falls inside a control horizon. There the candidate is valued at
# most at the commitment that stands (beyond_control_by_market): a
# restatement that holds it is worth nothing, and one that falls short
# costs the re-purchase the later market will have to make.
# -------------------------------------------------------------
# Outputs
# Named list with:
#   market_utc               : POSIXct vector. MarketUTC of each
#                              target interval, in the same order as
#                              every other element below.
#   E_orig_base_by_market    : Numeric vector. Main_df$Elec_total_plan
#                              summed per target interval, before this
#                              market's optimization.
#   E_orig_gross_by_market   : Numeric vector. The absolute value of
#                              Main_df$Elec_total_plan summed per
#                              target interval, before this market's
#                              optimization: the gross volume the
#                              distribution cost is settled on.
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
#   beyond_control_by_market   : Logical vector. TRUE for the target
#                              intervals after the close of the
#                              control horizon, where the flexibility
#                              a candidate is valued at is capped at
#                              the commitment that stands.
#   stored_energy_price        : Numeric scalar (EUR/kWh). The mean of
#                              the prices at which the market buys
#                              energy over its horizon
#                              (P_import_buy_by_market): the price at
#                              which the energy that the assets leave
#                              stored is valued.
#   stored_energy_discount     : Numeric scalar (-). The revenue
#                              discount factor of the last interval
#                              of the horizon, the one applied to
#                              the value of that energy when it is an
#                              income.
# -------------------------------------------------------------
# Code outline
# 1. Market row (full grid and sparse) and target market intervals
# 2. Baseline commitments before this market (SUM aggregation)
# 3. Current-market prices per target interval
# 4. Price estimate beyond the control horizon
# 5. Revenue discount factors and value of the stored energy
# -------------------------------------------------------------
# Usage instructions
# marginal_context <- resolve_marginal_context(row_index, Main_df,
# simulation_control, market_time, market_index,
# full_market_information, parameters)
# -------------------------------------------------------------

resolve_marginal_context <- function(row_index,
                                     Main_df,
                                     simulation_control,
                                     market_time,
                                     market_index,
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
    # instant_market_slot is called to key the current event by the
    # market interval its clearing instant falls in.
    event_slot <- instant_market_slot(
      time              = Main_df$time[row_index],
      market_resolution = parameters$market$market_resolution
    )
    row_m_full <- match(event_slot, market_time)
    market_rows <- full_market_information$Elec_unit_cost_import_buy_df$time
    row_m <- match(event_slot, market_rows)

    # The intervals to VALUE are those of the whole optimization horizon,
    # not just those of the control horizon. The optimizer decides the
    # setpoints of the whole horizon, so every energy flow and every
    # unit cost of that horizon has to reach the reward; otherwise the
    # tail of the horizon is chosen with no economic consequence at all.
    # What stays bounded to the control horizon is the COMMITMENT, and
    # that lives in settle_market(), which builds its own
    # interval set from idx_ctrl and is not touched by this widening.
    # The separation is what keeps the double counting away without any
    # artifice: the stretch valued with estimated prices never reaches
    # the settlement, so the next market finds those hours with nothing
    # booked on them and values them again with prices it does know.
    idx_target_market <- match(
      sort(unique(Main_df$MarketUTC[simulation_control$indexes_global$idx_horizon])),
      market_time
    )
    market_utc <- market_time[idx_target_market]

    # Close of the control horizon. Everything at or before it has a
    # published price; everything after it has to be estimated, and no
    # flexibility commitment of it may change.
    end_control_time <- max(Main_df$MarketUTC[simulation_control$indexes_global$idx_ctrl])
    beyond_control_by_market <- market_utc > end_control_time

    rm(list = "market_rows")
  }

  # 2. Baseline commitments before this market (SUM aggregation)
  # -------------------------------------------------------------
  # Same aggregation as settle_market()'s E_by_market$orig,
  # over Main_df in its pre-optimization state.
  # -------------------------------------------------------------
  {
    # system_net_energy gives the planned net electricity of the
    # system, which is aggregated per market interval.
    E_orig_base_by_market <- as.numeric(tapply(
      system_net_energy(Main_df, "plan")[simulation_control$indexes_global$idx_horizon],
      Main_df$MarketUTC[simulation_control$indexes_global$idx_horizon], sum
    ))

    # The gross volume of each interval, the sum of the absolute energy
    # of its time steps, is what the distribution cost is settled on:
    # each time step pays for the energy it exchanges, in either
    # direction.
    # The planned net electricity is read again with
    # system_net_energy.
    E_orig_gross_by_market <- as.numeric(tapply(
      abs(system_net_energy(Main_df, "plan")[simulation_control$indexes_global$idx_horizon]),
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
    # .subset2() reads a column without the method of data frames, and
    # gives NULL when the column does not exist.
    price_at <- function(signal_df, col_j) {
      signal_column <- .subset2(signal_df, col_j)
      if (!is.null(signal_column)) return(signal_column[row_m])
      last_col <- tail(setdiff(names(signal_df), "time"), 1)
      signal_df[row_m, last_col]
    }

    # The first row of Main_df of each target interval, found with a
    # single match() instead of comparing the times of every row
    # again for each interval.
    first_row_by_market <- match(as.numeric(market_utc),
                                 as.numeric(Main_df$MarketUTC))

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
      first_row               <- first_row_by_market[CONT_001]
      Flex_Probab_down_target <- Main_df$Flex_Probab_down[first_row]
      Flex_Probab_up_target   <- Main_df$Flex_Probab_up[first_row]

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

      rm(list = c("first_row", "Flex_Probab_down_target",
                  "Flex_Probab_up_target"))
    }
    # intersect with ls(): if idx_target_market were ever empty the
    # loop would not run and CONT_001/i_target/col_j would not exist,
    # and an unconditional rm() would abort with "object not found".
    rm(list = intersect(c("CONT_001", "i_target", "col_j", "price_at",
                          "first_row_by_market"), ls()))
  }

  # 4. Price estimate beyond the control horizon
  # -------------------------------------------------------------
  # Everything read above is the TRUE price of each interval, which for
  # the stretch that exceeds the control horizon is information the
  # optimizer cannot have when it decides. With price_forecast_type
  # "inaccurate", that stretch takes instead the price the markets
  # already know, by the rules of price_estimate_sources():
  #   1. the price of the last earlier market that traded the interval;
  #   2. otherwise, the price of the same interval one day before, from
  #      this market or from the last earlier market that traded it;
  #   3. otherwise, the mean of this market's published prices.
  # The sources depend on the market structure alone, so they are
  # resolved once and applied to every price signal. The activation
  # probabilities are not prices and are left as they are.
  # -------------------------------------------------------------
  {
    price_forecast_type <- parameters$forecast$price_forecast_type

    if (!is.null(price_forecast_type) && price_forecast_type == "inaccurate") {

      # price_estimate_sources is called to say, for each interval
      # beyond the control horizon, where its price is read from.
      sources <- price_estimate_sources(
        target_times      = market_utc,
        end_control_time  = end_control_time,
        event_slot        = event_slot,
        events            = market_index,
        market_resolution = parameters$market$market_resolution
      )

      # estimate_price_signal is called through this helper for each
      # price signal, to read every interval from its source.
      estimate_signal <- function(values, signal_df) {
        estimate_price_signal(
          values    = values,
          signal_df = signal_df,
          sources   = sources
        )
      }

      P_import_buy_by_market  <- estimate_signal(P_import_buy_by_market,
                                                 full_market_information$Elec_unit_cost_import_buy_df)
      P_import_sell_by_market <- estimate_signal(P_import_sell_by_market,
                                                 full_market_information$Elec_unit_cost_import_sell_df)
      P_export_buy_by_market  <- estimate_signal(P_export_buy_by_market,
                                                 full_market_information$Elec_unit_cost_export_buy_df)
      P_export_sell_by_market <- estimate_signal(P_export_sell_by_market,
                                                 full_market_information$Elec_unit_cost_export_sell_df)
      distribution_rate_by_market <- estimate_signal(distribution_rate_by_market,
                                                     full_market_information$Elec_unit_cost_distribution_df)

      p_down_com_buy_by_market   <- estimate_signal(p_down_com_buy_by_market,
                                                    full_market_information$Flex_unit_cost_down_com_buy_df)
      p_down_com_sell_by_market  <- estimate_signal(p_down_com_sell_by_market,
                                                    full_market_information$Flex_unit_cost_down_com_sell_df)
      p_up_com_buy_by_market     <- estimate_signal(p_up_com_buy_by_market,
                                                    full_market_information$Flex_unit_cost_up_com_buy_df)
      p_up_com_sell_by_market    <- estimate_signal(p_up_com_sell_by_market,
                                                    full_market_information$Flex_unit_cost_up_com_sell_df)
      p_down_exec_buy_by_market  <- estimate_signal(p_down_exec_buy_by_market,
                                                    full_market_information$Flex_unit_cost_down_exec_buy_df)
      p_down_exec_sell_by_market <- estimate_signal(p_down_exec_sell_by_market,
                                                    full_market_information$Flex_unit_cost_down_exec_sell_df)
      p_up_exec_buy_by_market    <- estimate_signal(p_up_exec_buy_by_market,
                                                    full_market_information$Flex_unit_cost_up_exec_buy_df)
      p_up_exec_sell_by_market   <- estimate_signal(p_up_exec_sell_by_market,
                                                    full_market_information$Flex_unit_cost_up_exec_sell_df)

      # The effective prices are rebuilt from the estimated halves, so
      # that the two families stay consistent with each other.
      p_down_buy_by_market  <- p_down_com_buy_by_market  + p_down_exec_buy_by_market  * flex_probab_down_by_market
      p_down_sell_by_market <- p_down_com_sell_by_market + p_down_exec_sell_by_market * flex_probab_down_by_market
      p_up_buy_by_market    <- p_up_com_buy_by_market    + p_up_exec_buy_by_market    * flex_probab_up_by_market
      p_up_sell_by_market   <- p_up_com_sell_by_market   + p_up_exec_sell_by_market   * flex_probab_up_by_market

      rm(list = c("sources", "estimate_signal"))
    }

    rm(list = "price_forecast_type")
  }

  # 5. Revenue discount factors and value of the stored energy
  # -------------------------------------------------------------
  # The decision instant H is this market event's own market interval,
  # the one its clearing instant falls in. Every valued interval is
  # then discounted by its distance from it, so that the reward prefers
  # what pays sooner. The factors travel in the context, next to the
  # prices, because they are resolved from the same market row and are
  # constant for every GA candidate of this optimization: computing them
  # here is what keeps them out of the per-candidate inner loop.
  # discount_origin_time travels too, so that reward_function() can
  # build the same factors for the Recovery Phase rows that fall beyond
  # this market's target intervals, exactly as it reads their prices
  # from the period_chunk.
  # The energy the assets leave stored at the end of the horizon is
  # valued at the mean price at which the market buys energy over
  # the horizon. When that value is an income it is discounted with
  # the factor of the last interval of the horizon, since that is
  # where the energy is left. market_utc is sorted, so its last
  # element is that interval.
  # -------------------------------------------------------------
  {
    discount_origin_time <- event_slot

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

    stored_energy_price    <- mean(P_import_buy_by_market)
    stored_energy_discount <-
      revenue_discount_by_market[length(revenue_discount_by_market)]
  }

  rm(list = c("row_m", "row_m_full", "idx_target_market", "end_control_time",
              "event_slot"))

  return(list(
    market_utc               = market_utc,
    E_orig_base_by_market    = E_orig_base_by_market,
    E_orig_gross_by_market   = E_orig_gross_by_market,
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
    discount_origin_time       = discount_origin_time,
    beyond_control_by_market   = beyond_control_by_market,
    stored_energy_price        = stored_energy_price,
    stored_energy_discount     = stored_energy_discount
  ))
}
