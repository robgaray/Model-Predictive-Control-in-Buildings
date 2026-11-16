# -------------------------------------------------------------
# Function: propagate_differential_cost.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
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
# see settle_market.R.
# -------------------------------------------------------------
# Inputs
# Same meaning as in propagate_unit_value():
#   - row_m
#   - col_j
#   - cost_df
#   - rows_ts
#   - weight_ts
# Numeric scalars, passed straight through to calc_differential_cost()
# (see that function's header for their meaning):
#   - E_orig
#   - E_new
#   - P_import_buy
#   - P_import_sell
#   - P_export_buy
#   - P_export_sell
# -------------------------------------------------------------
# Outputs
# Named list, as returned by propagate_unit_value():
#   - cost_df : Data frame. cost_df with the cash flow added at
#               [row_m, col_j], added in place, so the cost_df passed
#               in holds it too.
#   - rows    : Integer vector. The rows of Main_df to write.
#   - delta   : Numeric vector. Amount to add to each of those rows.
# -------------------------------------------------------------
# Code outline
# 1. Net cash flow of this transition
# 2. Accumulation and propagation via propagate_unit_value()
# -------------------------------------------------------------
# Usage instructions
# result  <- propagate_differential_cost(row_m, col_j, E_orig,
# E_new, P_import_buy, P_import_sell, P_export_buy, P_export_sell, cost_df,
# rows_ts, weight_ts)
# cost_df <- result$cost_df
# The caller adds result$delta to its target column at result$rows.
# -------------------------------------------------------------

propagate_differential_cost <- function(row_m,
                                        col_j,
                                        E_orig,
                                        E_new,
                                        P_import_buy,
                                        P_import_sell,
                                        P_export_buy,
                                        P_export_sell,
                                        cost_df,
                                        rows_ts,
                                        weight_ts) {

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
  # and spread its unit value across the rows of this target
  # interval, weighted by weight_ts.
  # -------------------------------------------------------------
  return(propagate_unit_value(
    row_m      = row_m,
    col_j      = col_j,
    delta_C    = delta_C,
    cost_df    = cost_df,
    rows_ts    = rows_ts,
    weight_ts  = weight_ts
  ))
}
