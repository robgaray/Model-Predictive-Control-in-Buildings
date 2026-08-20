# -------------------------------------------------------------
# Function: accumulate_market_operation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Adds one energy market operation - the move a single market made on
# a single target slot, already resolved into its four elementary
# components by split_market_operation() - to the two economic_analysis
# tables.
# It is the single place where a market flow becomes a reported
# number, so that economic_analysis$market and economic_analysis$slot cannot drift apart
# from each other or from the commitment matrices.
# The same operation is reported twice, from two different angles:
#   - on one row of economic_analysis$market: the market that owns this slot,
#     which accumulates the operation's quantities and its cash flow.
#   - on one row of economic_analysis$slot: the slot itself, which accumulates
#     the operation's costs, revenues and the working quantities that
#     economic_analysis_finalize.R later turns into fractions.
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
# imported), which is what
# 00_Agent_Input/20260820_Correcciones.md asks to correct.
# A consequence of this is that Cost_energy_bought and
# Revenue_energy_sold are no longer non-negative magnitudes: a slot
# whose position was mostly unwound reports a negative cost (net
# avoided cost) or a negative revenue (net avoided revenue).
# -------------------------------------------------------------
# Inputs
# economic_analysis : Named list. The accumulators, as built by
#                 economic_analysis_setup.R.
# operation     : Named list. One split_market_operation() result, with
#                 scalar components (one target slot at a time).
# dest_row      : Integer. Row of economic_analysis$market that reports this
#                 slot, already resolved by the attribution rule in
#                 integrate_market_process.R.
# dest_slot     : Integer. Row of economic_analysis$slot for this slot.
# is_scheduling : Logical. TRUE when the decision producing this
#                 operation is a Scheduling market. Only used to feed
#                 the "committed in Scheduling" working quantity of
#                 economic_analysis$slot; it is independent of dest_row, because
#                 a Piloting decision can be reported on a Scheduling
#                 row when that market owns the slot.
# -------------------------------------------------------------
# Outputs
# Named list. The updated economic_analysis accumulators.
# -------------------------------------------------------------
# Code outline
# 1. Aggregate the four elementary components into cost, revenue and
#    their unwinding-only counterparts
# 2. Accumulate on the owning economic_analysis$market row
# 3. Accumulate on the economic_analysis$slot row
# -------------------------------------------------------------
# Usage instructions
# economic_analysis <- accumulate_market_operation(economic_analysis, operation, dest_row, dest_slot, is_scheduling)
# -------------------------------------------------------------
# Where this function/script is used
# Called by integrate_market_process.R, once per target interval of
# every Scheduling and Piloting market execution.
# -------------------------------------------------------------
# functions/scripts called
# None.
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

  # 2. Accumulate on the owning economic_analysis$market row
  {
    economic_analysis$market$Energy_bought[dest_row]   <- economic_analysis$market$Energy_bought[dest_row]   + operation$qty_buy_new
    economic_analysis$market$Energy_rebought[dest_row] <- economic_analysis$market$Energy_rebought[dest_row] + operation$qty_buy_back
    economic_analysis$market$Energy_sold[dest_row]     <- economic_analysis$market$Energy_sold[dest_row]     + operation$qty_sell_new
    economic_analysis$market$Energy_resold[dest_row]   <- economic_analysis$market$Energy_resold[dest_row]   + operation$qty_sell_back

    economic_analysis$market$Cash_flow[dest_row]       <- economic_analysis$market$Cash_flow[dest_row]       + cash_flow
    economic_analysis$market$PL_rebuy_resale[dest_row] <- economic_analysis$market$PL_rebuy_resale[dest_row] + unwind_pl
  }

  # 3. Accumulate on the economic_analysis$slot row
  {
    economic_analysis$slot$Cost_energy_bought[dest_slot]  <- economic_analysis$slot$Cost_energy_bought[dest_slot]  + cost_total
    economic_analysis$slot$Revenue_energy_sold[dest_slot] <- economic_analysis$slot$Revenue_energy_sold[dest_slot] + revenue_total
    economic_analysis$slot$Cash_flow[dest_slot]           <- economic_analysis$slot$Cash_flow[dest_slot]           + cash_flow

    economic_analysis$slot$Qty_rebuy_resale[dest_slot] <- economic_analysis$slot$Qty_rebuy_resale[dest_slot] + unwind_qty
    economic_analysis$slot$Val_rebuy_resale[dest_slot] <- economic_analysis$slot$Val_rebuy_resale[dest_slot] + unwind_val

    if (is_scheduling) {
      economic_analysis$slot$Qty_scheduling[dest_slot] <- economic_analysis$slot$Qty_scheduling[dest_slot] +
        operation$qty_buy_new + operation$qty_sell_new
    }
  }

  rm(cost_total, revenue_total, cash_flow, unwind_qty, unwind_val, unwind_pl)

  return(economic_analysis)
}
