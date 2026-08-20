# -------------------------------------------------------------
# Function: propagate_differential_cost.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Resolves the net cash flow of a single market/target-interval energy
# transaction via calc_differential_cost(), then accumulates and
# propagates it via propagate_unit_value() (see that function's header
# for the accumulation/propagation mechanics). Used for the two
# energy-differential-cost signals of the simulation (base energy cost
# for Scheduling, flex-adjusted energy cost for Piloting), which both
# follow the same "resolve a single import/export transition" shape.
# The explicit-flexibility signal does not go through this function:
# it values two independent down/up legs rather than a single
# import/export transition, so it resolves its own net cash flow via
# value_flex_operation() and calls propagate_unit_value() directly -
# see integrate_market_process.R.
# -------------------------------------------------------------
# Inputs
# row_m, col_j, mkt_target, cost_df, Main_df, weight_col, target_col :
#              Same meaning as in propagate_unit_value().
# E_orig, E_new, P_import_buy, P_import_sell, P_export_buy, P_export_sell :
#              Numeric scalars, passed straight through to
#              calc_differential_cost() (see that function's header
#              for their meaning).
# -------------------------------------------------------------
# Outputs
# Named list with:
#   Main_df : Data frame. Updated in place at target_col for the
#             5-minute rows of the target interval.
#   cost_df : Data frame. Updated in place at [row_m, col_j].
# -------------------------------------------------------------
# Code outline
# 1. Net cash flow of this transition
# 2. Accumulation and propagation via propagate_unit_value()
# -------------------------------------------------------------
# Usage instructions
# result  <- propagate_differential_cost(row_m, col_j, mkt_target, E_orig, E_new, P_import_buy, P_import_sell, P_export_buy, P_export_sell, cost_df, Main_df, weight_col, target_col)
# Main_df <- result$Main_df
# cost_df <- result$cost_df
# -------------------------------------------------------------
# Where this function/script is used
# Called by integrate_market_process.R for the base energy cost
# (Scheduling) and the flex-adjusted energy cost (Piloting).
# -------------------------------------------------------------
# functions/scripts called
# calc_differential_cost(), propagate_unit_value()
# -------------------------------------------------------------

propagate_differential_cost <- function(row_m,
                                        col_j,
                                        mkt_target,
                                        E_orig,
                                        E_new,
                                        P_import_buy,
                                        P_import_sell,
                                        P_export_buy,
                                        P_export_sell,
                                        cost_df,
                                        Main_df,
                                        weight_col,
                                        target_col) {

  # 1. Net cash flow of this transition
  # -------------------------------------------------------------
  # calc_differential_cost is called to price the change from E_orig to
  # E_new for this target interval at the current market's buy/sell
  # prices, so only the marginal (incremental) cash flow of this
  # market's decision is accumulated, not the full commitment.
  # -------------------------------------------------------------
  delta_C <- calc_differential_cost(E_orig, E_new, P_import_buy, P_import_sell,
                                    P_export_buy, P_export_sell)

  # 2. Accumulation and propagation
  # -------------------------------------------------------------
  # propagate_unit_value is called to accumulate delta_C into cost_df
  # and spread its unit value across Main_df's rows for this target
  # interval, weighted by weight_col.
  # -------------------------------------------------------------
  return(propagate_unit_value(
    row_m      = row_m,
    col_j      = col_j,
    mkt_target = mkt_target,
    delta_C    = delta_C,
    cost_df    = cost_df,
    Main_df    = Main_df,
    weight_col = weight_col,
    target_col = target_col
  ))
}
