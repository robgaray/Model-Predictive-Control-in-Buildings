# -------------------------------------------------------------
# Script: economic_analysis_finalize.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Completes the economic analysis tables once the simulation loop is
# over. The Scheduling and Piloting flows were already accumulated
# during the loop by integrate_market_process.R; this script adds the
# execution-phase flows, which can be derived from Main_df in one pass
# at the end, and turns the working quantities into the reported
# fractions, whose denominators are only known once every market has
# traded.
# -------------------------------------------------------------
# The execution phase
# Execution is not a market: it is the physical delivery of energy,
# and it deviates from the last committed plan because the building
# does not behave exactly as forecast. Its economics are therefore the
# move from the last committed position (Elec_total_plan) to what was
# actually delivered (Elec_total_exec), valued at that slot's own
# import/export prices, resolved here into its four elementary
# operations instead of a single net number.
# The move is netted per market slot before it is resolved: energy is
# traded per slot, so only the slot's net adjustment is a real market
# operation. A deviation that merely shifts energy from one timestep
# to another inside the same slot leaves the slot's position almost
# unchanged and must not be reported as a purchase plus a matching
# sale - see 00_Agent_Input/20260820_Correcciones.md.
# implement_control_step.R still prices the same deviation per
# timestep into Elec_deviations_net_cost_h; that column is a
# per-timestep cost signal, not a market operation, so the two are
# expected to differ whenever a slot's timesteps offset each other.
# -------------------------------------------------------------
# Cost and revenue of an unwinding operation
# Only a new purchase is a cost and only a new sale is a revenue. A
# resale undoes an earlier purchase and is therefore an avoided cost
# (it reduces Cost_energy_bought); a rebuy undoes an earlier sale and
# is an avoided revenue (it reduces Revenue_energy_sold). Neither is
# reported as a flow of the opposite kind - see
# accumulate_market_operation()'s header, which applies the same rule
# to the Scheduling and Piloting flows. Cash_flow is identical either
# way; only the split between cost and revenue changes.
# -------------------------------------------------------------
# Executed flexibility
# Flexibility execution is not simulated yet: the building always
# delivers its baseline plan, and no flexibility activation is ever
# booked. The two Main_df signals reserved for it,
# Elec_flex_execution_revenue_h and Elec_flex_deviations_net_cost_h,
# are consequently zero for every row. The executed volume is computed
# from them, as the committed down-flexibility volume of the rows on
# which the execution phase actually booked a flexibility activation,
# so columns 14 and 15 of economic_analysis$market and the corresponding slot
# figures all come out as 0 today, and will report real values without
# any further change once flexibility execution is implemented.
# -------------------------------------------------------------
# Inputs
#   analysis   : Named list. The accumulators built by economic_analysis_setup.R
#                and filled during the simulation loop.
#   Main_df    : Data frame. The simulation results.
#   parameters : Named list. Only parameters$debug_and_config$verbose
#                is read, to gate the console summary at the end.
# -------------------------------------------------------------
# Outputs
#   analysis : Named list of 2 data frames (market, slot), with every
#              reported column filled in and the working columns and
#              the index sub-list removed.
# -------------------------------------------------------------
# Code outline
# 1. Per-slot aggregation helpers
# 2. Execution-phase operations, per market slot
# 3. Fill the Execution rows of economic_analysis$market
# 4. Fill the remaining economic_analysis$slot columns
# 5. Derive the reported fractions
# 6. Drop the working columns and the index
# -------------------------------------------------------------
# Usage
# source(file.path("30_Simulation", "04_Scripts", "economic_analysis_finalize.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by Main.R, after simulation.R and before data_outputs.R.
# -------------------------------------------------------------
# functions/scripts called
# split_market_operation()
# -------------------------------------------------------------

# -------------------------------------------------------------
# 1. Per-slot aggregation helpers
# -------------------------------------------------------------
{
  # Grouping is done on the numeric form of the timestamps, not on
  # their text form, so that the aggregation cannot be broken by a
  # locale or timezone difference in how a POSIXct prints. Slots with
  # no Main_df row would come back as NA from the match, so they are
  # forced to 0: nothing was delivered there.
  slot_group   <- as.numeric(Main_df$MarketUTC)
  slot_targets <- as.numeric(economic_analysis$slot$time)

  sum_by_slot <- function(values) {
    aggregated <- tapply(values, slot_group, sum)
    result     <- as.numeric(aggregated[match(slot_targets, as.numeric(names(aggregated)))])
    result[is.na(result)] <- 0
    result
  }

  # Prices are a property of the market slot, not of the timestep, so
  # the slot's own price is taken from its first row rather than
  # aggregated - the same rule integrate_market_process.R uses to read
  # Flex_Probab for a target interval.
  first_by_slot <- function(values) {
    aggregated <- tapply(values, slot_group, function(v) v[1])
    result     <- as.numeric(aggregated[match(slot_targets, as.numeric(names(aggregated)))])
    result[is.na(result)] <- 0
    result
  }
}

