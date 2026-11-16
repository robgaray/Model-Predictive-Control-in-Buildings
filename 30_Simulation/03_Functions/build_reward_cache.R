# -------------------------------------------------------------
# Function: build_reward_cache.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Resolves the parts of the reward that depend on the plan only,
# and not on the flexibility windows a candidate places:
#   - the revenue discount factors, per market interval and per row;
#   - the target market interval of each row;
#   - the marginal cost of the plan's energy and of its
#     distribution;
#   - when an asset stores energy, the value of the energy the plan
#     leaves stored.
# They are all economic terms, read from the rows of
# system_energy_rows(): the net electricity of the system, the
# market interval of each row and the change of the energy the
# assets store.
# The search for flexibility windows of evaluate_control() values
# many candidates over the same plan, and each candidate only
# changes the itinerary of the leg being searched. With fixed_leg,
# the terms of the other leg are resolved here too, once, for the
# whole search of that leg, together with the feasibility of its
# windows for each asset (the operation window_feasible of the type
# of model of the asset; flex_window_is_feasible() for a building),
# which is a check of the asset, not of the system.
# reward_function() and economic_terms() read every value from
# this list, and reward_function() builds it itself when no caller
# hands one in, so the values are the same whichever way they are
# obtained.
# -------------------------------------------------------------
# Inputs
#   piece            : The piece of the planning period. The economic
#                      terms read only its table of the system, with
#                      the columns system_energy_rows() reads. With
#                      fixed_leg, each asset is judged in its view.
#   parameters       : Named list. Model parameters:
#                      parameters$assets, the asset registry, which
#                      says what the assets store, and, when
#                      fixed_leg is given, parameters$joined_cols,
#                      the order of the view of each asset, and what
#                      the operation window_feasible of each asset
#                      reads.
#   marginal_context : Named list, as returned by
#                      resolve_marginal_context(). Mandatory.
#   fixed_leg        : Character or NULL. "down" or "up": the leg
#                      whose itinerary stays as it is in
#                      the piece for every candidate valued with
#                      this list. NULL when no leg is fixed.
#   stored_energy    : Optional. The change of the energy the assets
#                      store in the itineraries of this piece, as
#                      system_stored_energy() gives it (NULL when no
#                      asset stores energy). A caller that needs it
#                      too resolves it once and hands it in; when it
#                      is not given, it is resolved here.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     - discount_by_market : numeric vector, per target interval
#     - discount_row       : numeric vector, per row
#     - slot_index         : factor, target interval of each row
#     - Elec_Cost_total    : numeric scalar (EUR)
#     - Elec_Cost_distribution_total : numeric scalar (EUR)
#     - stored_value_plan  : numeric scalar (EUR). Only when an asset
#                            stores energy: the value of the energy
#                            the plan leaves stored
#                            (compute_stored_energy_value(), at
#                            marginal_context$stored_energy_price).
#     - fixed_leg          : as given
#     - fixed_terms        : NULL, or the terms of the fixed leg as
#                            returned by flex_leg_reward_terms(),
#                            plus "feasible": a logical vector named
#                            by asset id, the answer of the operation
#                            window_feasible of each asset
# -------------------------------------------------------------
# Code outline
# 1. Rows of the system
# 2. Revenue discount factors
# 3. Target interval of each row
# 4. Marginal cost of the plan's energy and distribution
# 4.1. Value of the energy the plan leaves stored
# 5. Terms of the fixed leg
# -------------------------------------------------------------
# Usage instructions
# cache <- build_reward_cache(piece, parameters,
#                             marginal_context, fixed_leg = "up")
# cache <- build_reward_cache(piece, parameters,
#                             marginal_context, fixed_leg = NULL,
#                             stored_energy = stored_energy)
# -------------------------------------------------------------
build_reward_cache <- function(piece,
                               parameters,
                               marginal_context,
                               fixed_leg,
                               stored_energy
                               ) {

  # -------------------------------------------------------------
  # 1. Rows of the system
  # The economic terms below read only the market interval, the net
  # electricity of the system and the change of the stored energy of
  # each row.
  # -------------------------------------------------------------
  {
    if (missing(stored_energy)) {
      # system_stored_energy is called to add the change of the energy
      # that the assets store, when the caller did not hand it in. It
      # is NULL when no asset stores energy.
      stored_energy <- system_stored_energy(
        piece      = piece,
        parameters = parameters
      )
    }

    # system_energy_rows is called to take from the table of the system
    # the rows the economic side values.
    system_rows <- system_energy_rows(
      period_chunk  = piece$system,
      stored_energy = stored_energy
    )
  }

  # -------------------------------------------------------------
  # 2. Revenue discount factors
  # The factors of the market's own target intervals are resolved
  # once per optimization by resolve_marginal_context() and travel
  # in the context, so they are read rather than recomputed here.
  # The per-row factors are the ones the Recovery Phase term needs
  # for the rows that fall beyond the market's horizon, where it
  # also reads the prices of the rows themselves. They are built from
  # the same origin and the same rate, so a row inside the horizon
  # gets exactly the factor its interval already carries.
  # -------------------------------------------------------------
  {
    if (is.null(marginal_context$revenue_discount_by_market) ||
        is.null(marginal_context$discount_origin_time) ||
        is.null(marginal_context$revenue_discount_per_hour)) {
      stop("reward_function: marginal_context carries no revenue discount. ",
           "revenue_discount_by_market, revenue_discount_per_hour and ",
           "discount_origin_time are resolved by resolve_marginal_context() ",
           "and have no default here - a missing one means the context was ",
           "built by something else, not that the discount should be ",
           "skipped.")
    }
    discount_by_market <- marginal_context$revenue_discount_by_market

    # revenue_discount_factor() is called to extend the same discount
    # to every row of the piece, on the row's own market
    # interval.
    discount_row <- revenue_discount_factor(
      target_time       = system_rows$MarketUTC,
      origin_time       = marginal_context$discount_origin_time,
      discount_per_hour = marginal_context$revenue_discount_per_hour
    )
  }

  # -------------------------------------------------------------
  # 3. Target interval of each row
  # Every economic term aggregates a series per target interval, on
  # the same rows and the same intervals, so the index is resolved
  # once and handed to each of them.
  # -------------------------------------------------------------
  {
    # market_slot_index is called to say which target interval of
    # the market each row belongs to.
    slot_index <- market_slot_index(
      candidate_market_utc = system_rows$MarketUTC,
      market_utc           = marginal_context$market_utc
    )
  }

  # -------------------------------------------------------------
  # 4. Marginal cost of the plan's energy and distribution
  # The whole horizon's base-energy commitment is aggregated per
  # market interval and valued at its marginal (differential) cost
  # relative to marginal_context's baseline, at the current market's
  # prices. The distribution cost applies to the base energy only,
  # never to flexibility.
  # -------------------------------------------------------------
  {
    # compute_marginal_energy_cost is called to value the plan's
    # energy against the energy already committed. The plan's energy
    # is the net electricity of the system.
    Elec_Cost_total <- compute_marginal_energy_cost(
      E_candidate             = system_rows$net_energy$plan,
      slot_index              = slot_index,
      E_orig_by_market        = marginal_context$E_orig_base_by_market,
      P_import_buy_by_market  = marginal_context$P_import_buy_by_market,
      P_import_sell_by_market = marginal_context$P_import_sell_by_market,
      P_export_buy_by_market  = marginal_context$P_export_buy_by_market,
      P_export_sell_by_market = marginal_context$P_export_sell_by_market,
      discount_by_market      = discount_by_market
    )

    # compute_marginal_distribution_cost is called to value the
    # distribution of the same energy.
    Elec_Cost_distribution_total <- compute_marginal_distribution_cost(
      E_candidate                 = system_rows$net_energy$plan,
      slot_index                  = slot_index,
      E_orig_gross_by_market      = marginal_context$E_orig_gross_by_market,
      distribution_rate_by_market = marginal_context$distribution_rate_by_market,
      discount_by_market          = discount_by_market
    )
  }

  # -------------------------------------------------------------
  # 4.1. Value of the energy the plan leaves stored
  # The energy the assets store in the plan is valued at the mean
  # price at which the market buys energy over its horizon, with the
  # weight 1 of the plan on every row. The value is only resolved
  # when an asset stores energy.
  # -------------------------------------------------------------
  {
    if (!is.null(stored_energy)) {
      # compute_stored_energy_value is called to value the energy the
      # plan leaves stored.
      stored_value_plan <- compute_stored_energy_value(
        stored_change = stored_energy$plan,
        probability   = rep(1, length(stored_energy$plan)),
        price         = marginal_context$stored_energy_price
      )
    }
  }

  # -------------------------------------------------------------
  # 5. Terms of the fixed leg
  # Valid for every candidate that leaves this leg's itinerary as
  # it is in the piece, which is what the search of the other
  # leg does. They are resolved on the list built so far, before
  # the leg is marked as fixed.
  # -------------------------------------------------------------
  {
    reward_cache <- list(
      discount_by_market           = discount_by_market,
      discount_row                 = discount_row,
      slot_index                   = slot_index,
      Elec_Cost_total              = Elec_Cost_total,
      Elec_Cost_distribution_total = Elec_Cost_distribution_total,
      fixed_leg                    = NULL,
      fixed_terms                  = NULL
    )

    if (!is.null(stored_energy)) {
      reward_cache$stored_value_plan <- stored_value_plan
      rm(list = "stored_value_plan")
    }

    if (!is.null(fixed_leg)) {
      # flex_leg_reward_terms is called to value the fixed leg once,
      # over the rows of the system.
      fixed_terms <- flex_leg_reward_terms(
        system_rows      = system_rows,
        leg              = fixed_leg,
        marginal_context = marginal_context,
        reward_cache     = reward_cache
      )

      # Whether the windows of the fixed leg are a service each asset
      # can render, one answer per asset, named by its asset id.
      fixed_terms$feasible <- vapply(
        names(parameters$assets),
        function(one_asset_id) {
          asset <- parameters$assets[[one_asset_id]]

          # model_type_contract is called to take the operations of
          # the type of model of the asset.
          model <- model_type_contract(asset$asset_type)

          # piece_asset_view is called to take the table of the asset
          # joined with that of the system, which the asset judges.
          view <- piece_asset_view(
            piece        = piece,
            asset_id     = one_asset_id,
            column_order = parameters$joined_cols
          )

          # The operation window_feasible of the model
          # (flex_window_is_feasible() for a building) is called to
          # judge, over the view of the asset, the windows of the fixed
          # leg by the technical rules of the asset.
          return(model$window_feasible(
            period_chunk = view,
            leg          = fixed_leg,
            parameters   = parameters,
            asset        = asset
          ))
        },
        logical(1)
      )

      reward_cache$fixed_leg   <- fixed_leg
      reward_cache$fixed_terms <- fixed_terms
      rm(list = "fixed_terms")
    }
    rm(list = c("system_rows", "stored_energy"))
  }

  return(reward_cache)
}
