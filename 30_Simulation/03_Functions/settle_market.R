# -------------------------------------------------------------
# Function: settle_market.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Settles the decision of a single Scheduling or Piloting market, for
# the current simulation step. It is the system side of the market
# process: it works only with energy per market interval, commitments,
# prices and amounts, and it knows nothing of the building's
# temperatures, modes or setpoints. The itineraries of the building
# are written by write_itineraries() before the settlement runs.
# The function never writes into Main_df: it returns the writes, and
# the simulation loop (run_market_role()) applies them. It:
#   - locates the market row of the current step and the target
#     market intervals covered by this market's control horizon
#   - attributes each target interval to the economic_analysis$market
#     row that reports it
#   - aggregates (SUM) the energy before and after the decision per
#     target interval, for:
#       - the base energy (the net electricity of the system in the
#         plan)
#       - the energy with flexibility (the net electricity of the
#         system in the downward itinerary)
#       - the explicit flexibility of each leg
#   - accumulates the differential energy commitments into these
#     market_commitments matrices:
#       - net/buy/sell
#       - their _flex counterparts
#       - the explicit flexibility buy/sell matrices
#   - accumulates the net cash flow of the explicit-flexibility service
#     (both down and up legs, for both Scheduling and Piloting) into
#     market_commitments$Elec_flex_Cost_plan_df and returns its spread
#     over Main_df$Elec_flex_commitment_revenue_h as an addition; it
#     also adds the sold/bought-back totals to this decision's row of
#     economic_analysis$decision, as Flex_sell_revenue (income, +=) and
#     Flex_purchase_cost (expense, -=)
#   - accumulates the net cash flow of the energy commitment (the base
#     energy track, for both market families) into
#     market_commitments$Elec_Cost_plan_df and returns its spread over
#     Main_df$Elec_market_net_cost_h as an addition; it also splits the
#     same differential into its elementary buy/rebuy/sell/resell
#     operations (split_market_operation()) and adds their totals to
#     this decision's row of economic_analysis$decision, as
#     Energy_sell_revenue (income, +=) and Energy_purchase_cost
#     (expense, -=)
#   - books the total reward of this decision on its row of
#     economic_analysis$decision: the sum of the per-timestep rewards
#     over the optimization horizon, which is the total the optimizer
#     maximised.
# Only two things are committed: the energy of the _plan itinerary and
# the phase-1 flexibility. The energy of the Recovery Phase is
# contingent on the service being called, so it is valued by
# reward_function() to steer the decision but never settled here.
# Every money signal follows the same sign convention: income
# positive, expense negative.
# full_market_information and market_commitments have one row per
# market event (not one row per market-resolution interval), while
# their future-step columns still refer to market-resolution-grid
# offsets. Column offsets (col_j) are therefore computed against
# market_time (the full market-resolution grid, used only for this
# arithmetic), while actual matrix reads/writes are indexed by
# row_m, the row of the current event within full_market_information/
# market_commitments' own (sparse) row set. The event is keyed by the
# market interval its clearing instant falls in (instant_market_slot()),
# the same key those matrices and economic_analysis were built with,
# while every target slot is a MarketUTC interval: the interval of the
# time steps the market controls.
# -------------------------------------------------------------
# Inputs
# prefix              : Character. "Sched" or "Pilot". Says whether the
#                        target slots count towards
#                        economic_analysis$slot's "committed in
#                        Scheduling" fraction. It does not select an
#                        energy track: both families settle the base
#                        energy of the _plan itinerary.
# row_index           : Integer. Current simulation row index
#                        (CONT_003).
# clearing_time       : POSIXct scalar. Clearing instant of the market
#                        (the time of row row_index).
# control_rows        : Integer vector. Rows of Main_df that the market
#                        controls (its control horizon).
# energy_before       : Data frame, one row per row of Main_df, with the
#                        energy before the decision:
#                          - MarketUTC: market interval of the row
#                          - the net electricity of the system in the
#                            plan and in the downward itinerary (kWh,
#                            columns named by system_net_energy_column())
#                          - Elec_flex_down_plan and Elec_flex_up_plan:
#                            the flexibility committed on each leg (kWh)
# energy_after        : Data frame. The same columns, after the
#                        decision: the itineraries as write_itineraries()
#                        writes them. They are also the weights used to
#                        spread the cash flow of an interval over its
#                        rows.
# reward_by_step      : Numeric vector. Per-timestep Reward of the
#                        decision over its optimization horizon.
# market_time         : POSIXct vector. Sorted unique MarketUTC
#                        intervals on the full market-resolution grid;
#                        used only to compute future-step column
#                        offsets (col_j), not as the matrices' row set.
# full_market_information : Named list of 13 market-event price data
#                        frames (read-only), as built by
#                        prepare_market_information().
# market_commitments  : Named list of 12 market-event output data
#                        frames, as built by prepare_commitments().
# economic_analysis   : Named list of economic-analysis accumulators
#                        (market, slot, decision and the index
#                        sub-list), as built by
#                        prepare_economic_analysis().
# parameters          : Named list. Model parameters; reads
#                        parameters$market$market_resolution to key the
#                        event.
# -------------------------------------------------------------
# Outputs
# Named list with:
#   main_df_writes     : List of writes for Main_df, in the order in
#                        which they have to be applied. Each element is
#                        a list with:
#                          - column : Character. Column of Main_df.
#                          - rows   : Integer vector. Rows of Main_df.
#                          - value  : Numeric vector, as long as rows.
#                          - mode   : Character. "add": the values are
#                            added to the current ones.
#                        The writes are the Elec_flex_commitment_revenue_h
#                        and Elec_market_net_cost_h spreads over the rows
#                        of each target interval.
#   market_commitments : Named list. Updated with the
#                        differential energy and cost commitments of
#                        this market execution. Its tables are changed
#                        in place (add_to_table_cells()), so the
#                        market_commitments passed in holds them too.
#   economic_analysis  : Named list. Updated, in place like
#                        market_commitments, with this market
#                        execution's elementary operations, on the
#                        economic_analysis$market row that owns each
#                        target slot and on the economic_analysis$slot
#                        row of that slot, and with the totals of this
#                        decision on its row of economic_analysis$decision:
#                          - the cost of the energy bought
#                          - the revenue of the energy sold
#                          - the revenue of the flexibility sold
#                          - the cost of the flexibility bought back
#                          - the Reward
#                        Income is positive and expense negative.
# -------------------------------------------------------------
# Code outline
# 1. Market row and target market intervals
# 2. Attribution of each target slot to an economic_analysis$market row
# 3. Per-interval energy before/after the market (SUM aggregation)
# 4. Accumulate the differential commitments in the output matrices
#    (also resolves the explicit-flexibility net cash flow per interval)
# 5. Explicit flexibility cost/revenue (Scheduling and Piloting alike)
# 6. Differential cost of the energy commitment (base energy track, for
#    both market families)
# 7. Reward of this decision, totalled on its row of
#    economic_analysis$decision
# -------------------------------------------------------------
# Usage instructions
# settlement <- settle_market(
#   prefix                  = "Sched",
#   row_index               = CONT_003,
#   clearing_time           = Main_df$time[CONT_003],
#   control_rows            = simulation_control$indexes_global$idx_ctrl,
#   energy_before           = energy_before,
#   energy_after            = energy_after,
#   reward_by_step          = reward_by_step,
#   market_time             = market_time,
#   full_market_information = full_market_information,
#   market_commitments      = market_commitments,
#   economic_analysis       = economic_analysis,
#   parameters              = parameters
# )
# main_df_writes     <- settlement$main_df_writes
# market_commitments <- settlement$market_commitments
# economic_analysis  <- settlement$economic_analysis
# -------------------------------------------------------------

