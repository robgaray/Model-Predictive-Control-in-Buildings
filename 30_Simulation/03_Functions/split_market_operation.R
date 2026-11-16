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
#   - qty_buy_new, val_buy_new: new purchase, quantity and value
#   - qty_buy_back, val_buy_back: buy back of an earlier sale
#   - qty_sell_new, val_sell_new: new sale
#   - qty_sell_back, val_sell_back: resale of an earlier purchase
# -------------------------------------------------------------
# Code outline
# 1. Check the inputs
# 2. Place every slot in one of the six branches
# 3. Quantity and value of each elementary operation
# -------------------------------------------------------------
# Usage instructions
# op <- split_market_operation(E_orig, E_new, P_import_buy, P_import_sell,
# P_export_buy, P_export_sell)
# energy_bought   <- op$qty_buy_new
# energy_resold   <- op$qty_sell_back
# -------------------------------------------------------------

split_market_operation <- function(E_orig, E_new,
                                   P_import_buy, P_import_sell,
                                   P_export_buy, P_export_sell) {

  # -------------------------------------------------------------
  # 1. Check the inputs
  # The six vectors are compared and combined element by
  # element, so they must have the same length, and a position
  # that is missing cannot be placed in any branch.
  # -------------------------------------------------------------
  {
    n_slots <- length(E_orig)

    if (any(lengths(list(E_new, P_import_buy, P_import_sell,
                         P_export_buy, P_export_sell)) != n_slots)) {
      stop("split_market_operation: E_orig, E_new and the four ",
           "prices must have the same length")
    }
    if (anyNA(E_orig) || anyNA(E_new)) {
      stop("split_market_operation: E_orig and E_new cannot hold NA")
    }
  }

  # -------------------------------------------------------------
  # 2. Place every slot in one of the six branches
  # Each branch is a logical mask over all the slots, so the
  # six cases are resolved for the whole vector at once instead
  # of slot by slot. Every slot falls in exactly one of them:
  #   - long_grows    : long before, long after, larger
  #   - long_shrinks  : long before, long after, smaller
  #   - long_to_short : long before, short after
  #   - short_grows   : short or flat before, short after,
  #                     larger in size
  #   - short_shrinks : short or flat before, short after,
  #                     smaller in size
  #   - short_to_long : short or flat before, long after
  # "Long" is a positive (import) position and "short" a
  # negative (export) one, as in calc_differential_cost().
  # -------------------------------------------------------------
  {
    delta    <- E_new - E_orig
    was_long <- E_orig > 0

    long_grows    <- was_long  & E_new >= 0 & delta >= 0
    long_shrinks  <- was_long  & E_new >= 0 & delta <  0
    long_to_short <- was_long  & E_new <  0
    short_grows   <- !was_long & E_new <= 0 & delta <= 0
    short_shrinks <- !was_long & E_new <= 0 & delta >  0
    short_to_long <- !was_long & E_new >  0
  }

  # -------------------------------------------------------------
  # 3. Quantity and value of each elementary operation
  # Every operation starts at zero, and each branch writes the
  # operations it holds, with the same arithmetic in every
  # slot.
  # -------------------------------------------------------------
  {
    qty_buy_new   <- numeric(n_slots)
    qty_buy_back  <- numeric(n_slots)
    qty_sell_new  <- numeric(n_slots)
    qty_sell_back <- numeric(n_slots)
    val_buy_new   <- numeric(n_slots)
    val_buy_back  <- numeric(n_slots)
    val_sell_new  <- numeric(n_slots)
    val_sell_back <- numeric(n_slots)

    # The position grows: a new purchase
    qty_buy_new[long_grows] <- delta[long_grows]
    val_buy_new[long_grows] <- delta[long_grows] * P_import_buy[long_grows]

    # The position shrinks: part of it is resold
    qty_sell_back[long_shrinks] <- -delta[long_shrinks]
    val_sell_back[long_shrinks] <- -delta[long_shrinks] * P_import_sell[long_shrinks]

    # It turns short: all of it is resold, and the rest is sold
    # anew
    qty_sell_back[long_to_short] <- E_orig[long_to_short]
    val_sell_back[long_to_short] <- E_orig[long_to_short] * P_import_sell[long_to_short]
    qty_sell_new[long_to_short]  <- -E_new[long_to_short]
    val_sell_new[long_to_short]  <- -E_new[long_to_short] * P_export_sell[long_to_short]

    # The short position grows: a new sale
    qty_sell_new[short_grows] <- -delta[short_grows]
    val_sell_new[short_grows] <- -delta[short_grows] * P_export_sell[short_grows]

    # The short position shrinks: part of it is bought back
    qty_buy_back[short_shrinks] <- delta[short_shrinks]
    val_buy_back[short_shrinks] <- delta[short_shrinks] * P_export_buy[short_shrinks]

    # It turns long: all of it is bought back, and the rest is
    # bought anew
    qty_buy_back[short_to_long] <- -E_orig[short_to_long]
    val_buy_back[short_to_long] <- -E_orig[short_to_long] * P_export_buy[short_to_long]
    qty_buy_new[short_to_long]  <- E_new[short_to_long]
    val_buy_new[short_to_long]  <- E_new[short_to_long] * P_import_buy[short_to_long]

    rm(list = c("n_slots", "delta", "was_long", "long_grows", "long_shrinks",
                "long_to_short", "short_grows", "short_shrinks",
                "short_to_long"))
  }

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
