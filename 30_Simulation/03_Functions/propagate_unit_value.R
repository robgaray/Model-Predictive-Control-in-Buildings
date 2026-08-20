# -------------------------------------------------------------
# Function: propagate_unit_value.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Accumulates an already-resolved net cash flow (delta_C) for a single
# market/target-interval decision into a market-resolution cost
# matrix, and propagates its unit value, weighted by energy, to the
# 5-minute rows of Main_df that share the target interval's MarketUTC.
# This is the reusable second half of propagate_differential_cost():
# that function additionally resolves delta_C itself via
# calc_differential_cost() for a single (E_orig, E_new, four prices)
# transition; this function is called directly whenever delta_C has
# already been resolved some other way (e.g. the down/up-leg
# flexibility valuation of integrate_market_process.R, via
# value_flex_operation(), which is not a single import/export
# transition and so cannot go through calc_differential_cost()).
# -------------------------------------------------------------
# Inputs
# row_m      : Integer. Row of the current market event in cost_df
#              (a sparse, market-event row set; not the full
#              market-resolution grid).
# col_j      : Character. Market-resolution column (future-step
#              offset) of the target interval in cost_df.
# mkt_target : POSIXct scalar. MarketUTC of the target interval,
#              used to locate its Main_df rows.
# delta_C    : Numeric scalar. Net cash flow to accumulate for the
#              target interval (positive = income, negative = expense).
# cost_df    : Data frame. Market-resolution cost matrix to accumulate
#              delta_C into (e.g. market_commitments$Elec_flex_Cost_plan_df).
# Main_df    : Data frame. The main simulation data frame.
# weight_col : Character. Name of the Main_df column holding the
#              per-timestamp energy used to weight the value
#              propagation (e.g. "Elec_flex_plan"). The column is a
#              signed position; its absolute value is what is used as
#              the weight - see block 2.
# target_col : Character. Name of the Main_df column to add the
#              propagated unit value to (e.g. "Elec_flex_commitment_revenue_h").
# -------------------------------------------------------------
# Outputs
# Named list with:
#   Main_df : Data frame. Updated in place at target_col for the
#             5-minute rows of the target interval.
#   cost_df : Data frame. Updated in place at [row_m, col_j].
# -------------------------------------------------------------
# Code outline
# 1. Accumulation into cost_df
# 2. Unit value propagation to Main_df, weighted by energy per timestamp
# -------------------------------------------------------------
# Usage instructions
# result  <- propagate_unit_value(row_m, col_j, mkt_target, delta_C, cost_df, Main_df, weight_col, target_col)
# Main_df <- result$Main_df
# cost_df <- result$cost_df
# -------------------------------------------------------------
# Where this function/script is used
# Called by propagate_differential_cost() (energy) and directly by
# integrate_market_process.R (explicit flexibility).
# -------------------------------------------------------------
# functions/scripts called
# None.
# -------------------------------------------------------------

propagate_unit_value <- function(row_m,
                                 col_j,
                                 mkt_target,
                                 delta_C,
                                 cost_df,
                                 Main_df,
                                 weight_col,
                                 target_col) {

  # 1. Accumulation into cost_df
  {
    cost_df[row_m, col_j] <- cost_df[row_m, col_j] + delta_C
  }

  # 2. Unit value propagation to Main_df, weighted by energy per timestamp
  # -------------------------------------------------------------
  # The weight is abs(weight_col), not weight_col itself. The weight
  # columns hold signed positions: inside a single market interval
  # some timesteps can be importing while others export, so their
  # signed sum is a net that can come arbitrarily close to zero while
  # the individual timesteps are large. Weighting by that net would
  # keep the interval's total correct but scatter enormous values of
  # opposite sign across neighbouring rows. abs() is what "how much
  # energy this timestep moves within the interval" actually means,
  # and it keeps every row's share non-negative.
  # -------------------------------------------------------------
  {
    rows_ts <- which(Main_df$MarketUTC == mkt_target)
    E_ts    <- abs(Main_df[[weight_col]][rows_ts])
    E_total <- sum(E_ts)

    # data.table::set() writes the target interval's rows straight into
    # Main_df's existing column. This runs twice per target interval of
    # every market, so avoiding a copy of the column each time matters.
    if (E_total != 0) {
      delta_unit <- delta_C / E_total
      set(Main_df, i = rows_ts, j = target_col,
          value = Main_df[[target_col]][rows_ts] + delta_unit * E_ts)
    } else {
      set(Main_df, i = rows_ts, j = target_col,
          value = Main_df[[target_col]][rows_ts] + delta_C / length(rows_ts))
    }
  }

  return(list(Main_df = Main_df, cost_df = cost_df))
}