settle_market <- function(prefix,
                          row_index,
                          clearing_time,
                          control_rows,
                          energy_before,
                          energy_after,
                          reward_by_step,
                          market_time,
                          full_market_information,
                          market_commitments,
                          economic_analysis,
                          parameters) {

  if (!prefix %in% c("Sched", "Pilot")) {
    stop("settle_market: prefix must be 'Sched' or 'Pilot'")
  }

  # -------------------------------------------------------------
  # 1. Market row of the current step and target market intervals
  # row_m_full is the position of the current event on the full
  # market-resolution grid (market_time); it is only used to compute
  # col_j offsets, which stay valid market-resolution-step counts
  # regardless of how sparse the matrices' own row set is. row_m is
  # the position of the current event within full_market_information/
  # market_commitments' own (sparse, market-event) row set, and is
  # what actually indexes into those matrices.
  # -------------------------------------------------------------
  {
    # instant_market_slot is called to key the current event by the
    # market interval its clearing instant falls in.
    event_slot <- instant_market_slot(
      time              = clearing_time,
      market_resolution = parameters$market$market_resolution
    )
    row_m_full <- match(event_slot, market_time)
    market_rows <- full_market_information$Elec_unit_cost_import_buy_df$time
    row_m <- match(event_slot, market_rows)

    idx_target_market <- match(
      sort(unique(energy_before$MarketUTC[control_rows])),
      market_time
    )

    rm(list = "market_rows")
  }

  # -------------------------------------------------------------
  # 2. Attribution of each target slot to an economic_analysis$market
  #    row
  # Every economic flow this market produces on a target slot has to
  # be reported on exactly one row of economic_analysis$market. When a
  # Scheduling and a Piloting market clear at the same timestamp, the
  # slots the Scheduling market covers are reported on the Scheduling
  # row - no matter which of the two decisions actually produced the
  # flow - and the remaining slots on the Piloting row (see
  # prepare_economic_analysis()). A Scheduling market therefore always
  # reports its own slots, and it records them in
  # economic_analysis$index$sched_claim so that the Piloting market
  # clearing at the same row_index (simulate() always runs the
  # Scheduling market first) can hand those same slots over to it. The
  # claim carries its row_index so that a stale claim from an earlier
  # simulation step is never reused.
  # -------------------------------------------------------------
  {
    slot_pos <- match(as.numeric(market_time[idx_target_market]),
                      economic_analysis$index$slot_key)

    # The reporting row belongs to the market that took the decision,
    # so it is looked up at the decision's own timestamp, not at the
    # target slot's timestamp.
    decision_pos   <- match(as.numeric(event_slot),
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

      rm(list = "claimed_slot_pos")
    }

    # The totals of the decision go to its own row of
    # economic_analysis$decision, found by its family and its interval.
    decision_family <- if (prefix == "Sched") "Scheduling" else "Piloting"
    decision_row    <- which(
      economic_analysis$decision$market_type == decision_family &
        as.numeric(economic_analysis$decision$time) == as.numeric(event_slot)
    )
    if (length(decision_row) != 1) {
      stop("settle_market: the ", decision_family,
           " decision at row ", row_index,
           " has no row of its own in economic_analysis$decision")
    }

    rm(list = c("decision_pos", "row_sched_here", "row_pilot_here",
                "event_slot", "decision_family"))
  }

  # -------------------------------------------------------------
  # 3. Per-interval energy before/after the market (SUM aggregation)
  # One aggregate per signal and per leg, before (energy_before) and
  # after (energy_after) this market's decision, over the control
  # rows. The two flexibility signals are non-negative by
  # construction, so a single aggregate would net a downward
  # commitment against an upward one and value the difference as if
  # it were one service.
  # The energy of the Recovery Phase is deliberately NOT aggregated
  # here. A market commits two things and only two: the energy bought
  # and sold on the _plan itinerary, and the flexibility of the
  # Commitment Phase, the phase-1 differential between _plan and each
  # flexibility itinerary. The rebuy the building would make while
  # recovering is contingent on the operator calling the service, so
  # committing it would book an operation that may never happen.
  # Its future price does have to weigh on the decision, and it does:
  # reward_function() values it through compute_recovery_energy_cost(),
  # as the change against the itineraries already committed, which is
  # where a contingent cost belongs. Valuing it to choose and
  # committing it to settle are different things, and this function
  # only settles.
  # -------------------------------------------------------------
  {
    energy_tables <- list(orig = energy_before, new = energy_after)
    E_by_market   <- list(orig = list(), new = list())

    for (CONT_008 in names(energy_tables)) {
      one_table <- energy_tables[[CONT_008]]

      # Each signal of the list below is summed over the market
      # interval each row belongs to:
      #   - base         : net electricity of the system in the plan
      #   - flex         : net electricity of the system in the
      #                    downward itinerary
      #   - expflex_down : flexibility committed on the down leg
      #   - expflex_up   : flexibility committed on the up leg
      # system_net_energy is called to read the net electricity of the
      # system in the plan and in the downward itinerary.
      per_row_signals <- list(
        base         = system_net_energy(
          itinerary_table = one_table,
          itinerary       = "plan"
        ),
        flex         = system_net_energy(
          itinerary_table = one_table,
          itinerary       = "plan_flex_down"
        ),
        expflex_down = one_table[["Elec_flex_down_plan"]],
        expflex_up   = one_table[["Elec_flex_up_plan"]]
      )

      for (CONT_011 in names(per_row_signals)) {
        E_by_market[[CONT_008]][[CONT_011]] <- as.numeric(tapply(
          per_row_signals[[CONT_011]][control_rows],
          one_table$MarketUTC[control_rows], sum
        ))
      }

      rm(list = c("one_table", "per_row_signals", "CONT_011"))
    }
    rm(list = c("CONT_008", "energy_tables"))
  }

  # -------------------------------------------------------------
  # 4. Accumulate the differential commitments in the output matrices
  # Also resolves, per target interval and per leg, the
  # explicit-flexibility net cash flow (flex_revenue_down_by_market/
  # flex_buyback_down_by_market and their up-leg counterparts) that
  # block 5 propagates into the writes of Main_df and into
  # market_commitments, weighted by the post-decision value of each
  # leg's own signal (Elec_flex_down_plan and Elec_flex_up_plan). The
  # cash flow is kept split by leg because each leg is spread over
  # Main_df with its own weight column.
  # Every interval is valued at once, element by element, and every
  # addition to a table is made in place by add_to_table_cells(): when
  # a cell receives the values of several intervals, they are added
  # in the order of the intervals.
  # -------------------------------------------------------------
  {
    # The column of each target interval, as an offset of steps from
    # the market event.
    col_names <- as.character(idx_target_market - row_m_full)

    # The price of every target interval is read from the row of the
    # market event. .subset2() reads a column without the method of
    # data frames.
    price_at_row <- function(signal_df) {
      vapply(col_names, function(CONT_012) {
        .subset2(signal_df, CONT_012)[row_m]
      }, numeric(1), USE.NAMES = FALSE)
    }

    # Explicit flexibility, one leg at a time.
    # Elec_flex_down_plan and Elec_flex_up_plan are two independent
    # signals, each of them a volume >= 0: the first is the load the
    # building commits to shed during its Commitment Phase, the second
    # the load it commits to add. The move from the previous to the
    # new volume is either a sale (the leg grows: more service
    # committed to the grid, income) or a buy back (the leg shrinks:
    # part of a commitment sold in an earlier market is unwound,
    # expense).
    # value_flex_operation() tells the two legs apart by the sign of
    # the series it is given, so the up leg is passed negated; both
    # series being non-negative, each call activates only its own leg
    # and the other one comes back at zero. Netting them into a single
    # signed series instead would silently cancel a downward
    # commitment against an upward one in the same interval.
    # See value_flex_operation()'s header for why this cannot be
    # valued via calc_differential_cost()/split_market_operation()
    # the way energy is.
    # The market settles the commitment only, at the commitment
    # price of each leg: it is what the service is paid for,
    # whether or not the operator ever calls it. The execution
    # price is paid for an activation, so it belongs to the
    # execution phase, when the activation is delivered. The
    # optimizer still weighs the expected execution revenue,
    # the execution price times the activation probability, in
    # its reward (see reward_function()): it is what makes a
    # commitment worth selling, but it is not money the market
    # pays.
    price_down_sell <- price_at_row(full_market_information$Flex_unit_cost_down_com_sell_df)
    price_down_buy  <- price_at_row(full_market_information$Flex_unit_cost_down_com_buy_df)
    price_up_sell   <- price_at_row(full_market_information$Flex_unit_cost_up_com_sell_df)
    price_up_buy    <- price_at_row(full_market_information$Flex_unit_cost_up_com_buy_df)

    # value_flex_operation is called once per leg, for every target
    # interval at once, to resolve each interval's move from
    # E_orig_expflex to E_new_expflex into its sold and bought-back
    # volumes and their net cash flow. It works element by element, so
    # each interval is valued as on its own.
    flex_op_down <- value_flex_operation(
      E_orig          = E_by_market$orig$expflex_down,
      E_new           = E_by_market$new$expflex_down,
      price_down_sell = price_down_sell,
      price_down_buy  = price_down_buy,
      price_up_sell   = price_up_sell,
      price_up_buy    = price_up_buy
    )
    flex_op_up <- value_flex_operation(
      E_orig          = -E_by_market$orig$expflex_up,
      E_new           = -E_by_market$new$expflex_up,
      price_down_sell = price_down_sell,
      price_down_buy  = price_down_buy,
      price_up_sell   = price_up_sell,
      price_up_buy    = price_up_buy
    )

    flex_revenue_down_by_market <- flex_op_down$down_sold   * price_down_sell
    flex_buyback_down_by_market <- flex_op_down$down_bought * price_down_buy
    flex_revenue_up_by_market   <- flex_op_up$up_sold       * price_up_sell
    flex_buyback_up_by_market   <- flex_op_up$up_bought     * price_up_buy

    # The energy of every target interval, before and after the
    # decision: the net electricity of the plan and of the downward
    # itinerary, and the part of each that is bought (positive) and
    # sold (negative).
    E_orig      <- E_by_market$orig$base
    E_new       <- E_by_market$new$base
    E_orig_flex <- E_by_market$orig$flex
    E_new_flex  <- E_by_market$new$flex

    # The differential commitments of every target interval, one per
    # table of market_commitments.
    commitment_additions <- list(
      Elec_net_plan_df            = E_new - E_orig,
      Elec_buy_plan_df            = pmax(E_new, 0) - pmax(E_orig, 0),
      Elec_sell_plan_df           = pmin(E_new, 0) - pmin(E_orig, 0),
      Elec_net_plan_flex_down_df  = E_new_flex - E_orig_flex,
      Elec_buy_plan_flex_down_df  = pmax(E_new_flex, 0) - pmax(E_orig_flex, 0),
      Elec_sell_plan_flex_down_df = pmin(E_new_flex, 0) - pmin(E_orig_flex, 0),
      Elec_flex_down_sell_plan_df = flex_op_down$down_sold,
      Elec_flex_down_buy_plan_df  = flex_op_down$down_bought,
      Elec_flex_up_sell_plan_df   = flex_op_up$up_sold,
      Elec_flex_up_buy_plan_df    = flex_op_up$up_bought
    )

    for (CONT_013 in names(commitment_additions)) {
      # add_to_table_cells is called to add the commitments to the
      # row of the market event, one cell per target interval, in
      # place.
      add_to_table_cells(
        table   = market_commitments[[CONT_013]],
        rows    = row_m,
        columns = col_names,
        values  = commitment_additions[[CONT_013]]
      )
    }

    # The two legs are booked together here: the accounting tables
    # record the market's whole flexibility position, and each of
    # them already has its own down and up columns.
    flex_cash_flow  <- flex_op_down$revenue + flex_op_up$revenue
    flex_buyback_ti <- flex_buyback_down_by_market +
                       flex_buyback_up_by_market

    # The flexibility of each interval on the market row that owns
    # it. A buy back reduces PL_rebuy_resale.
    market_additions <- list(
      Flex_down_sold     = flex_op_down$down_sold,
      Flex_down_rebought = flex_op_down$down_bought,
      Flex_up_sold       = flex_op_up$up_sold,
      Flex_up_rebought   = flex_op_up$up_bought,
      Cash_flow          = flex_cash_flow,
      PL_rebuy_resale    = -flex_buyback_ti
    )

    # The flexibility of each interval on the row of its slot.
    # Flex_committed adds the down leg and then the up leg, and
    # Qty_flex_rebought the same, one after the other.
    slot_additions <- list(
      Flex_down_committed      = flex_op_down$down_sold,
      Flex_up_committed        = flex_op_up$up_sold,
      Flex_committed           = flex_op_down$down_sold,
      Flex_committed           = flex_op_up$up_sold,
      Qty_flex_rebought        = flex_op_down$down_bought,
      Qty_flex_rebought        = flex_op_up$up_bought,
      Revenue_flex_commitments = flex_cash_flow,
      Cash_flow                = flex_cash_flow,
      Val_rebuy_resale         = flex_buyback_ti
    )

    for (CONT_014 in names(market_additions)) {
      # add_to_table_cells is called to add the flexibility of every
      # interval to the market row that owns it, in place. Several
      # intervals can share a row: their values are added in the
      # order of the intervals.
      add_to_table_cells(
        table   = economic_analysis$market,
        rows    = analysis_dest_row,
        columns = CONT_014,
        values  = market_additions[[CONT_014]]
      )
    }

    for (CONT_015 in seq_along(slot_additions)) {
      # add_to_table_cells is called to add the flexibility of every
      # interval to the row of its slot, in place.
      add_to_table_cells(
        table   = economic_analysis$slot,
        rows    = slot_pos,
        columns = names(slot_additions)[CONT_015],
        values  = slot_additions[[CONT_015]]
      )
    }

    rm(list = intersect(
      c("CONT_013", "CONT_014", "CONT_015", "E_orig", "E_new",
        "E_orig_flex", "E_new_flex", "commitment_additions",
        "market_additions", "slot_additions", "flex_cash_flow",
        "flex_buyback_ti"),
      ls()
    ))
    rm(list = c("price_down_sell", "price_down_buy", "price_up_sell",
                "price_up_buy", "flex_op_down", "flex_op_up"))
  }

  # -------------------------------------------------------------
  # 5. Explicit flexibility cost/revenue (both Scheduling and Piloting)
  # Registered for every market that can commit flexibility, not just
  # Piloting: a Scheduling market with a flexibility-inclusive aim
  # takes this same economic decision (resolve_marginal_context() and
  # reward_function() already value it regardless of prefix) and it
  # must leave the same kind of entry.
  # It runs after block 4, where the per-interval net cash flow was
  # resolved, as a loop of its own: propagate_unit_value() spreads
  # that cash flow across the rows of Main_df weighted by the leg's
  # own signal, Elec_flex_down_plan or Elec_flex_up_plan, read from
  # energy_after, which holds this decision's own (post-update) value.
  # One propagation per leg, because the two have different weights:
  # the rows where the building committed to shed load are not the
  # rows where it committed to add it, and a single propagation would
  # spread each leg's cash flow over the other leg's rows.
  # main_df_writes collects every write of Main_df, in the order in
  # which it has to be applied.
  # -------------------------------------------------------------
  {
    main_df_writes <- list()

    flex_sell_revenue_total  <- 0
    flex_purchase_cost_total <- 0

    # The target interval of each row of energy_after, as its position
    # in idx_target_market (NA for a row of no target interval), so
    # that the rows of each interval are found without comparing
    # times again for every interval.
    row_target <- match(as.numeric(energy_after$MarketUTC),
                        as.numeric(market_time[idx_target_market]))

    for (CONT_004 in seq_along(idx_target_market)) {
      col_j   <- col_names[CONT_004]
      rows_ts <- which(row_target == CONT_004)

      # propagate_unit_value is called once per leg, to accumulate this
      # target interval's already-resolved explicit-flexibility net cash
      # flow into market_commitments$Elec_flex_Cost_plan_df and to spread
      # its unit value over the rows of this target interval, to be
      # added to Main_df$Elec_flex_commitment_revenue_h, weighted by
      # that leg's own signal. Both legs accumulate into the
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
          delta_C    = delta_C_leg,
          cost_df    = market_commitments$Elec_flex_Cost_plan_df,
          rows_ts    = rows_ts,
          weight_ts  = energy_after[[weight_col_leg]][rows_ts]
        )
        main_df_writes[[length(main_df_writes) + 1L]] <- list(
          column = "Elec_flex_commitment_revenue_h",
          rows   = prop_result$rows,
          value  = prop_result$delta,
          mode   = "add"
        )

        rm(list = c("delta_C_leg", "weight_col_leg", "prop_result"))
      }
      rm(list = intersect("CONT_006", ls()))

      flex_sell_revenue_total  <- flex_sell_revenue_total  +
        flex_revenue_down_by_market[CONT_004] + flex_revenue_up_by_market[CONT_004]
      flex_purchase_cost_total <- flex_purchase_cost_total +
        flex_buyback_down_by_market[CONT_004] + flex_buyback_up_by_market[CONT_004]

      rm(list = c("col_j", "rows_ts"))
    }
    rm(list = intersect("CONT_004", ls()))

    # add_to_table_cells is called to add the flexibility totals of the
    # decision to its row of economic_analysis$decision: the revenue
    # as income, the cost of the buy back as expense.
    add_to_table_cells(
      table   = economic_analysis$decision,
      rows    = decision_row,
      columns = "Flex_sell_revenue",
      values  = flex_sell_revenue_total
    )
    add_to_table_cells(
      table   = economic_analysis$decision,
      rows    = decision_row,
      columns = "Flex_purchase_cost",
      values  = -flex_purchase_cost_total
    )
    rm(list = c("flex_sell_revenue_total", "flex_purchase_cost_total",
                "flex_revenue_down_by_market", "flex_buyback_down_by_market",
                "flex_revenue_up_by_market", "flex_buyback_up_by_market"))
  }

  # -------------------------------------------------------------
  # 6. Differential cost of the energy commitment
  # Always on the base energy track. For every target interval, the
  # differential is propagated into Main_df$Elec_market_net_cost_h (an
  # energy-weighted accumulation, weighted by the net electricity of
  # the system in the plan after the decision), and the elementary
  # buy/rebuy/sell/resell operations of the very same differential
  # (split_market_operation()) are summed across this decision's whole
  # (implementation-horizon) target-interval set and added, with
  # `+=`/`-=`, to the totals of this decision on its row of
  # economic_analysis$decision - Energy_sell_revenue (income,
  # positive) and Energy_purchase_cost (expense, negative).
  # The energy bought and sold is the one of the _plan itinerary, for
  # both market families alike. The flexibility itineraries are not
  # settled here: what they move is sold as the flexibility service,
  # in block 5, valued on Elec_flex_down_plan/Elec_flex_up_plan.
  # Settling on the downward itinerary instead would book the
  # building as buying the energy of an itinerary it only flies if
  # the operator calls the service: it would disagree with what the
  # building consumes (Elec_total_exec) and with what the reward
  # values (reward_function() prices energy on the plan for every
  # aim), and it would pay the same reduction twice, once as energy
  # not bought and again as flexibility sold.
  # prefix therefore selects no energy track; it only says whether
  # the target slot counts towards economic_analysis$slot's
  # "committed in Scheduling" fraction.
  # -------------------------------------------------------------
  {
    E_orig_sel   <- E_by_market$orig$base
    E_new_sel    <- E_by_market$new$base
    is_sched_sel <- (prefix == "Sched")

    # system_net_energy is called to read the net electricity of the
    # system in the plan after the decision, the weight of the spread.
    weight_sel <- system_net_energy(
      itinerary_table = energy_after,
      itinerary       = "plan"
    )

    purchase_cost_total <- 0
    sell_revenue_total  <- 0

    # The energy prices of every target interval.
    P_import_buy_all  <- price_at_row(full_market_information$Elec_unit_cost_import_buy_df)
    P_import_sell_all <- price_at_row(full_market_information$Elec_unit_cost_import_sell_df)
    P_export_buy_all  <- price_at_row(full_market_information$Elec_unit_cost_export_buy_df)
    P_export_sell_all <- price_at_row(full_market_information$Elec_unit_cost_export_sell_df)

    # split_market_operation is called to break the energy
    # differential of every target interval into the four elementary
    # operations:
    #   - new buy
    #   - buy back
    #   - new sell
    #   - resell
    # It works element by element, so each interval is split as on its
    # own. Their values aggregate into the cost/revenue pair of the
    # totals of this decision below, and their quantities and values
    # feed the economic_analysis tables.
    # The two unwinding operations are reported against the flow they
    # cancel, not as a flow of the opposite kind: a resale is an
    # avoided cost and a rebuy an avoided revenue - the same rule
    # accumulate_market_operation() applies to the economic_analysis
    # tables, so that Main_df's "_market" columns and
    # economic_analysis$slot cannot disagree about what a cost and a
    # revenue are. See accumulate_market_operation()'s header.
    operation_all <- split_market_operation(
      E_orig_sel, E_new_sel,
      P_import_buy_all, P_import_sell_all, P_export_buy_all,
      P_export_sell_all
    )

    for (CONT_002 in seq_along(idx_target_market)) {
      col_j   <- col_names[CONT_002]
      rows_ts <- which(row_target == CONT_002)

      P_import_buy  <- P_import_buy_all[CONT_002]
      P_import_sell <- P_import_sell_all[CONT_002]
      P_export_buy  <- P_export_buy_all[CONT_002]
      P_export_sell <- P_export_sell_all[CONT_002]

      # propagate_differential_cost is called to value this decision's
      # base-energy commitment change at this target interval's prices,
      # and to spread that differential over the rows of this target
      # interval, weighted by weight_sel, to be added to
      # Main_df$Elec_market_net_cost_h.
      result <- propagate_differential_cost(
        row_m         = row_m,
        col_j         = col_j,
        E_orig        = E_orig_sel[CONT_002],
        E_new         = E_new_sel[CONT_002],
        P_import_buy  = P_import_buy,
        P_import_sell = P_import_sell,
        P_export_buy  = P_export_buy,
        P_export_sell = P_export_sell,
        cost_df       = market_commitments$Elec_Cost_plan_df,
        rows_ts       = rows_ts,
        weight_ts     = weight_sel[rows_ts]
      )
      main_df_writes[[length(main_df_writes) + 1L]] <- list(
        column = "Elec_market_net_cost_h",
        rows   = result$rows,
        value  = result$delta,
        mode   = "add"
      )

      purchase_cost_total <- purchase_cost_total +
        operation_all$val_buy_new[CONT_002] -
        operation_all$val_sell_back[CONT_002]
      sell_revenue_total  <- sell_revenue_total +
        operation_all$val_sell_new[CONT_002] -
        operation_all$val_buy_back[CONT_002]

      rm(list = c("col_j", "rows_ts", "result", "P_import_buy",
                  "P_import_sell", "P_export_buy", "P_export_sell"))
    }
    rm(list = intersect("CONT_002", ls()))

    # accumulate_market_operation is called once, for every target
    # interval, to report the same four operations on the
    # economic_analysis row and slot that own each interval, which is
    # what makes economic_analysis$market and economic_analysis$slot
    # add up to the whole simulation. The values of the intervals are
    # added in their order.
    # is_sched_sel is FALSE for Piloting: a Piloting decision never
    # counts towards the "committed in Scheduling" fraction of
    # economic_analysis$slot, even when its flows are reported on a
    # Scheduling row because that market owns the slot.
    economic_analysis <- accumulate_market_operation(
      economic_analysis = economic_analysis,
      operation         = operation_all,
      dest_row          = analysis_dest_row,
      dest_slot         = slot_pos,
      is_scheduling     = is_sched_sel
    )

    # add_to_table_cells is called to add the energy totals of the
    # decision to its row of economic_analysis$decision: the cost of
    # the energy bought as expense, the revenue of the energy sold as
    # income.
    add_to_table_cells(
      table   = economic_analysis$decision,
      rows    = decision_row,
      columns = "Energy_purchase_cost",
      values  = -purchase_cost_total
    )
    add_to_table_cells(
      table   = economic_analysis$decision,
      rows    = decision_row,
      columns = "Energy_sell_revenue",
      values  = sell_revenue_total
    )

    rm(list = c("E_orig_sel", "E_new_sel", "weight_sel", "is_sched_sel",
                "purchase_cost_total", "sell_revenue_total", "operation_all",
                "P_import_buy_all", "P_import_sell_all", "P_export_buy_all",
                "P_export_sell_all"))
  }

  # -------------------------------------------------------------
  # 7. Reward of this decision
  # reward_function() evaluates the reward per timestep, and what the
  # optimizer maximises is its total over the window it decides. That
  # total belongs to the decision, not to the hours it plans: a market
  # clearing at hour 2 for the period that runs from hour 20 to hour 25
  # books, on its row of economic_analysis$decision, the sum of the
  # rewards of rows 20 to 25. Spreading it over those rows instead
  # would suggest the reward was earned there, and adding it up across
  # markets would then count the same hours once per market that
  # planned them.
  # The window summed is the OPTIMIZATION horizon, not the market's
  # period: reward_function() evaluates the reward over that whole
  # horizon and the optimizer maximises its total, so any narrower
  # window would report a number the search never compared its
  # candidates on. It is the one quantity here that is not bounded to
  # what the market commits, because it is not a commitment: it is
  # the value of the decision.
  # Accumulated rather than assigned, like the totals above. A row
  # where both a Scheduling and a Piloting market clear gives two
  # decisions, each on its own row.
  # -------------------------------------------------------------
  {
    # add_to_table_cells is called to add the total reward of the
    # decision to its row of economic_analysis$decision.
    add_to_table_cells(
      table   = economic_analysis$decision,
      rows    = decision_row,
      columns = "Reward",
      values  = sum(
        reward_by_step,
        na.rm = TRUE
      )
    )
  }

  rm(list = c("row_m", "row_m_full", "idx_target_market", "slot_pos",
              "analysis_dest_row", "E_by_market", "decision_row",
              "col_names", "row_target", "price_at_row"))

  return(list(main_df_writes     = main_df_writes,
              market_commitments = market_commitments,
              economic_analysis  = economic_analysis))
}