# -------------------------------------------------------------
# 2. Execution-phase operations, per market slot
# -------------------------------------------------------------
# Energy is bought and sold per market slot, not per timestep, so the
# committed plan and the realized delivery are netted over all the
# timesteps of each slot BEFORE being resolved into elementary
# operations. Doing it the other way round (one operation per 5-minute
# row, summed afterwards) invents a buy and a matching sell whenever
# the deviation merely moves energy between two timesteps of the same
# slot, even though the slot's net position barely changed - see
# 00_Agent_Input/20260820_Correcciones.md. Only the slot's net
# adjustment is a real market operation.
# -------------------------------------------------------------
{
  # split_market_operation is called on the move from the last
  # committed plan to the realized delivery, per slot and at that
  # slot's own prices, so that the execution deviation is available
  # split into energy bought, bought back, sold and resold, rather
  # than only as the net cost implement_control_step.R already stores.
  execution_operation <- split_market_operation(
    E_orig        = sum_by_slot(Main_df$Elec_total_plan),
    E_new         = sum_by_slot(Main_df$Elec_total_exec),
    P_import_buy  = first_by_slot(Main_df$Elec_unit_cost_import_buy),
    P_import_sell = first_by_slot(Main_df$Elec_unit_cost_import_sell),
    P_export_buy  = first_by_slot(Main_df$Elec_unit_cost_export_buy),
    P_export_sell = first_by_slot(Main_df$Elec_unit_cost_export_sell)
  )

  # A flexibility activation is considered booked on a row when the
  # execution phase wrote either of the two signals reserved for it.
  # Neither is written today, so this is 0 for every row.
  flex_activated <- as.numeric(
    Main_df$Elec_flex_execution_revenue_h  != 0 |
    Main_df$Elec_flex_deviations_net_cost_h != 0
  )

  # The operation is already resolved per slot, so its components are
  # taken as they are; only the quantities that genuinely live at
  # timestep resolution still go through sum_by_slot().
  exec_bought   <- execution_operation$qty_buy_new
  exec_rebought <- execution_operation$qty_buy_back
  exec_sold     <- execution_operation$qty_sell_new
  exec_resold   <- execution_operation$qty_sell_back

  # A resale is an avoided cost and a rebuy an avoided revenue, so
  # each is reported against the flow it cancels instead of as a flow
  # of the opposite kind - same rule as accumulate_market_operation(),
  # see its header.
  exec_cost    <- execution_operation$val_buy_new  - execution_operation$val_sell_back
  exec_revenue <- execution_operation$val_sell_new - execution_operation$val_buy_back
  exec_unwind_value <- execution_operation$val_buy_back + execution_operation$val_sell_back
  exec_unwind_pl    <- execution_operation$val_sell_back - execution_operation$val_buy_back

  distribution_cost <- sum_by_slot(Main_df$Elec_cost_distr_h)

  # Both terms already carry the repository's sign (income positive,
  # expense negative), so this is a plain sum.
  flex_executed          <- sum_by_slot(Main_df$Elec_flex_plan * flex_activated)
  flex_executed_cashflow <- sum_by_slot(Main_df$Elec_flex_execution_revenue_h) +
                            sum_by_slot(Main_df$Elec_flex_deviations_net_cost_h)

  energy_in        <- sum_by_slot(pmax(Main_df$Elec_total_exec, 0))
  energy_out       <- sum_by_slot(pmax(-Main_df$Elec_total_exec, 0))

  rm(execution_operation, flex_activated)
}

