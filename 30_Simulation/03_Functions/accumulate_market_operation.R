# -------------------------------------------------------------
# Function: accumulate_market_operation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Adds the energy market operations of one market - the move it made
# on each of its target slots, already resolved into its four
# elementary components by split_market_operation() - to the two
# economic_analysis tables, slot by slot, in the order of the slots.
# It is the single place where a market flow becomes a reported
# number, so that economic_analysis$market and economic_analysis$slot cannot
# drift apart from each other or from the commitment matrices.
# The same operation is reported twice, from two different angles:
#   - on one row of economic_analysis$market: the market that owns this slot,
#     which accumulates the operation's quantities and its cash flow.
#   - on one row of economic_analysis$slot: the slot itself, which accumulates
#     the operation's costs, revenues and the working quantities that
#     finalize() later turns into fractions.
# -------------------------------------------------------------
# Sign convention
# Cash_flow is signed as an inflow: selling energy (either a new sale
# or reselling something bought in an earlier market) brings money in
# and adds to it; buying energy (either a new purchase or buying back
# something sold in an earlier market) takes money out and subtracts
# from it. PL_rebuy_resale applies the same convention to the
# unwinding operations alone, so it is the net cash flow produced by
# undoing earlier positions, valued at the prices of the market that
# undid them.
# -------------------------------------------------------------
# Where an unwinding operation is reported
# The four elementary operations are not two costs and two revenues.
# Only a new purchase is a cost and only a new sale is a revenue; the
# other two undo an earlier position and are reported as a reduction
# of the flow they cancel, not as a flow of the opposite kind:
#   - a resale (selling back something bought earlier) is an avoided
#     cost, so it reduces Cost_energy_bought;
#   - a rebuy (buying back something sold earlier) is an avoided
#     revenue, so it reduces Revenue_energy_sold.
# Reporting them the other way round would create revenue in a slot
# where no energy was ever exported (and cost where none was
# imported).
# A consequence of this is that Cost_energy_bought and
# Revenue_energy_sold are not always non-negative magnitudes: a slot
# whose position was mostly unwound reports a negative cost (net
# avoided cost) or a negative revenue (net avoided revenue).
# -------------------------------------------------------------
# Inputs
# economic_analysis : Named list. The accumulators, as built by
#                 prepare_economic_analysis().
# operation     : Named list. One split_market_operation() result,
#                 with one element per target slot.
# dest_row      : Integer vector, one element per target slot. Row of
#                 economic_analysis$market that reports each slot,
#                 already resolved by the attribution rule in
#                 settle_market.R. Several slots can share a row.
# dest_slot     : Integer vector, one element per target slot. Row of
#                 economic_analysis$slot for each slot; no two slots
#                 share a row.
# is_scheduling : Logical. TRUE when the decision producing this
#                 operation is a Scheduling market. Only used to feed
#                 the "committed in Scheduling" working quantity of
#                 economic_analysis$slot; it is independent of dest_row, because
#                 a Piloting decision can be reported on a Scheduling
#                 row when that market owns the slot.
# -------------------------------------------------------------
# Outputs
# Named list. The updated economic_analysis accumulators. Its tables
# are changed in place (add_to_table_cells()), so the tables of the
# economic_analysis passed in hold the same values.
# -------------------------------------------------------------
# Code outline
# 1. Aggregate the four elementary components into cost, revenue and
#    their unwinding-only counterparts
# 2. Accumulate on the owning economic_analysis$market row, in place
# 3. Accumulate on the economic_analysis$slot row, in place
# -------------------------------------------------------------
# Usage instructions
# economic_analysis <- accumulate_market_operation(economic_analysis, operation,
# dest_row, dest_slot, is_scheduling)
# -------------------------------------------------------------

accumulate_market_operation <- function(economic_analysis,
                                        operation,
                                        dest_row,
                                        dest_slot,
                                        is_scheduling) {

  # 1. Aggregate the four elementary components
  # -------------------------------------------------------------
  # An unwinding operation is not a flow of its own kind: it is the
  # cancellation of the opposite flow, and is reported against that
  # flow rather than alongside it (see the Sign convention block in
  # this file's header).
  #   - a resale (val_sell_back) undoes an earlier purchase, so it is
  #     an avoided cost and is subtracted from the cost, never added
  #     to the revenue;
  #   - a rebuy (val_buy_back) undoes an earlier sale, so it is an
  #     avoided revenue and is subtracted from the revenue, never
  #     added to the cost.
  # cash_flow is unaffected by this: it is the same number either way,
  # because the four components only move between the two aggregates.
  # -------------------------------------------------------------
  {
    cost_total    <- operation$val_buy_new  - operation$val_sell_back
    revenue_total <- operation$val_sell_new - operation$val_buy_back
    cash_flow     <- revenue_total - cost_total

    unwind_qty <- operation$qty_buy_back + operation$qty_sell_back
    unwind_val <- operation$val_buy_back + operation$val_sell_back
    unwind_pl  <- operation$val_sell_back - operation$val_buy_back
  }

  # -------------------------------------------------------------
  # 2. Accumulate on the owning economic_analysis$market row
  # Each value is added in place by add_to_table_cells(), so the
  # column of the table is not copied. Several target slots can share
  # a market row: their values are added in the order of the slots.
  # -------------------------------------------------------------
  {
    market_additions <- list(
      Energy_bought   = operation$qty_buy_new,
      Energy_rebought = operation$qty_buy_back,
      Energy_sold     = operation$qty_sell_new,
      Energy_resold   = operation$qty_sell_back,
      Cash_flow       = cash_flow,
      PL_rebuy_resale = unwind_pl
    )

    for (CONT_001 in names(market_additions)) {
      # add_to_table_cells is called to add the values to the market
      # row that owns each slot.
      add_to_table_cells(
        table   = economic_analysis$market,
        rows    = dest_row,
        columns = CONT_001,
        values  = market_additions[[CONT_001]]
      )
    }

    rm(list = c("market_additions", "CONT_001"))
  }

  # -------------------------------------------------------------
  # 3. Accumulate on the economic_analysis$slot row
  # The quantity committed in Scheduling adds the new purchase and
  # then the new sale, one after the other, in that order.
  # -------------------------------------------------------------
  {
    slot_additions <- list(
      Cost_energy_bought  = cost_total,
      Revenue_energy_sold = revenue_total,
      Cash_flow           = cash_flow,
      Qty_rebuy_resale    = unwind_qty,
      Val_rebuy_resale    = unwind_val
    )
    if (is_scheduling) {
      slot_additions <- c(
        slot_additions,
        list(Qty_scheduling = operation$qty_buy_new,
             Qty_scheduling = operation$qty_sell_new)
      )
    }

    for (CONT_002 in seq_along(slot_additions)) {
      # add_to_table_cells is called to add the values to the row of
      # each slot.
      add_to_table_cells(
        table   = economic_analysis$slot,
        rows    = dest_slot,
        columns = names(slot_additions)[CONT_002],
        values  = slot_additions[[CONT_002]]
      )
    }

    rm(list = c("slot_additions", "CONT_002"))
  }

  rm(list = c("cost_total", "revenue_total", "cash_flow", "unwind_qty",
              "unwind_val", "unwind_pl"))

  return(economic_analysis)
}
