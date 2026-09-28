# -------------------------------------------------------------
# Function: integrate_market_process.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Integrates the result of a single Scheduling or Piloting market
# execution into Main_df and the market-event output matrices,
# for the current simulation step. This is the "4. Integrate results"
# logic shared by the Scheduling and Piloting blocks of 14_simulation.R:
#   4.1 Locate the market row of the current step and the target
#       market intervals covered by this market's control horizon.
#   4.2 Aggregate (SUM) the previous and new commitments per target
#       interval, for:
#         - base energy
#         - energy with flexibility
#         - explicit flexibility
#   4.3 Accumulate the differential energy commitments into these
#       market_commitments matrices:
#         - net/buy/sell
#         - their _flex counterparts
#         - the explicit flexibility buy/sell matrices
#   4.4 Write the absolute *_plan/*_plan_flex_down columns into Main_df.
#       Only two things are committed: the energy of the _plan
#       itinerary and the phase-1 flexibility. The energy of the
#       Recovery Phase is contingent on the service being called, so it
#       is valued by reward_function() to steer the decision but never
#       settled here.
#   4.5 Accumulate the net cash flow of the explicit-flexibility service
#       (both down and up legs, for both Scheduling and Piloting - see
#       finding 3 of the audit referenced below) into
#       market_commitments$Elec_flex_Cost_plan_df and propagate it into
#       Main_df$Elec_flex_commitment_revenue_h; also add the sold/
#       bought-back totals, on this decision's own row, to
#       Main_df$Elec_flex_sell_revenue_market (income, +=) and
#       Elec_flex_purchase_cost_market (expense, -=).
#   4.6 Accumulate the net cash flow of the energy commitment (the base
#       energy track, for both market families) into
#       market_commitments$Elec_Cost_plan_df and propagate it into
#       Main_df$Elec_market_net_cost_h; also split the same
#       differential into its elementary buy/rebuy/sell/resell
#       operations (split_market_operation()) and add their totals, on
#       this decision's own row, to Main_df$Elec_sell_revenue_market
#       (income, +=) and Elec_purchase_cost_market (expense, -=).
#   4.7 Book the total reward of this decision on its own row: the sum
#       of the per-timestep rewards over the optimization horizon, which
#       is the total the optimizer maximised.
# See 01_Agent_Comments/20260725_Plan_Reporte_Costes_Mercados_Main_df.md
# for the original design of these signals, and
# 01_Agent_Comments/20260817_Auditoria_Consistencia_Economica.md plus
# 00_Agent_Input/20260818_comentarios_observaciones_anteriores.md for
# the sign convention (income positive, expense negative, throughout)
# and the fix that registers flexibility economics for Scheduling too.
# full_market_information and market_commitments have one row per
# market event (not one row per market-resolution interval), while
# their future-step columns still refer to market-resolution-grid
# offsets. Column offsets (col_j) are therefore computed against
# market_time (the full market-resolution grid, used only for this
# arithmetic), while actual matrix reads/writes are indexed by
# row_m, the row of the current event within full_market_information/
# market_commitments' own (sparse) row set.
# -------------------------------------------------------------
# Inputs
# prefix              : Character. "Sched" or "Pilot". Says whether the
#                        target slots count towards economic_analysis$slot's
#                        "committed in Scheduling" fraction. It does not
#                        select an energy track: both families settle the
#                        base energy of the _plan itinerary.
# row_index           : Integer. Current simulation row index (CONT_003).
# results_df          : Data frame. scheduling_results or
#                        piloting_results, as returned by
#                        run_market_process(), with MarketUTC, the
#                        *_plan/*_plan_flex_down columns for the market's
#                        control horizon, and the per-timestep Reward of
#                        that same window.
# Main_df             : Data frame. The main simulation data frame.
# simulation_control  : Named list. Must contain
#                        indexes_global$idx_ctrl and
#                        indexes_local$idx_ctrl for the current market.
# market_time         : POSIXct vector. Sorted unique MarketUTC
#                        intervals on the full market-resolution grid;
#                        used only to compute future-step column
#                        offsets (col_j), not as the matrices' row set.
# full_market_information : Named list of 13 market-event price data
#                        frames (read-only), as built by
#                        11_full_market_information_setup.R.
# market_commitments  : Named list of 12 market-event output data
#                        frames, as built by 12_market_commitments_setup.R.
# economic_analysis   : Named list of economic-analysis accumulators
#                        (market, slot and the index sub-list), as built
#                        by 13_economic_analysis_setup.R.
# -------------------------------------------------------------
# Outputs
# Named list with:
#   Main_df            : Data frame. Updated with the absolute *_plan/
#                        *_plan_flex_down columns, the propagated
#                        Elec_market_net_cost_h and
#                        Elec_flex_commitment_revenue_h columns, and the
#                        "_market" lump-sum columns on row_index -
#                        Elec_purchase_cost_market / Elec_sell_revenue_market
#                        and Elec_flex_purchase_cost_market /
#                        Elec_flex_sell_revenue_market, all four
#                        regardless of prefix (income positive, expense
#                        negative) - plus Reward, the total reward of
#                        this decision, also on row_index.
#   market_commitments : Named list. Updated in place with the
#                        differential energy and cost commitments of
#                        this market execution.
#   economic_analysis  : Named list. Updated in place with this market
#                        execution's elementary operations, on the
#                        economic_analysis$market row that owns each target slot
#                        and on the economic_analysis$slot row of that slot.
# -------------------------------------------------------------
# Code outline
# 1. Market row and target market intervals
# 1b. Attribution of each target slot to an economic_analysis$market row
# 2. Per-interval commitments before/after the market (SUM aggregation)
# 3. Accumulate the differential commitments in the output matrices
#    (also resolves the explicit-flexibility net cash flow per interval)
# 4. Absolute update of Main_df
# 4b. Explicit flexibility cost/revenue (Scheduling and Piloting alike)
# 5. Differential cost of the energy commitment (base energy track, for
#    both market families)
# 5b. Reward of this decision, totalled on its own row
# -------------------------------------------------------------
# Usage instructions
# result             <- integrate_market_process(prefix, row_index, results_df, Main_df, simulation_control, market_time, full_market_information, market_commitments, economic_analysis)
# Main_df            <- result$Main_df
# market_commitments <- result$market_commitments
# economic_analysis  <- result$economic_analysis
# -------------------------------------------------------------
# Where this function/script is used
# Called by 14_simulation.R once per Scheduling execution and once per
# Piloting execution, in the main simulation loop.
# -------------------------------------------------------------
# functions/scripts called
# value_flex_operation(), propagate_unit_value(),
# propagate_differential_cost(), split_market_operation(),
# accumulate_market_operation()
# -------------------------------------------------------------

