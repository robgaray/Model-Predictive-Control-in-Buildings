# -------------------------------------------------------------
# Function: flex_leg_reward_terms.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Computes, for one flexibility leg ("down" or "up"), the terms
# that leg adds to the economic part of the reward
# (economic_terms()):
#   - its commitment signal: the energy the leg commits during its
#     Commitment Phase, as a non-negative series;
#   - the commitment revenue: that signal valued at the
#     commitment price alone;
#   - the execution revenue: the same signal valued at the
#     execution price times the activation probability;
#   - the Recovery Phase cost: the energy the building would move
#     while returning to its plan if the service were called.
#     economic_terms() values it as the change against the
#     cost of the itineraries already committed
#     (committed_recovery_cost());
#   - when an asset stores energy, the value of the energy the leg
#     leaves stored against the plan: the difference between the
#     change of the stored energy of the leg and that of the plan,
#     weighted by the activation probability of the leg on each row
#     and valued at the price of the stored energy
#     (compute_stored_energy_value()). If the service were called
#     and the Recovery Phase did not bring the stored energy back,
#     the leg would leave that energy stored or spent. economic_terms()
#     values it as the change against what the committed itineraries
#     leave (committed_recovery_cost()).
# It is part of the system side of the reward: it reads only the
# rows of system_energy_rows(), that is the net electricity of the
# system in each itinerary, the phases of the legs, the prices and
# the probabilities, never a temperature, a mode or a setpoint.
# The two legs are independent: each term reads only the rows of
# its own leg and the plan, so a caller that keeps one leg fixed
# can compute its terms once and reuse them.
# -------------------------------------------------------------
# Inputs
#   system_rows        : Named list, as returned by
#                        system_energy_rows(). Its market interval,
#                        its net electricity of the plan and of
#                        this leg's itinerary, its phase, its row
#                        prices and its activation probability of
#                        this leg are used, and, when it holds it,
#                        the change of the stored energy of the plan
#                        and of this leg.
#   leg                : Character. "down" or "up".
#   marginal_context   : Named list, as returned by
#                        resolve_marginal_context(). Its activation
#                        probability of the leg by market interval
#                        and its price of the stored energy are used
#                        for the value of the stored energy.
#   reward_cache       : Named list, as returned by
#                        build_reward_cache(). Its revenue discount
#                        factors (per target interval and per row)
#                        and its target interval of each row are
#                        used. When its fixed_leg is this leg, its
#                        fixed_terms are returned as they are.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     - commitment    : numeric vector, one value per row
#     - com_revenue   : numeric scalar (EUR)
#     - exec_revenue  : numeric scalar (EUR)
#     - recovery_cost : numeric scalar (EUR)
#     - stored_value  : numeric scalar (EUR). Only when
#                       system_rows holds the change of the stored
#                       energy: the value of the energy the leg
#                       leaves stored against the plan.
# -------------------------------------------------------------
# Code outline
# 0. The fixed leg
# 1. Commitment signal of the leg
# 2. Commitment and execution revenue
# 3. Recovery Phase cost
# 4. Value of the energy the leg leaves stored
# -------------------------------------------------------------
# Usage instructions
# terms <- flex_leg_reward_terms(system_rows, "down", marginal_context,
#                                reward_cache)
# -------------------------------------------------------------
flex_leg_reward_terms <- function(system_rows,
                                  leg,
                                  marginal_context,
                                  reward_cache
                                  ) {

  # -------------------------------------------------------------
  # 0. The fixed leg
  # Its itinerary is the one reward_cache was built on, so its terms
  # are the ones reward_cache already carries.
  # -------------------------------------------------------------
  {
    if (identical(reward_cache$fixed_leg, leg)) {
      return(reward_cache$fixed_terms)
    }
    discount_by_market <- reward_cache$discount_by_market
    discount_row       <- reward_cache$discount_row
    slot_index         <- reward_cache$slot_index
  }

  # -------------------------------------------------------------
  # 1. Commitment signal of the leg
  # The commitment exists only during the Commitment Phase (phase
  # 1). The Neutral and Recovery Phases are a consequence of the
  # event, not a service sold to the grid, so they are not valued,
  # not even with the opposite sign.
  # Downward, the signal is the load the building sheds below its
  # plan. Upward it is the load it adds over its plan, bounded at 0
  # from below: within an accepted window a single row can come out
  # below the plan, because the event switches the non-selected
  # system off and that system may have been running on the backup
  # resistances, at COP 1. Such a row delivers no upward service.
  # value_flex_operation() tells the legs apart by sign, so the
  # upward series and its baseline are passed negated.
  # -------------------------------------------------------------
  {
    if (leg == "down") {
      # The net electricity of the system in the plan and in the
      # downward itinerary differ by the energy the leg sheds.
      commitment <-
        (system_rows$net_energy$plan -
           system_rows$net_energy$plan_flex_down) *
        (system_rows$phase$down == 1)
      E_candidate      <- commitment
      E_orig_by_market <- marginal_context$E_orig_expflex_down_by_market
    } else if (leg == "up") {
      # The net electricity of the system in the upward itinerary
      # and in the plan differ by the energy the leg adds.
      commitment <-
        pmax(system_rows$net_energy$plan_flex_up -
               system_rows$net_energy$plan, 0) *
        (system_rows$phase$up == 1)
      E_candidate      <- -commitment
      E_orig_by_market <- -marginal_context$E_orig_expflex_up_by_market
    } else {
      stop("flex_leg_reward_terms: leg must be 'down' or 'up'")
    }
  }

  # -------------------------------------------------------------
  # 2. Commitment and execution revenue
  # The commitment is paid whether or not the operator ever calls
  # the service, so it is valued at the commitment price alone. The
  # execution is conditional, so it is valued at the execution
  # price weighted by the activation probability of each leg.
  # -------------------------------------------------------------
  {
    # compute_marginal_flex_revenue is called to value the move of
    # this leg's commitment, per target interval, at the commitment
    # prices. After the close of the control horizon the move is
    # capped at the commitment that stands, which no market may change
    # there.
    com_revenue <- compute_marginal_flex_revenue(
      E_candidate               = E_candidate,
      slot_index                = slot_index,
      E_orig_by_market          = E_orig_by_market,
      price_down_sell_by_market = marginal_context$p_down_com_sell_by_market,
      price_down_buy_by_market  = marginal_context$p_down_com_buy_by_market,
      price_up_sell_by_market   = marginal_context$p_up_com_sell_by_market,
      price_up_buy_by_market    = marginal_context$p_up_com_buy_by_market,
      discount_by_market        = discount_by_market,
      capped_by_market          = marginal_context$beyond_control_by_market
    )

    # compute_marginal_flex_revenue is called again to value the
    # same move at the execution prices weighted by the activation
    # probability.
    exec_revenue <- compute_marginal_flex_revenue(
      E_candidate               = E_candidate,
      slot_index                = slot_index,
      E_orig_by_market          = E_orig_by_market,
      price_down_sell_by_market = marginal_context$p_down_exec_sell_by_market *
                                    marginal_context$flex_probab_down_by_market,
      price_down_buy_by_market  = marginal_context$p_down_exec_buy_by_market *
                                    marginal_context$flex_probab_down_by_market,
      price_up_sell_by_market   = marginal_context$p_up_exec_sell_by_market *
                                    marginal_context$flex_probab_up_by_market,
      price_up_buy_by_market    = marginal_context$p_up_exec_buy_by_market *
                                    marginal_context$flex_probab_up_by_market,
      discount_by_market        = discount_by_market,
      capped_by_market          = marginal_context$beyond_control_by_market
    )

    rm(list = c("E_candidate", "E_orig_by_market"))
  }

  # -------------------------------------------------------------
  # 3. Recovery Phase cost
  # The energy the building moves while it recovers is valued over
  # the whole Recovery Phase, including the part that falls beyond
  # the intervals this market trades: it is bought or sold whenever
  # it happens. Those rows are valued at the prices and probability
  # of the rows themselves.
  # -------------------------------------------------------------
  {
    # compute_recovery_energy_cost is called to value the deviation
    # of this leg's itinerary from the plan over its Recovery Phase,
    # weighted by the probability that the service is called. The
    # plan and the itinerary of this leg are the net electricity of
    # the system.
    recovery_cost <- compute_recovery_energy_cost(
      E_plan                  = system_rows$net_energy$plan,
      E_flex                  = system_rows$net_energy[[paste0("plan_flex_", leg)]],
      phase                   = system_rows$phase[[leg]],
      MarketUTC_candidate     = system_rows$MarketUTC,
      market_utc              = marginal_context$market_utc,
      P_import_buy_by_market  = marginal_context$P_import_buy_by_market,
      P_import_sell_by_market = marginal_context$P_import_sell_by_market,
      P_export_buy_by_market  = marginal_context$P_export_buy_by_market,
      P_export_sell_by_market = marginal_context$P_export_sell_by_market,
      probability_by_market   = marginal_context[[paste0("flex_probab_", leg, "_by_market")]],
      P_import_buy_row        = system_rows$price_row$import_buy,
      P_import_sell_row       = system_rows$price_row$import_sell,
      P_export_buy_row        = system_rows$price_row$export_buy,
      P_export_sell_row       = system_rows$price_row$export_sell,
      probability_row         = system_rows$probability_row[[leg]],
      discount_by_market      = discount_by_market,
      discount_row            = discount_row
    )
  }

  # -------------------------------------------------------------
  # 4. Value of the energy the leg leaves stored
  # The change of the stored energy of the leg against the plan is
  # weighted, on each row, by the activation probability of the leg
  # in the target interval of the row: the market's own view where
  # the row has a target interval, and the probability of the row
  # itself where it has none (only the first row, the initial
  # condition, which holds no change), the same rule as the
  # Recovery Phase cost. The value is only resolved when the rows of
  # the system hold the change of the stored energy.
  # -------------------------------------------------------------
  {
    leg_terms <- list(
      commitment    = commitment,
      com_revenue   = com_revenue,
      exec_revenue  = exec_revenue,
      recovery_cost = recovery_cost
    )

    if (!is.null(system_rows$stored_energy)) {
      target_position <- as.integer(slot_index)
      probability     <- system_rows$probability_row[[leg]]
      inside          <- !is.na(target_position)
      probability[inside] <- marginal_context[[
        paste0("flex_probab_", leg, "_by_market")]][target_position[inside]]

      # compute_stored_energy_value is called to value the difference
      # between the stored energy of this leg and that of the plan,
      # weighted by the probability that the service is called.
      leg_terms$stored_value <- compute_stored_energy_value(
        stored_change = system_rows$stored_energy[[paste0("plan_flex_", leg)]] -
                          system_rows$stored_energy$plan,
        probability   = probability,
        price         = marginal_context$stored_energy_price
      )
      rm(list = c("target_position", "probability", "inside"))
    }
  }

  rm(list = c("discount_by_market", "discount_row", "slot_index",
              "commitment", "com_revenue", "exec_revenue",
              "recovery_cost"))

  return(leg_terms)
}
