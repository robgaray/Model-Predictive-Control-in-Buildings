# -------------------------------------------------------------
# Function: resolve_marginal_context.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Builds, per market interval of the optimization horizon, what the
# reward needs to value a candidate at its marginal cash flow: the
# commitments already held before this market, the prices of this
# market and the revenue discount. It is resolved once per call,
# before the optimizer runs, so every candidate is valued against the
# same baseline and prices.
# The intervals valued are those from i_begin_horizon to the last one
# before i_end_horizon. The commitments are those of the plan
# itinerary given in the input (Elec_total, Elec_flex_down,
# Elec_flex_up). The prices are the ones given in the input: past
# i_end_control they are a forecast made by the caller.
# The flexibility prices are returned as their two halves, the
# commitment price and the execution price, together with the
# activation probability of each leg, because the reward values the
# certain commitment and the conditional execution separately.
# The revenue discount counts the hours from the decision instant,
# the market interval that contains i0, to each valued interval.
# -------------------------------------------------------------
# Inputs
#   checked    : Named list, as returned by validate_inputs().
#   parameters : Named list. Uses reward$Revenue_discount_per_hour.
# -------------------------------------------------------------
# Outputs
# Named list, with one value per valued interval in each vector:
#   market_utc                     : POSIXct. Start of each interval.
#   E_orig_base_by_market          : energy already committed (kWh).
#   E_orig_expflex_down_by_market  : down-flexibility already sold.
#   E_orig_expflex_up_by_market    : up-flexibility already sold.
#   P_import_buy_by_market, P_import_sell_by_market,
#   P_export_buy_by_market, P_export_sell_by_market :
#                                    energy prices (EUR/kWh).
#   distribution_rate_by_market    : distribution rate (EUR/kWh).
#   p_down_com_buy_by_market, p_down_com_sell_by_market,
#   p_up_com_buy_by_market, p_up_com_sell_by_market,
#   p_down_exec_buy_by_market, p_down_exec_sell_by_market,
#   p_up_exec_buy_by_market, p_up_exec_sell_by_market :
#                                    commitment and execution halves.
#   flex_probab_down_by_market, flex_probab_up_by_market :
#                                    activation probabilities (0-1).
#   revenue_discount_by_market     : revenue discount factor.
#   revenue_discount_per_hour      : the rate of those factors (%).
#   discount_origin_time           : POSIXct. The decision instant.
# -------------------------------------------------------------
# Code outline
# 1. Valued intervals
# 2. Commitments before this market
# 3. Prices of this market
# 4. Revenue discount factors
# -------------------------------------------------------------
# Usage instructions
# marginal_context <- resolve_marginal_context(checked, parameters)
# -------------------------------------------------------------
# Where this function/script is used
#   - optimize_market(): once per call, before run_market_process().
# -------------------------------------------------------------
# functions/scripts called
#   - revenue_discount_factor(): builds the revenue discount factor of
#     each valued interval
# -------------------------------------------------------------

resolve_marginal_context <- function(checked,
                                     parameters
                                     ) {

  # -------------------------------------------------------------
  # 1. Valued intervals
  # -------------------------------------------------------------
  {
    valued <- checked$slot_time >= checked$market$i_begin_horizon &
              checked$slot_time <  checked$market$i_end_horizon
    market_utc <- checked$slot_time[valued]
    prices     <- checked$prices[valued, , drop = FALSE]
    plan       <- checked$itineraries$plan[valued, , drop = FALSE]
  }

  # -------------------------------------------------------------
  # 2. Commitments before this market
  # -------------------------------------------------------------
  {
    E_orig_base_by_market         <- plan$Elec_total
    E_orig_expflex_down_by_market <- plan$Elec_flex_down
    E_orig_expflex_up_by_market   <- plan$Elec_flex_up
  }

  # -------------------------------------------------------------
  # 3. Prices of this market
  # -------------------------------------------------------------
  {
    flex_probab_down_by_market <- prices$Flex_Probab_down
    flex_probab_up_by_market   <- prices$Flex_Probab_up

    p_down_com_buy_by_market   <- prices$Flex_unit_cost_down_com_buy
    p_down_com_sell_by_market  <- prices$Flex_unit_cost_down_com_sell
    p_up_com_buy_by_market     <- prices$Flex_unit_cost_up_com_buy
    p_up_com_sell_by_market    <- prices$Flex_unit_cost_up_com_sell
    p_down_exec_buy_by_market  <- prices$Flex_unit_cost_down_exec_buy
    p_down_exec_sell_by_market <- prices$Flex_unit_cost_down_exec_sell
    p_up_exec_buy_by_market    <- prices$Flex_unit_cost_up_exec_buy
    p_up_exec_sell_by_market   <- prices$Flex_unit_cost_up_exec_sell
  }

  # -------------------------------------------------------------
  # 4. Revenue discount factors
  # -------------------------------------------------------------
  {
    discount_origin_time      <- checked$market$i0
    revenue_discount_per_hour <- parameters$reward$Revenue_discount_per_hour

    # revenue_discount_factor is called to turn the hourly rate into
    # one factor per valued interval.
    revenue_discount_by_market <- revenue_discount_factor(
      target_time       = market_utc,
      origin_time       = discount_origin_time,
      discount_per_hour = revenue_discount_per_hour
    )
  }

  marginal_context <- list(
    market_utc                    = market_utc,
    E_orig_base_by_market         = E_orig_base_by_market,
    E_orig_expflex_down_by_market = E_orig_expflex_down_by_market,
    E_orig_expflex_up_by_market   = E_orig_expflex_up_by_market,
    P_import_buy_by_market        = prices$Elec_unit_cost_import_buy,
    P_import_sell_by_market       = prices$Elec_unit_cost_import_sell,
    P_export_buy_by_market        = prices$Elec_unit_cost_export_buy,
    P_export_sell_by_market       = prices$Elec_unit_cost_export_sell,
    distribution_rate_by_market   = prices$Elec_unit_cost_distribution,
    p_down_com_buy_by_market      = p_down_com_buy_by_market,
    p_down_com_sell_by_market     = p_down_com_sell_by_market,
    p_up_com_buy_by_market        = p_up_com_buy_by_market,
    p_up_com_sell_by_market       = p_up_com_sell_by_market,
    p_down_exec_buy_by_market     = p_down_exec_buy_by_market,
    p_down_exec_sell_by_market    = p_down_exec_sell_by_market,
    p_up_exec_buy_by_market       = p_up_exec_buy_by_market,
    p_up_exec_sell_by_market      = p_up_exec_sell_by_market,
    flex_probab_down_by_market    = flex_probab_down_by_market,
    flex_probab_up_by_market      = flex_probab_up_by_market,
    revenue_discount_by_market    = revenue_discount_by_market,
    revenue_discount_per_hour     = revenue_discount_per_hour,
    discount_origin_time          = discount_origin_time
  )

  rm(valued, market_utc, prices, plan,
     E_orig_base_by_market, E_orig_expflex_down_by_market, E_orig_expflex_up_by_market,
     p_down_com_buy_by_market, p_down_com_sell_by_market,
     p_up_com_buy_by_market, p_up_com_sell_by_market,
     p_down_exec_buy_by_market, p_down_exec_sell_by_market,
     p_up_exec_buy_by_market, p_up_exec_sell_by_market,
     flex_probab_down_by_market, flex_probab_up_by_market,
     revenue_discount_by_market, revenue_discount_per_hour,
     discount_origin_time)

  return(marginal_context)
}