integrate_market_process <- function(prefix,
                                     row_index,
                                     results_df,
                                     Main_df,
                                     simulation_control,
                                     market_time,
                                     full_market_information,
                                     market_commitments,
                                     economic_analysis) {

  if (!prefix %in% c("Sched", "Pilot")) {
    stop("integrate_market_process: prefix must be 'Sched' or 'Pilot'")
  }

  # 1. Market row of the current step and target market intervals
  # -------------------------------------------------------------
  # row_m_full is the position of the current event on the full
  # market-resolution grid (market_time); it is only used to compute
  # col_j offsets, which stay valid market-resolution-step counts
  # regardless of how sparse the matrices' own row set is. row_m is
  # the position of the current event within full_market_information/
  # market_commitments' own (sparse, market-event) row set, and is
  # what actually indexes into those matrices.
  # -------------------------------------------------------------
  {
    row_m_full <- match(Main_df$MarketUTC[row_index], market_time)
    market_rows <- full_market_information$Elec_unit_cost_import_buy_df$time
    row_m <- match(Main_df$MarketUTC[row_index], market_rows)

    idx_target_market <- match(
      sort(unique(Main_df$MarketUTC[simulation_control$indexes_global$idx_ctrl])),
      market_time
    )

    rm(market_rows)
  }

  # 1b. Attribution of each target slot to an economic_analysis$market row
  # -------------------------------------------------------------
  # Every economic flow this market produces on a target slot has to be
  # reported on exactly one row of economic_analysis$market. When a Scheduling
  # and a Piloting market clear at the same timestamp, the slots the
  # Scheduling market covers are reported on the Scheduling row - no
  # matter which of the two decisions actually produced the flow - and
  # the remaining slots on the Piloting row (see 13_economic_analysis_setup.R).
  # A Scheduling market therefore always reports its own slots, and it
  # records them in economic_analysis$index$sched_claim so that the Piloting
  # market clearing at the same row_index (14_simulation.R always runs the
  # Scheduling block first) can hand those same slots over to it. The
  # claim carries its row_index so that a stale claim from an earlier
  # simulation step is never reused.
  # -------------------------------------------------------------
  {
    slot_pos <- match(as.numeric(market_time[idx_target_market]),
                      economic_analysis$index$slot_key)

    # The reporting row belongs to the market that took the decision,
    # so it is looked up at the decision's own timestamp, not at the
    # target slot's timestamp.
    decision_pos   <- match(as.numeric(Main_df$MarketUTC[row_index]),
                            economic_analysis$index$slot_key)
    row_sched_here <- economic_analysis$index$row_sched[decision_pos]
    row_pilot_here <- economic_analysis$index$row_pilot[decision_pos]

    if (prefix == "Sched") {
      analysis_dest_row <- rep(row_sched_here, length(idx_target_market))
      economic_analysis$index$sched_claim <- list(row_index = row_index, slot_pos = slot_pos)
    } else {
      claimed_slot_pos <- integer(0)
      if (!is.null(economic_analysis$index$sched_claim) &&
          economic_analysis$index$sched_claim$row_index == row_index) {
        claimed_slot_pos <- economic_analysis$index$sched_claim$slot_pos
      }

      analysis_dest_row <- ifelse(
        slot_pos %in% claimed_slot_pos,
        row_sched_here,
        row_pilot_here
      )

      rm(claimed_slot_pos)
    }

    rm(decision_pos, row_sched_here, row_pilot_here)
  }

  # 2. Per-interval commitments before/after the market (SUM aggregation)
  {
    E_orig_base_by_market    <- as.numeric(tapply(
      Main_df$Elec_total_plan[simulation_control$indexes_global$idx_ctrl],
      Main_df$MarketUTC[simulation_control$indexes_global$idx_ctrl], sum
    ))
    E_new_base_by_market     <- as.numeric(tapply(
      results_df$Elec_total_plan[simulation_control$indexes_local$idx_ctrl],
      results_df$MarketUTC[simulation_control$indexes_local$idx_ctrl], sum
    ))

    E_orig_flex_by_market    <- as.numeric(tapply(
      Main_df$Elec_total_plan_flex_down[simulation_control$indexes_global$idx_ctrl],
      Main_df$MarketUTC[simulation_control$indexes_global$idx_ctrl], sum
    ))
    E_new_flex_by_market     <- as.numeric(tapply(
      results_df$Elec_total_plan_flex_down[simulation_control$indexes_local$idx_ctrl],
      results_df$MarketUTC[simulation_control$indexes_local$idx_ctrl], sum
    ))

    # One aggregate per leg, before and after this market's decision.
    # The two signals are non-negative by construction, so a single
    # aggregate would net a downward commitment against an upward one
    # and value the difference as if it were one service.
    E_orig_expflex_down_by_market <- as.numeric(tapply(
      Main_df$Elec_flex_down_plan[simulation_control$indexes_global$idx_ctrl],
      Main_df$MarketUTC[simulation_control$indexes_global$idx_ctrl], sum
    ))
    E_new_expflex_down_by_market  <- as.numeric(tapply(
      results_df$Elec_flex_down_plan[simulation_control$indexes_local$idx_ctrl],
      results_df$MarketUTC[simulation_control$indexes_local$idx_ctrl], sum
    ))

    E_orig_expflex_up_by_market <- as.numeric(tapply(
      Main_df$Elec_flex_up_plan[simulation_control$indexes_global$idx_ctrl],
      Main_df$MarketUTC[simulation_control$indexes_global$idx_ctrl], sum
    ))
    E_new_expflex_up_by_market  <- as.numeric(tapply(
      results_df$Elec_flex_up_plan[simulation_control$indexes_local$idx_ctrl],
      results_df$MarketUTC[simulation_control$indexes_local$idx_ctrl], sum
    ))

    # The energy of the Recovery Phase is deliberately NOT aggregated
    # here. A market commits two things and only two: the energy bought
    # and sold on the _plan itinerary, and the flexibility of the
    # Commitment Phase, the phase-1 differential between _plan and each
    # flexibility itinerary. The rebuy the building would make while
    # recovering is contingent on the operator calling the service, so
    # committing it would book an operation that may never happen.
    # Its future price does have to weigh on the decision, and it does:
    # reward_function() values it through compute_recovery_energy_cost(),
    # which is where a contingent cost belongs. Valuing it to choose and
    # committing it to settle are different things, and this block only
    # settles.
  }

  # 3. Accumulate the differential commitments in the output matrices
  # -------------------------------------------------------------
  # Also resolves, per target interval and per leg, the
  # explicit-flexibility net cash flow (flex_revenue_down_by_market/
  # flex_buyback_down_by_market and their up-leg counterparts) that
  # block 4b propagates into Main_df/market_commitments once Main_df's
  # weight columns (Elec_flex_down_plan and Elec_flex_up_plan) have their
  # post-decision value - see block 4b's own header for why that
  # propagation cannot happen here. The cash flow is kept split by leg
  # because each leg is spread over Main_df with its own weight column.
  # -------------------------------------------------------------
  {
    flex_revenue_down_by_market  <- numeric(length(idx_target_market))
    flex_buyback_down_by_market  <- numeric(length(idx_target_market))
    flex_revenue_up_by_market    <- numeric(length(idx_target_market))
    flex_buyback_up_by_market    <- numeric(length(idx_target_market))

    for (CONT_001 in seq_along(idx_target_market)) {
      i_target <- idx_target_market[CONT_001]
      col_j    <- as.character(i_target - row_m_full)

      E_orig  <- E_orig_base_by_market[CONT_001]
      E_new   <- E_new_base_by_market[CONT_001]
      delta_E <- E_new - E_orig

      market_commitments$Elec_net_plan_df[[col_j]][row_m] <- market_commitments$Elec_net_plan_df[[col_j]][row_m] + delta_E

      buy_orig <- max(E_orig, 0); sell_orig <- min(E_orig, 0)
      buy_new  <- max(E_new,  0); sell_new  <- min(E_new,  0)

      market_commitments$Elec_buy_plan_df[[col_j]][row_m]  <- market_commitments$Elec_buy_plan_df[[col_j]][row_m]  + (buy_new  - buy_orig)
      market_commitments$Elec_sell_plan_df[[col_j]][row_m] <- market_commitments$Elec_sell_plan_df[[col_j]][row_m] + (sell_new - sell_orig)

      E_orig_flex  <- E_orig_flex_by_market[CONT_001]
      E_new_flex   <- E_new_flex_by_market[CONT_001]
      delta_E_flex <- E_new_flex - E_orig_flex

      market_commitments$Elec_net_plan_flex_down_df[[col_j]][row_m] <- market_commitments$Elec_net_plan_flex_down_df[[col_j]][row_m] + delta_E_flex

      buy_orig_flex <- max(E_orig_flex, 0); sell_orig_flex <- min(E_orig_flex, 0)
      buy_new_flex  <- max(E_new_flex,  0); sell_new_flex  <- min(E_new_flex,  0)

      market_commitments$Elec_buy_plan_flex_down_df[[col_j]][row_m]  <- market_commitments$Elec_buy_plan_flex_down_df[[col_j]][row_m]  + (buy_new_flex  - buy_orig_flex)
      market_commitments$Elec_sell_plan_flex_down_df[[col_j]][row_m] <- market_commitments$Elec_sell_plan_flex_down_df[[col_j]][row_m] + (sell_new_flex - sell_orig_flex)

      # Explicit flexibility, one leg at a time.
      # Elec_flex_down_plan and Elec_flex_up_plan are two independent
      # signals, each of them a volume >= 0: the first is the load the
      # building commits to shed during its Commitment Phase, the second the
      # load it commits to add. The move from the previous to the new
      # volume is either a sale (the leg grows: more service committed
      # to the grid, income) or a buy back (the leg shrinks: part of a
      # commitment sold in an earlier market is unwound, expense).
      # value_flex_operation() tells the two legs apart by the sign of
      # the series it is given, so the up leg is passed negated; both
      # series being non-negative, each call activates only its own leg
      # and the other one comes back at zero. Netting them into a single
      # signed series instead would silently cancel a downward
      # commitment against an upward one in the same interval.
      # Each leg is valued at its own effective price (commitment price
      # plus execution price weighted by that leg's own activation
      # probability) - see value_flex_operation()'s header for why this
      # cannot be valued via calc_differential_cost()/
      # split_market_operation() the way energy is.
      # Each leg is weighted by its own activation probability, exactly as
      # resolve_marginal_context() does when it prices the same interval
      # for the optimizer.
      rows_target_ts          <- which(Main_df$MarketUTC == market_time[i_target])
      flex_probab_down_target <- Main_df$Flex_Probab_down[rows_target_ts[1]]
      flex_probab_up_target   <- Main_df$Flex_Probab_up[rows_target_ts[1]]
      price_down_sell <- full_market_information$Flex_unit_cost_down_com_sell_df[[col_j]][row_m] +
        full_market_information$Flex_unit_cost_down_exec_sell_df[[col_j]][row_m] * flex_probab_down_target
      price_down_buy  <- full_market_information$Flex_unit_cost_down_com_buy_df[[col_j]][row_m] +
        full_market_information$Flex_unit_cost_down_exec_buy_df[[col_j]][row_m]  * flex_probab_down_target
      price_up_sell   <- full_market_information$Flex_unit_cost_up_com_sell_df[[col_j]][row_m] +
        full_market_information$Flex_unit_cost_up_exec_sell_df[[col_j]][row_m]   * flex_probab_up_target
      price_up_buy    <- full_market_information$Flex_unit_cost_up_com_buy_df[[col_j]][row_m] +
        full_market_information$Flex_unit_cost_up_exec_buy_df[[col_j]][row_m]    * flex_probab_up_target

      # value_flex_operation is called once per leg, to resolve this
      # target interval's move from E_orig_expflex to E_new_expflex into
      # its sold and bought-back volumes and their net cash flow.
      flex_op_down <- value_flex_operation(
        E_orig          = E_orig_expflex_down_by_market[CONT_001],
        E_new           = E_new_expflex_down_by_market[CONT_001],
        price_down_sell = price_down_sell,
        price_down_buy  = price_down_buy,
        price_up_sell   = price_up_sell,
        price_up_buy    = price_up_buy
      )
      flex_op_up <- value_flex_operation(
        E_orig          = -E_orig_expflex_up_by_market[CONT_001],
        E_new           = -E_new_expflex_up_by_market[CONT_001],
        price_down_sell = price_down_sell,
        price_down_buy  = price_down_buy,
        price_up_sell   = price_up_sell,
        price_up_buy    = price_up_buy
      )

      flex_revenue_down_by_market[CONT_001] <- flex_op_down$down_sold   * price_down_sell
      flex_buyback_down_by_market[CONT_001] <- flex_op_down$down_bought * price_down_buy
      flex_revenue_up_by_market[CONT_001]   <- flex_op_up$up_sold       * price_up_sell
      flex_buyback_up_by_market[CONT_001]   <- flex_op_up$up_bought     * price_up_buy


      market_commitments$Elec_flex_down_sell_plan_df[[col_j]][row_m] <-
        market_commitments$Elec_flex_down_sell_plan_df[[col_j]][row_m] + flex_op_down$down_sold
      market_commitments$Elec_flex_down_buy_plan_df[[col_j]][row_m] <-
        market_commitments$Elec_flex_down_buy_plan_df[[col_j]][row_m]  + flex_op_down$down_bought
      market_commitments$Elec_flex_up_sell_plan_df[[col_j]][row_m] <-
        market_commitments$Elec_flex_up_sell_plan_df[[col_j]][row_m]   + flex_op_up$up_sold
      market_commitments$Elec_flex_up_buy_plan_df[[col_j]][row_m] <-
        market_commitments$Elec_flex_up_buy_plan_df[[col_j]][row_m]    + flex_op_up$up_bought

      dest_row  <- analysis_dest_row[CONT_001]
      dest_slot <- slot_pos[CONT_001]

      # The two legs are booked together here: the accounting tables
      # record the market's whole flexibility position, and each of
      # them already has its own down and up columns.
      flex_cash_flow  <- flex_op_down$revenue + flex_op_up$revenue
      flex_buyback_ti <- flex_buyback_down_by_market[CONT_001] +
                         flex_buyback_up_by_market[CONT_001]

      economic_analysis$market$Flex_down_sold[dest_row]     <- economic_analysis$market$Flex_down_sold[dest_row]     + flex_op_down$down_sold
      economic_analysis$market$Flex_down_rebought[dest_row] <- economic_analysis$market$Flex_down_rebought[dest_row] + flex_op_down$down_bought
      economic_analysis$market$Flex_up_sold[dest_row]       <- economic_analysis$market$Flex_up_sold[dest_row]       + flex_op_up$up_sold
      economic_analysis$market$Flex_up_rebought[dest_row]   <- economic_analysis$market$Flex_up_rebought[dest_row]   + flex_op_up$up_bought
      economic_analysis$market$Cash_flow[dest_row]          <- economic_analysis$market$Cash_flow[dest_row]          + flex_cash_flow
      economic_analysis$market$PL_rebuy_resale[dest_row]    <- economic_analysis$market$PL_rebuy_resale[dest_row]    - flex_buyback_ti

      economic_analysis$slot$Flex_down_committed[dest_slot]      <- economic_analysis$slot$Flex_down_committed[dest_slot]      + flex_op_down$down_sold
      economic_analysis$slot$Flex_up_committed[dest_slot]        <- economic_analysis$slot$Flex_up_committed[dest_slot]        + flex_op_up$up_sold
      economic_analysis$slot$Flex_committed[dest_slot]           <- economic_analysis$slot$Flex_committed[dest_slot]           + flex_op_down$down_sold + flex_op_up$up_sold
      economic_analysis$slot$Qty_flex_rebought[dest_slot]        <- economic_analysis$slot$Qty_flex_rebought[dest_slot]        + flex_op_down$down_bought + flex_op_up$up_bought
      economic_analysis$slot$Revenue_flex_commitments[dest_slot] <- economic_analysis$slot$Revenue_flex_commitments[dest_slot] + flex_cash_flow
      economic_analysis$slot$Cash_flow[dest_slot]                <- economic_analysis$slot$Cash_flow[dest_slot]                + flex_cash_flow
      economic_analysis$slot$Val_rebuy_resale[dest_slot]         <- economic_analysis$slot$Val_rebuy_resale[dest_slot]         + flex_buyback_ti
    }

    # Only variables the loop actually created are removed (intersect
    # with ls()): if idx_target_market were ever empty, the loop would
    # not run and none of these would exist, and an unconditional rm()
    # would abort with "object not found" instead of simply having
    # nothing to clean up.
    rm(list = intersect(
      c("CONT_001", "i_target", "col_j",
        "E_orig", "E_new", "delta_E", "buy_orig", "sell_orig", "buy_new", "sell_new",
        "E_orig_flex", "E_new_flex", "delta_E_flex",
        "buy_orig_flex", "sell_orig_flex", "buy_new_flex", "sell_new_flex",
        "rows_target_ts", "flex_probab_down_target", "flex_probab_up_target",
        "price_down_sell", "price_down_buy",
        "price_up_sell", "price_up_buy", "flex_op_down", "flex_op_up",
        "flex_cash_flow", "flex_buyback_ti",
        "dest_row", "dest_slot"),
      ls()
    ))
  }

  # 4. Absolute update of Main_df (plan and plan_flex_down columns)
  # -------------------------------------------------------------
  # Main_df is a data.table (see 14_simulation.R's "Data frame
  # formatting" block), so the market's result is written straight
  # into its existing columns with data.table::set() instead of
  # rebuilding the whole object once per market. results_df is a
  # plain data frame, so it keeps ordinary data.frame indexing.
  # -------------------------------------------------------------
  {
    inject_cols <- grep("(_plan$|_plan_flex_down$|_plan_flex_up$)", names(results_df), value = TRUE)

    # The phase codes are the optimizer's own labels: scratch state of
    # the search, reset on every candidate by
    # initialize_plan_flex_columns(), and they match the pattern above
    # only because of how they are named. They are not written back.
    # Nothing here reads them any more: the settlement commits the energy
    # of the _plan itinerary and the phase-1 flexibility, and neither
    # needs the label once the contingent recovery stopped being
    # committed.
    inject_cols <- setdiff(inject_cols,
                           c("Flex_phase_down_plan", "Flex_phase_up_plan"))

    for (CONT_005 in inject_cols) {
      set(Main_df,
          i     = simulation_control$indexes_global$idx_ctrl,
          j     = CONT_005,
          value = results_df[[CONT_005]][simulation_control$indexes_local$idx_ctrl])
    }

    rm(list = intersect(c("inject_cols", "CONT_005"), ls()))
  }

  # 4b. Explicit flexibility cost/revenue (both Scheduling and Piloting)
  # -------------------------------------------------------------
  # Registered for every market that can commit flexibility, not just
  # Piloting: a Scheduling market with a flexibility-inclusive aim takes
  # this same economic decision (see resolve_marginal_context.R and
  # reward_function.R, which already value it regardless of prefix) and
  # it must leave the same kind of entry - see
  # 01_Agent_Comments/20260817_Auditoria_Consistencia_Economica.md
  # (finding 3) and 00_Agent_Input/20260818_comentarios_observaciones_anteriores.md.
  # Runs after block 4 (not inside block 3, where the per-interval net
  # cash flow was resolved) because propagate_unit_value() spreads that
  # cash flow across Main_df's rows weighted by the leg's own signal,
  # Elec_flex_down_plan or Elec_flex_up_plan, which must already carry
  # this decision's own (post-update) value for the weighting to be
  # correct - the same ordering block 5 already relies on for the energy
  # term below.
  # One propagation per leg, because the two have different weights: the
  # rows where the building committed to shed load are not the rows
  # where it committed to add it, and a single propagation would spread
  # each leg's cash flow over the other leg's rows.
  # -------------------------------------------------------------
  {
    flex_sell_revenue_total  <- 0
    flex_purchase_cost_total <- 0

    for (CONT_004 in seq_along(idx_target_market)) {
      i_target   <- idx_target_market[CONT_004]
      col_j      <- as.character(i_target - row_m_full)
      mkt_target <- market_time[i_target]

      # propagate_unit_value is called once per leg, to accumulate this
      # target interval's already-resolved explicit-flexibility net cash
      # flow into market_commitments$Elec_flex_Cost_plan_df and to spread
      # its unit value across Main_df$Elec_flex_commitment_revenue_h,
      # weighted by that leg's own signal. Both legs accumulate into the
      # same cost matrix and the same Main_df column: what the split
      # changes is which rows each leg's cash flow lands on.
      for (CONT_006 in c("down", "up")) {
        if (CONT_006 == "down") {
          delta_C_leg <- flex_revenue_down_by_market[CONT_004] -
                         flex_buyback_down_by_market[CONT_004]
          weight_col_leg <- "Elec_flex_down_plan"
        } else {
          delta_C_leg <- flex_revenue_up_by_market[CONT_004] -
                         flex_buyback_up_by_market[CONT_004]
          weight_col_leg <- "Elec_flex_up_plan"
        }

        prop_result <- propagate_unit_value(
          row_m      = row_m,
          col_j      = col_j,
          mkt_target = mkt_target,
          delta_C    = delta_C_leg,
          cost_df    = market_commitments$Elec_flex_Cost_plan_df,
          Main_df    = Main_df,
          weight_col = weight_col_leg,
          target_col = "Elec_flex_commitment_revenue_h"
        )
        Main_df                                  <- prop_result$Main_df
        market_commitments$Elec_flex_Cost_plan_df <- prop_result$cost_df

        rm(delta_C_leg, weight_col_leg, prop_result)
      }
      rm(list = intersect("CONT_006", ls()))

      flex_sell_revenue_total  <- flex_sell_revenue_total  +
        flex_revenue_down_by_market[CONT_004] + flex_revenue_up_by_market[CONT_004]
      flex_purchase_cost_total <- flex_purchase_cost_total +
        flex_buyback_down_by_market[CONT_004] + flex_buyback_up_by_market[CONT_004]

      rm(i_target, col_j, mkt_target)
    }
    rm(list = intersect("CONT_004", ls()))

    set(Main_df, i = row_index, j = "Elec_flex_sell_revenue_market",
        value = Main_df$Elec_flex_sell_revenue_market[row_index]  + flex_sell_revenue_total)
    set(Main_df, i = row_index, j = "Elec_flex_purchase_cost_market",
        value = Main_df$Elec_flex_purchase_cost_market[row_index] - flex_purchase_cost_total)
    rm(flex_sell_revenue_total, flex_purchase_cost_total,
       flex_revenue_down_by_market, flex_buyback_down_by_market,
       flex_revenue_up_by_market, flex_buyback_up_by_market)
  }

  # 5. Differential cost of the energy commitment, always on the base
  #    energy track. For every target interval, in addition to the
  #    existing propagation into Main_df$Elec_market_net_cost_h (the
  #    same energy-weighted accumulation mechanism as before), the
  #    elementary buy/rebuy/sell/resell operations of the very same
  #    differential (split_market_operation()) are summed across this
  #    decision's whole (implementation-horizon) target-interval set
  #    and added, with `+=`/`-=`, to the "_market" lump-sum signals on
  #    this decision's own row (row_index) - Elec_sell_revenue_market
  #    (income, positive) and Elec_purchase_cost_market (expense,
  #    negative) - so that a row where both a Scheduling and a Piloting
  #    market clear accumulates both contributions.
  #    The energy bought and sold is the one of the _plan itinerary, for
  #    both market families alike. The flexibility itineraries are not
  #    settled here: what they move is sold as the flexibility service,
  #    in block 4b, valued on Elec_flex_down_plan/Elec_flex_up_plan.
  #    Settling Piloting on Elec_total_plan_flex_down instead, as this
  #    block used to, booked the building as buying the energy of an
  #    itinerary it only flies if the operator calls the service: it
  #    disagreed with what the building consumes (Elec_total_exec), with
  #    what the reward values (reward_function() prices energy on
  #    Elec_total_plan for every aim), and it paid the same reduction
  #    twice, once as energy not bought and again as flexibility sold.
  #    See 01_Agent_Comments/20260915_Propuesta_Correccion_Energia_Liquidada.md.
  #    prefix therefore no longer selects an energy track; it only says
  #    whether the target slot counts towards economic_analysis$slot's
  #    "committed in Scheduling" fraction.
  {
    E_orig_sel     <- E_orig_base_by_market
    E_new_sel      <- E_new_base_by_market
    weight_col_sel <- "Elec_total_plan"
    is_sched_sel   <- (prefix == "Sched")

    purchase_cost_total <- 0
    sell_revenue_total  <- 0

    for (CONT_002 in seq_along(idx_target_market)) {
      i_target   <- idx_target_market[CONT_002]
      col_j      <- as.character(i_target - row_m_full)
      mkt_target <- market_time[i_target]

      P_import_buy  <- full_market_information$Elec_unit_cost_import_buy_df[[col_j]][row_m]
      P_import_sell <- full_market_information$Elec_unit_cost_import_sell_df[[col_j]][row_m]
      P_export_buy  <- full_market_information$Elec_unit_cost_export_buy_df[[col_j]][row_m]
      P_export_sell <- full_market_information$Elec_unit_cost_export_sell_df[[col_j]][row_m]

      # propagate_differential_cost is called to value this decision's
      # base-energy commitment change at this target interval's prices,
      # and to accumulate that differential into
      # Main_df$Elec_market_net_cost_h weighted by weight_col_sel.
      result <- propagate_differential_cost(
        row_m         = row_m,
        col_j         = col_j,
        mkt_target    = mkt_target,
        E_orig        = E_orig_sel[CONT_002],
        E_new         = E_new_sel[CONT_002],
        P_import_buy  = P_import_buy,
        P_import_sell = P_import_sell,
        P_export_buy  = P_export_buy,
        P_export_sell = P_export_sell,
        cost_df    = market_commitments$Elec_Cost_plan_df,
        Main_df    = Main_df,
        weight_col = weight_col_sel,
        target_col = "Elec_market_net_cost_h"
      )
      Main_df                             <- result$Main_df
      market_commitments$Elec_Cost_plan_df <- result$cost_df

      # split_market_operation is called to break the very same
      # energy differential into the four elementary operations:
      #   - new buy
      #   - buy back
      #   - new sell
      #   - resell
      # Their values aggregate into
      # the cost/revenue pair used by this decision's own-row lump-sum
      # market signals below, and their quantities and values feed the
      # economic_analysis tables.
      # The two unwinding operations are reported against the flow they
      # cancel, not as a flow of the opposite kind: a resale is an
      # avoided cost and a rebuy an avoided revenue - the same rule
      # accumulate_market_operation() applies to the economic_analysis tables,
      # so that Main_df's "_market" columns and economic_analysis$slot cannot
      # disagree about what a cost and a revenue are. See
      # accumulate_market_operation()'s header.
      operation <- split_market_operation(
        E_orig_sel[CONT_002], E_new_sel[CONT_002],
        P_import_buy, P_import_sell, P_export_buy, P_export_sell
      )
      purchase_cost_total <- purchase_cost_total + operation$val_buy_new  - operation$val_sell_back
      sell_revenue_total  <- sell_revenue_total  + operation$val_sell_new - operation$val_buy_back

      # accumulate_market_operation is called to report the same four
      # operations on the economic_analysis row and slot that own this target
      # interval, which is what makes economic_analysis$market and economic_analysis$slot
      # add up to the whole simulation. is_sched_sel is FALSE for
      # Piloting: a Piloting decision never counts towards the
      # "committed in Scheduling" fraction of economic_analysis$slot, even when
      # its flows are reported on a Scheduling row because that market
      # owns the slot.
      economic_analysis <- accumulate_market_operation(
        economic_analysis = economic_analysis,
        operation     = operation,
        dest_row      = analysis_dest_row[CONT_002],
        dest_slot     = slot_pos[CONT_002],
        is_scheduling = is_sched_sel
      )

      rm(i_target, col_j, mkt_target, result, operation,
         P_import_buy, P_import_sell, P_export_buy, P_export_sell)
    }
    rm(list = intersect("CONT_002", ls()))

    set(Main_df, i = row_index, j = "Elec_purchase_cost_market",
        value = Main_df$Elec_purchase_cost_market[row_index] - purchase_cost_total)
    set(Main_df, i = row_index, j = "Elec_sell_revenue_market",
        value = Main_df$Elec_sell_revenue_market[row_index]  + sell_revenue_total)

    # 5b. Reward of this decision
    # -------------------------------------------------------------
    # reward_function() evaluates the reward per timestep, and what the
    # optimizer maximises is its total over the window it decides. That
    # total belongs to the decision, not to the hours it plans: a market
    # clearing at hour 2 for the period that runs from hour 20 to hour 25
    # books, on row 2, the sum of the rewards of rows 20 to 25. Spreading
    # it over those rows instead would suggest the reward was earned
    # there, and adding it up across markets would then count the same
    # hours once per market that planned them.
    # The window summed is the OPTIMIZATION horizon (idx_horizon), not
    # the market's period: reward_function() evaluates the reward over
    # that whole horizon and the optimizer maximises its total, so any
    # narrower window would report a number the search never compared
    # its candidates on. It is the one quantity here that is not bounded
    # to what the market commits, because it is not a commitment: it is
    # the value of the decision.
    # Accumulated rather than assigned, like the lump-sum signals above,
    # so that a row where both a Scheduling and a Piloting market clear
    # carries both decisions.
    # -------------------------------------------------------------
    set(Main_df, i = row_index, j = "Reward",
        value = Main_df$Reward[row_index] +
          sum(results_df$Reward[simulation_control$indexes_local$idx_horizon],
              na.rm = TRUE))
    rm(E_orig_sel, E_new_sel, weight_col_sel, is_sched_sel,
       purchase_cost_total, sell_revenue_total)
  }

  rm(row_m, row_m_full, idx_target_market, slot_pos, analysis_dest_row,
     E_orig_base_by_market, E_new_base_by_market,
     E_orig_flex_by_market, E_new_flex_by_market,
     E_orig_expflex_down_by_market, E_new_expflex_down_by_market,
     E_orig_expflex_up_by_market, E_new_expflex_up_by_market)

  return(list(Main_df            = Main_df,
              market_commitments = market_commitments,
              economic_analysis  = economic_analysis))
}
