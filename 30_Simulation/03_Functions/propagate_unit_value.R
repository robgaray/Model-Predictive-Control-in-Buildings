# -------------------------------------------------------------
# Function: propagate_unit_value.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Accumulates an already-resolved net cash flow (delta_C) for a single
# market/target-interval decision into a market-resolution cost
# matrix, and spreads its unit value, weighted by energy, over the
# 5-minute rows that share the target interval's MarketUTC.
# The function writes nothing into Main_df: it returns the amount to
# add to each of those rows, and the simulation loop writes it.
# This is the reusable second half of propagate_differential_cost():
# that function additionally resolves delta_C itself via
# calc_differential_cost() for a single (E_orig, E_new, four prices)
# transition; this function is called directly whenever delta_C has
# already been resolved some other way (e.g. the down/up-leg
# flexibility valuation of settle_market.R, via
# value_flex_operation(), which is not a single import/export
# transition and so cannot go through calc_differential_cost()).
# -------------------------------------------------------------
# Inputs
# row_m      : Integer. Row of the current market event in cost_df
#              (a sparse, market-event row set; not the full
#              market-resolution grid).
# col_j      : Character. Market-resolution column (future-step
#              offset) of the target interval in cost_df.
# delta_C    : Numeric scalar. Net cash flow to accumulate for the
#              target interval (positive = income, negative = expense).
# cost_df    : Data frame. Market-resolution cost matrix to accumulate
#              delta_C into (e.g. market_commitments$Elec_flex_Cost_plan_df).
# rows_ts    : Integer vector. Rows of Main_df that belong to the
#              target interval.
# weight_ts  : Numeric vector, as long as rows_ts. Energy position of
#              each of those rows, used to weight the value
#              propagation. It is a signed position; its absolute value
#              is what is used as the weight - see block 2.
# -------------------------------------------------------------
# Outputs
# Named list with:
#   cost_df : Data frame. cost_df with delta_C added at [row_m, col_j].
#             The addition is made in place (add_to_table_cells()), so
#             the cost_df passed in holds it too.
#   rows    : Integer vector. The rows of Main_df to write (rows_ts).
#   delta   : Numeric vector, as long as rows. Amount to add to each of
#             those rows of the target column.
# -------------------------------------------------------------
# Code outline
# 1. Accumulation into cost_df
# 2. Unit value spread over the rows of the target interval, weighted
#    by energy per timestamp
# -------------------------------------------------------------
# Usage instructions
# result  <- propagate_unit_value(row_m, col_j, delta_C, cost_df,
# rows_ts, weight_ts)
# cost_df <- result$cost_df
# The caller adds result$delta to the target column at result$rows.
# -------------------------------------------------------------

propagate_unit_value <- function(row_m,
                                 col_j,
                                 delta_C,
                                 cost_df,
                                 rows_ts,
                                 weight_ts) {

  # 1. Accumulation into cost_df
  {
    # add_to_table_cells is called to add delta_C to the cell of the
    # market event and the target interval, in place.
    add_to_table_cells(
      table   = cost_df,
      rows    = row_m,
      columns = col_j,
      values  = delta_C
    )
  }

  # 2. Unit value spread over the rows, weighted by energy per timestamp
  # -------------------------------------------------------------
  # The weight is abs(weight_ts), not weight_ts itself. The weights
  # are signed positions: inside a single market interval
  # some timesteps can be importing while others export, so their
  # signed sum is a net that can come arbitrarily close to zero while
  # the individual timesteps are large. Weighting by that net would
  # keep the interval's total correct but scatter enormous values of
  # opposite sign across neighbouring rows. abs() is what "how much
  # energy this timestep moves within the interval" actually means,
  # and it keeps every row's share non-negative.
  # -------------------------------------------------------------
  {
    E_ts    <- abs(weight_ts)
    E_total <- sum(E_ts)

    if (E_total != 0) {
      delta_unit <- delta_C / E_total
      delta_ts   <- delta_unit * E_ts
    } else {
      delta_ts <- rep(delta_C / length(rows_ts), length(rows_ts))
    }
  }

  return(list(cost_df = cost_df,
              rows    = rows_ts,
              delta   = delta_ts))
}
