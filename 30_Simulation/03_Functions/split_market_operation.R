# -------------------------------------------------------------
# Function: split_market_operation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Same four price regimes and same six branches as
# calc_differential_cost() (same inputs, same signs, same
# asymmetric-price logic), but it separates the move from E_orig to
# E_new into the four elementary market operations that accounting
# needs to keep apart, instead of a single net cash flow:
#
#   buy_new   ("compra")   - taking on, or increasing, a positive
#                            (import) position. Priced at P_import_buy.
#   sell_back ("reventa")  - reducing, or closing, a previously held
#                            positive position, i.e. reselling something
#                            bought earlier. Priced at P_import_sell.
#   sell_new  ("venta")    - taking on, or increasing, a negative
#                            (export) position. Priced at P_export_sell.
#   buy_back  ("recompra") - reducing, or closing, a previously held
#                            negative position, i.e. buying back
#                            something sold earlier. Priced at
#                            P_export_buy.
#
# For each of the four, both the quantity (always >= 0, in the units of
# E_orig/E_new) and its value (always >= 0, quantity times the matching
# price) are returned.
# -------------------------------------------------------------
# Relationship with calc_differential_cost()
# For every input, the following identity holds exactly:
#   calc_differential_cost() = (val_sell_new + val_sell_back) -
#                              (val_buy_new  + val_buy_back)
# calc_differential_cost() is in fact implemented as a thin wrapper
# over this function, so the branch logic lives in one place only.
# -------------------------------------------------------------
# Inputs
# E_orig         : Numeric vector. Previous net position per slot.
# E_new          : Numeric vector. New net position per slot.
# P_import_buy   : Numeric vector. Price of a new/incremental positive
#                  position.
# P_import_sell  : Numeric vector. Price of unwinding a previous
#                  positive position.
# P_export_buy   : Numeric vector. Price of unwinding a previous
#                  negative position.
# P_export_sell  : Numeric vector. Price of a new/incremental negative
#                  position.
# All six vectors must have the same length.
# -------------------------------------------------------------
# Outputs
# Named list of eight numeric vectors, all >= 0 and all the same length
# as the inputs:
#   qty_buy_new,   qty_buy_back,   qty_sell_new,   qty_sell_back
#   val_buy_new,   val_buy_back,   val_sell_new,   val_sell_back
# -------------------------------------------------------------
# Code outline
# 1. Loop over slots, mirroring calc_differential_cost()'s six
#    branches, and assign each branch's magnitude and value to the
#    corresponding elementary operation.
# -------------------------------------------------------------
# Usage instructions
# op <- split_market_operation(E_orig, E_new, P_import_buy, P_import_sell, P_export_buy, P_export_sell)
# energy_bought   <- op$qty_buy_new
# energy_resold   <- op$qty_sell_back
# -------------------------------------------------------------
# Where this function/script is used
# Called by calc_differential_cost() (which aggregates its eight
# outputs into a single net cash flow), by economic_analysis_finalize.R (the
# Execution-phase deviation), and by integrate_market_process.R, which
# accumulates the elementary quantities and values into the economic_analysis
# accumulators (see economic_analysis_setup.R) and into the "_market" lump-sum
# Main_df columns.
# -------------------------------------------------------------
# functions/scripts called
# None.
# -------------------------------------------------------------

split_market_operation <- function(E_orig, E_new,
                                   P_import_buy, P_import_sell,
                                   P_export_buy, P_export_sell) {

  n_slots <- length(E_orig)

  qty_buy_new   <- numeric(n_slots)
  qty_buy_back  <- numeric(n_slots)
  qty_sell_new  <- numeric(n_slots)
  qty_sell_back <- numeric(n_slots)
  val_buy_new   <- numeric(n_slots)
  val_buy_back  <- numeric(n_slots)
  val_sell_new  <- numeric(n_slots)
  val_sell_back <- numeric(n_slots)

  for (CONT_001 in seq_len(n_slots)) {
    eo   <- E_orig[CONT_001]
    en   <- E_new[CONT_001]
    p_ib <- P_import_buy[CONT_001]
    p_is <- P_import_sell[CONT_001]
    p_eb <- P_export_buy[CONT_001]
    p_es <- P_export_sell[CONT_001]

    if (eo > 0) {
      if (en >= 0) {
        delta <- en - eo
        if (delta >= 0) {
          qty_buy_new[CONT_001]   <- delta
          val_buy_new[CONT_001]   <- delta * p_ib
        } else {
          qty_sell_back[CONT_001] <- -delta
          val_sell_back[CONT_001] <- -delta * p_is
        }
      } else {
        qty_sell_back[CONT_001] <- eo
        val_sell_back[CONT_001] <- eo * p_is
        qty_sell_new[CONT_001]  <- -en
        val_sell_new[CONT_001]  <- -en * p_es
      }
    } else {
      if (en <= 0) {
        delta <- en - eo
        if (delta <= 0) {
          qty_sell_new[CONT_001] <- -delta
          val_sell_new[CONT_001] <- -delta * p_es
        } else {
          qty_buy_back[CONT_001] <- delta
          val_buy_back[CONT_001] <- delta * p_eb
        }
      } else {
        qty_buy_back[CONT_001] <- -eo
        val_buy_back[CONT_001] <- -eo * p_eb
        qty_buy_new[CONT_001]  <- en
        val_buy_new[CONT_001]  <- en * p_ib
      }
    }

    rm(eo, en, p_ib, p_is, p_eb, p_es)
    # inherits = FALSE so that only a delta created by this iteration is
    # removed. With the default (inherits = TRUE) the lookup would also
    # find a delta in an enclosing or the global environment, and rm()
    # would then warn about an object that is not there.
    if (exists("delta", inherits = FALSE)) rm(delta)
  }
  rm(CONT_001, n_slots)

  return(list(
    qty_buy_new   = qty_buy_new,
    qty_buy_back  = qty_buy_back,
    qty_sell_new  = qty_sell_new,
    qty_sell_back = qty_sell_back,
    val_buy_new   = val_buy_new,
    val_buy_back  = val_buy_back,
    val_sell_new  = val_sell_new,
    val_sell_back = val_sell_back
  ))
}
