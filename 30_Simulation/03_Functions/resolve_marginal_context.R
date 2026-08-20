# -------------------------------------------------------------
# Function: resolve_marginal_context.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
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
#                           indexes_global$idx_ctrl for the current
#                           market's control horizon.
# market_time             : POSIXct vector. Sorted unique MarketUTC
#                           intervals on the full market-resolution
#                           grid; used only to compute future-step
#                           column offsets (col_j).
# full_market_information : Named list of 13 market-event price data
#                           frames (read-only), as built by
#                           full_market_information_setup.R.
# -------------------------------------------------------------
# Outputs
# Named list with:
#   market_utc               : POSIXct vector. MarketUTC of each
#                              target interval, in the same order as
#                              every other element below.
#   E_orig_base_by_market    : Numeric vector. Main_df$Elec_total_plan
#                              summed per target interval, before this
#                              market's optimization.
#   E_orig_expflex_by_market : Numeric vector. Main_df$Elec_flex_plan
#                              summed per target interval, before this
#                              market's optimization.
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
#                              flexibility) - see
#                              01_Agent_Comments/20260722c_Plan_Costes_Distribucion_Recompensa.md.
#   p_up_buy_by_market, p_up_sell_by_market,
#   p_down_buy_by_market, p_down_sell_by_market :
#                              Numeric vectors. Effective up/down
#                              flexibility prices per target interval
#                              (commitment + execution * probability),
#                              ready to pass into the same functions for
#                              the explicit-flexibility term.
# -------------------------------------------------------------
# Code outline
# 1. Market row (full grid and sparse) and target market intervals
# 2. Baseline commitments before this market (SUM aggregation)
# 3. Current-market prices per target interval
# -------------------------------------------------------------
# Usage instructions
# marginal_context <- resolve_marginal_context(row_index, Main_df, simulation_control, market_time, full_market_information)
# -------------------------------------------------------------
# Where this function/script is used
# Called by simulation.R, once per Scheduling/Piloting market process,
# right before run_market_process(), using Main_df in its
# pre-optimization state. The result is passed into
# run_market_process() as marginal_context.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

resolve_marginal_context <- function(row_index,
                                     Main_df,
                                     simulation_control,
                                     market_time,
                                     full_market_information) {

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

    idx_target_market <- match(
      sort(unique(Main_df$MarketUTC[simulation_control$indexes_global$idx_ctrl])),
      market_time
    )
    market_utc <- market_time[idx_target_market]

    rm(market_rows)
  }

  # 2. Baseline commitments before this market (SUM aggregation)
  # -------------------------------------------------------------
  # Same aggregation as integrate_market_process()'s E_orig_*_by_market,
  # over Main_df in its pre-optimization state.
  # -------------------------------------------------------------
  {
    E_orig_base_by_market <- as.numeric(tapply(
      Main_df$Elec_total_plan[simulation_control$indexes_global$idx_ctrl],
      Main_df$MarketUTC[simulation_control$indexes_global$idx_ctrl], sum
    ))

    E_orig_expflex_by_market <- as.numeric(tapply(
      Main_df$Elec_flex_plan[simulation_control$indexes_global$idx_ctrl],
      Main_df$MarketUTC[simulation_control$indexes_global$idx_ctrl], sum
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

    for (CONT_001 in seq_along(idx_target_market)) {
      i_target <- idx_target_market[CONT_001]
      col_j    <- as.character(i_target - row_m_full)

      P_import_buy_by_market[CONT_001]  <- full_market_information$Elec_unit_cost_import_buy_df[row_m, col_j]
      P_import_sell_by_market[CONT_001] <- full_market_information$Elec_unit_cost_import_sell_df[row_m, col_j]
      P_export_buy_by_market[CONT_001]  <- full_market_information$Elec_unit_cost_export_buy_df[row_m, col_j]
      P_export_sell_by_market[CONT_001] <- full_market_information$Elec_unit_cost_export_sell_df[row_m, col_j]
      distribution_rate_by_market[CONT_001] <- full_market_information$Elec_unit_cost_distribution_df[row_m, col_j]

      mkt_target         <- market_utc[CONT_001]
      rows_ts             <- which(Main_df$MarketUTC == mkt_target)
      Flex_Probab_target  <- Main_df$Flex_Probab[rows_ts[1]]

      p_up_buy_by_market[CONT_001]   <- full_market_information$Flex_unit_cost_up_com_buy_df[row_m, col_j] +
        full_market_information$Flex_unit_cost_up_exec_buy_df[row_m, col_j] * Flex_Probab_target
      p_up_sell_by_market[CONT_001]  <- full_market_information$Flex_unit_cost_up_com_sell_df[row_m, col_j] +
        full_market_information$Flex_unit_cost_up_exec_sell_df[row_m, col_j] * Flex_Probab_target
      p_down_buy_by_market[CONT_001]  <- full_market_information$Flex_unit_cost_down_com_buy_df[row_m, col_j] +
        full_market_information$Flex_unit_cost_down_exec_buy_df[row_m, col_j] * Flex_Probab_target
      p_down_sell_by_market[CONT_001] <- full_market_information$Flex_unit_cost_down_com_sell_df[row_m, col_j] +
        full_market_information$Flex_unit_cost_down_exec_sell_df[row_m, col_j] * Flex_Probab_target

      rm(mkt_target, rows_ts, Flex_Probab_target)
    }
    # intersect with ls(): if idx_target_market were ever empty the
    # loop would not run and CONT_001/i_target/col_j would not exist,
    # and an unconditional rm() would abort with "object not found".
    rm(list = intersect(c("CONT_001", "i_target", "col_j"), ls()))
  }

  rm(row_m, row_m_full, idx_target_market)

  return(list(
    market_utc               = market_utc,
    E_orig_base_by_market    = E_orig_base_by_market,
    E_orig_expflex_by_market = E_orig_expflex_by_market,
    P_import_buy_by_market   = P_import_buy_by_market,
    P_import_sell_by_market  = P_import_sell_by_market,
    P_export_buy_by_market   = P_export_buy_by_market,
    P_export_sell_by_market  = P_export_sell_by_market,
    distribution_rate_by_market = distribution_rate_by_market,
    p_up_buy_by_market       = p_up_buy_by_market,
    p_up_sell_by_market      = p_up_sell_by_market,
    p_down_buy_by_market     = p_down_buy_by_market,
    p_down_sell_by_market    = p_down_sell_by_market
  ))
}