# -------------------------------------------------------------
# 3. Fill the Execution rows of economic_analysis$market
# -------------------------------------------------------------
# Cash_flow is the all-in cash flow of the row: the energy deviation
# (revenue minus cost), plus the distribution cost of the energy
# delivered (already negative - see implement_control_step.R), plus
# the cash flow of any executed flexibility. The last two are also
# reported on their own, in columns 15 and 16, so those two columns
# are a breakdown of part of column 12, not additions to it.
# -------------------------------------------------------------
{
  exec_rows <- economic_analysis$market$market_type == "Execution"
  exec_slot <- match(as.numeric(economic_analysis$market$time[exec_rows]), economic_analysis$index$slot_key)

  economic_analysis$market$Energy_bought[exec_rows]   <- exec_bought[exec_slot]
  economic_analysis$market$Energy_rebought[exec_rows] <- exec_rebought[exec_slot]
  economic_analysis$market$Energy_sold[exec_rows]     <- exec_sold[exec_slot]
  economic_analysis$market$Energy_resold[exec_rows]   <- exec_resold[exec_slot]

  economic_analysis$market$Cash_flow[exec_rows] <-
    (exec_revenue[exec_slot] - exec_cost[exec_slot]) +
    distribution_cost[exec_slot] +
    flex_executed_cashflow[exec_slot]

  economic_analysis$market$PL_rebuy_resale[exec_rows] <- exec_unwind_pl[exec_slot]

  economic_analysis$market$Flex_executed[exec_rows]           <- flex_executed[exec_slot]
  economic_analysis$market$Flex_executed_cash_flow[exec_rows] <- flex_executed_cashflow[exec_slot]
  economic_analysis$market$Distribution_cost[exec_rows]       <- distribution_cost[exec_slot]

  rm(exec_rows, exec_slot)
}

# -------------------------------------------------------------
# 4. Fill the remaining economic_analysis$slot columns
# -------------------------------------------------------------
{
  economic_analysis$slot$Energy_in         <- energy_in
  economic_analysis$slot$Energy_out        <- energy_out
  economic_analysis$slot$Distribution_cost <- distribution_cost

  economic_analysis$slot$Cost_energy_bought  <- economic_analysis$slot$Cost_energy_bought  + exec_cost
  economic_analysis$slot$Revenue_energy_sold <- economic_analysis$slot$Revenue_energy_sold + exec_revenue

  economic_analysis$slot$Qty_execution     <- exec_bought + exec_sold
  economic_analysis$slot$Qty_rebuy_resale  <- economic_analysis$slot$Qty_rebuy_resale + exec_rebought + exec_resold
  economic_analysis$slot$Val_rebuy_resale  <- economic_analysis$slot$Val_rebuy_resale + exec_unwind_value

  economic_analysis$slot$Cash_flow <- economic_analysis$slot$Cash_flow +
    (exec_revenue - exec_cost) + distribution_cost + flex_executed_cashflow

  rm(energy_in, energy_out, exec_bought, exec_rebought, exec_sold, exec_resold,
     exec_cost, exec_revenue, exec_unwind_value, exec_unwind_pl,
     distribution_cost, flex_executed, flex_executed_cashflow,
     sum_by_slot, first_by_slot, slot_group, slot_targets)
}

# -------------------------------------------------------------
# 5. Derive the reported fractions
# -------------------------------------------------------------
# A fraction whose denominator is zero is reported as NA rather than
# as 0: with no energy traded in the slot, the share of that energy
# committed in Scheduling (or unwound, or adjusted at Execution) is
# undefined, and reporting 0 would read as "none of it", which is a
# different statement.
# -------------------------------------------------------------
{
  safe_fraction <- function(numerator, denominator) {
    ifelse(denominator == 0, NA_real_, numerator / denominator)
  }

  energy_gross <- economic_analysis$slot$Energy_in + economic_analysis$slot$Energy_out

  economic_analysis$slot$Frac_scheduling   <- safe_fraction(economic_analysis$slot$Qty_scheduling,   energy_gross)
  economic_analysis$slot$Frac_rebuy_resale <- safe_fraction(economic_analysis$slot$Qty_rebuy_resale, energy_gross)
  economic_analysis$slot$Frac_execution    <- safe_fraction(economic_analysis$slot$Qty_execution,    energy_gross)

  economic_analysis$slot$Frac_flex_rebuy <- safe_fraction(
    economic_analysis$slot$Qty_flex_rebought,
    economic_analysis$slot$Flex_committed
  )

  economic_analysis$slot$Frac_rebuy_resale_value <- safe_fraction(
    economic_analysis$slot$Val_rebuy_resale,
    economic_analysis$slot$Cost_energy_bought +
      economic_analysis$slot$Revenue_energy_sold +
      economic_analysis$slot$Revenue_flex_commitments
  )

  rm(safe_fraction, energy_gross)
}

# -------------------------------------------------------------
# 6. Drop the working columns and the index
# -------------------------------------------------------------
{
  working_cols <- c("Qty_scheduling", "Qty_rebuy_resale", "Qty_execution",
                    "Qty_flex_rebought", "Val_rebuy_resale")
  economic_analysis$slot <- economic_analysis$slot[, setdiff(names(economic_analysis$slot), working_cols)]
  economic_analysis$index <- NULL

  if (parameters$debug_and_config$verbose) {
    cat("economic_analysis completed:", nrow(economic_analysis$market), "market rows,",
        nrow(economic_analysis$slot), "slot rows\n")
  }

  rm(working_cols)
}
