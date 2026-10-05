# -------------------------------------------------------------
# Function: compute_market_operations.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Computes the operations this market sends to the grid, per market
# interval of the control horizon (from i_begin_horizon to the last
# interval before i_end_control). Each is the move from what was
# committed before this market (the plan itinerary of the input) to
# what is committed after it (the plan itinerary of the output):
#   - Energy: the move of the net energy (Elec_total) is split by
#     split_market_operation() into new purchase, resale of an earlier
#     purchase, new sale and rebuy of an earlier sale.
#   - Flexibility: each leg (Elec_flex_down, Elec_flex_up) is split by
#     value_flex_operation() into volume sold and volume bought back.
#     The up leg is passed negated, because value_flex_operation()
#     tells the two legs apart by sign.
# Only volumes are returned: their cash flow follows from the prices,
# which the caller already has.
# -------------------------------------------------------------
# Inputs
#   checked         : Named list, as returned by validate_inputs().
#   itineraries_out : Named list, as returned by aggregate_to_slots().
# -------------------------------------------------------------
# Outputs
#   Data frame, one row per committed interval, with the columns (kWh):
#     - time
#     - Energy_bought, Energy_resold, Energy_sold, Energy_rebought
#     - Flex_down_sold, Flex_down_rebought
#     - Flex_up_sold, Flex_up_rebought
# -------------------------------------------------------------
# Code outline
# 1. Committed intervals, before and after
# 2. Energy operations
# 3. Flexibility operations
# -------------------------------------------------------------
# Usage instructions
# operations <- compute_market_operations(checked, itineraries_out)
# -------------------------------------------------------------
# Where this function/script is used
#   - optimize_market(): builds the operations of the output.
# -------------------------------------------------------------
# functions/scripts called
#   - split_market_operation(): splits the move of the net energy
#   - value_flex_operation(): splits the move of each flexibility leg
# -------------------------------------------------------------

compute_market_operations <- function(checked,
                                      itineraries_out
                                      ) {

  # -------------------------------------------------------------
  # 1. Committed intervals, before and after
  # -------------------------------------------------------------
  {
    after <- itineraries_out$plan[-nrow(itineraries_out$plan), , drop = FALSE]

    input_rows <- match(as.numeric(after$time), as.numeric(checked$slot_time))
    before     <- checked$itineraries$plan[input_rows, , drop = FALSE]
    prices     <- checked$prices[input_rows, , drop = FALSE]

    rm(input_rows)
  }

  # -------------------------------------------------------------
  # 2. Energy operations
  # -------------------------------------------------------------
  {
    # split_market_operation is called to split each interval's move
    # of net energy into its four elementary operations.
    energy <- split_market_operation(
      E_orig        = before$Elec_total,
      E_new         = after$Elec_total,
      P_import_buy  = prices$Elec_unit_cost_import_buy,
      P_import_sell = prices$Elec_unit_cost_import_sell,
      P_export_buy  = prices$Elec_unit_cost_export_buy,
      P_export_sell = prices$Elec_unit_cost_export_sell
    )
  }

  # -------------------------------------------------------------
  # 3. Flexibility operations
  # -------------------------------------------------------------
  # Prices are passed only because value_flex_operation() also returns
  # a cash flow, which is not used here.
  # -------------------------------------------------------------
  {
    # value_flex_operation is called once per leg to split its move
    # into volume sold and volume bought back.
    flex_down <- value_flex_operation(
      E_orig          = before$Elec_flex_down,
      E_new           = after$Elec_flex_down,
      price_down_sell = prices$Flex_unit_cost_down_com_sell,
      price_down_buy  = prices$Flex_unit_cost_down_com_buy,
      price_up_sell   = prices$Flex_unit_cost_up_com_sell,
      price_up_buy    = prices$Flex_unit_cost_up_com_buy
    )
    flex_up <- value_flex_operation(
      E_orig          = -before$Elec_flex_up,
      E_new           = -after$Elec_flex_up,
      price_down_sell = prices$Flex_unit_cost_down_com_sell,
      price_down_buy  = prices$Flex_unit_cost_down_com_buy,
      price_up_sell   = prices$Flex_unit_cost_up_com_sell,
      price_up_buy    = prices$Flex_unit_cost_up_com_buy
    )
  }

  operations <- data.frame(
    time               = after$time,
    Energy_bought      = energy$qty_buy_new,
    Energy_resold      = energy$qty_sell_back,
    Energy_sold        = energy$qty_sell_new,
    Energy_rebought    = energy$qty_buy_back,
    Flex_down_sold     = flex_down$down_sold,
    Flex_down_rebought = flex_down$down_bought,
    Flex_up_sold       = flex_up$up_sold,
    Flex_up_rebought   = flex_up$up_bought
  )

  rm(after, before, prices, energy, flex_down, flex_up)

  return(operations)
}
