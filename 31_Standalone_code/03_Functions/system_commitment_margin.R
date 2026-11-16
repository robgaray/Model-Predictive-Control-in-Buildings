# -------------------------------------------------------------
# Function: system_commitment_margin.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Applies the commitment margin to a flexibility window of the
# system, over the rows of the guard zone of its Commitment Phase.
# The margin is one, of the set of assets that contribute to the
# window: it is kept by their net electricity, against the limit of
# the set, and not by each asset on its own.
#
# Why the margin exists
# -------------------------------------------------------------
# A window is sold against a concrete itinerary, and every market that
# clears afterwards derives it again. An itinerary pinned at the limit
# of what the assets can draw cannot absorb any change, however small.
# Leaving flexibility_commitment_margin of electricity unused, in
# every market interval, is what gives the next market something to
# work with.
#
# The band of the set
# -------------------------------------------------------------
# Each asset gives, row by row, the electricity it draws at the limit
# of the leg (its margin data): at the ceiling of the window upward,
# at its floor downward. The limit of the set is their sum, and
# commitment_margin_bound() turns it into the band of every market
# interval: upward, the net electricity stays at least the margin
# below the limit of the set; downward, at least the margin above it.
# An asset that does not contribute to the window holds its plan, so
# the plan is its floor and its ceiling in that window. It adds the
# same electricity to the net and to the limit, and is left out of
# both.
#
# How the set is brought inside the band
# -------------------------------------------------------------
# All the assets contribute with the same fraction of flexibility. In
# a market interval whose net leaves the band, the departure of every
# asset from its plan is scaled by one same factor between 0 and 1,
# found by bisection on the net electricity of the interval, with
# flexibility_commitment_bisection_steps halvings. When the plan of
# the set is already outside the band, the interval has no service to
# offer and every asset keeps its plan in it; when the itinerary the
# assets drew is already inside, nothing is scaled.
# With a single asset, the asset fits itself inside the band, through
# the operation margin_fit of its type of model (for a building,
# apply_commitment_margin(), in compiled code). It is the same rule,
# and it is faster.
#
# The minimum flexibility
# -------------------------------------------------------------
# A new window sells, in each market interval, nothing or at least the
# minimum the system gives for the interval (minimum_flexibility times
# the length of the interval). Once the interval is inside the band,
# what it sells is measured in electricity, on the net, with the
# electrical model of each asset (the operation margin_energy of its
# type of model), as the economic chain measures it: the net
# electricity of the itinerary below the plan downward, above it
# upward. An interval that sells something, but less than its
# minimum, is brought back to the plan in every asset and sells
# nothing.
# A window that restates a commitment already sold sells nothing new,
# so the minimum is not applied to it: what an earlier market sold is
# kept, even below the minimum.
# -------------------------------------------------------------
# Inputs
# All the vectors are the same length, one entry per row of the guard
# zone of the Commitment Phase.
#   margins         : Named list, one entry per asset that contributes
#                     to the window, named by its asset_id: its margin
#                     data, as its type of model gives it (for a
#                     building, building_margin_data()). Reads:
#                       - plan and profile: named lists of numeric
#                         vectors, the quantities the asset moves, in
#                         the plan and in the itinerary it drew before
#                         the margin
#                       - limit_energy: numeric vector, the electricity
#                         (kWh) of each row at the limit of the leg
#                     The rest is read by the operations of the asset.
#   market_slot     : Vector. The market interval each row belongs to.
#   delta_t_h       : Numeric vector. Timestep of each row in hours.
#   leg             : Character, "up" or "down".
#   enforce_minimum : Logical scalar. TRUE for a new window, whose
#                     intervals must sell nothing or at least their
#                     minimum; FALSE for a window that restates a
#                     commitment already sold.
#   parameters      : Named list. Reads:
#                     - parameters$assets, the asset registry, whose
#                       entries are handed to the operations of their
#                       types of model
#                     - parameters$control$
#                       flexibility_commitment_bisection_steps
#                     - parameters$computing$flex_energy_tol (kWh),
#                       the energy below which an interval sells
#                       nothing
#                     - what commitment_margin_bound() reads
# -------------------------------------------------------------
# Outputs
#   Named list, one entry per entry of margins, with the same names:
#   the quantities the asset moves after the margin, a named list of
#   numeric vectors in the shape of its profile (for a building,
#   list(Q_heat, Q_cool)). An interval that has no service to offer,
#   or that would sell less than its minimum, comes back equal to the
#   plan in every asset.
# -------------------------------------------------------------
# Code outline
# 1. The band of the set
# 2. Bring the set inside the band
#   2.1. A single asset
#   2.2. Several assets, with one factor
# 3. Bring back to the plan the intervals below their minimum
# -------------------------------------------------------------
# Usage instructions
# margined <- system_commitment_margin(
#   margins         = list(Building_001 = margin),
#   market_slot     = market_slot,
#   delta_t_h       = delta_t_h,
#   leg             = "down",
#   enforce_minimum = TRUE,
#   parameters      = parameters
# )
# margined$Building_001$Q_heat
# -------------------------------------------------------------

system_commitment_margin <- function(margins,
                                     market_slot,
                                     delta_t_h,
                                     leg,
                                     enforce_minimum,
                                     parameters) {

  # -------------------------------------------------------------
  # 1. The band of the set
  # The limit of the set is the sum, row by row, of the limits of its
  # assets. With a single asset it is the limit of that asset.
  # -------------------------------------------------------------
  {
    if (!is.list(margins) || length(margins) == 0 ||
        is.null(names(margins)) ||
        !all(names(margins) %in% names(parameters$assets))) {
      stop("system_commitment_margin: margins must be a list named by ",
           "the asset_id of assets of the asset registry")
    }

    asset_ids    <- names(margins)
    limit_energy <- Reduce(`+`, lapply(margins, `[[`, "limit_energy"))

    # commitment_margin_bound is called to number the market intervals
    # and to give the net electricity the set may reach in each of
    # them, from energy alone.
    band <- commitment_margin_bound(
      limit_energy = limit_energy,
      market_slot  = market_slot,
      delta_t_h    = delta_t_h,
      leg          = leg,
      parameters   = parameters
    )

    # model_type_contract is called for the operations of the type of
    # model of each asset, through which its electricity is measured
    # and its quantities fitted.
    models <- lapply(asset_ids, function(one_id) {
      model_type_contract(parameters$assets[[one_id]]$asset_type)
    })
    names(models) <- asset_ids

    rm(list = "limit_energy")
  }

  # -------------------------------------------------------------
  # 2. Bring the set inside the band
  # Sub-blocks:
  #   2.1. A single asset
  #   2.2. Several assets, with one factor
  # -------------------------------------------------------------

  # -------------------------------------------------------------
  # 2.1. A single asset
  # The asset fits its own itinerary inside the band of the set, which
  # is then its own band.
  # -------------------------------------------------------------
  {
    if (length(asset_ids) == 1) {
      # The operation margin_fit of the model
      # (apply_commitment_margin() for a building) is called to fit
      # the itinerary of the asset inside the band.
      margined <- list(models[[1]]$margin_fit(
        margin     = margins[[1]],
        band       = band,
        leg        = leg,
        parameters = parameters,
        asset      = parameters$assets[[asset_ids]]
      ))
      names(margined) <- asset_ids
    }
  }

  # -------------------------------------------------------------
  # 2.2. Several assets, with one factor
  # In each market interval, the departure of every asset from its
  # plan is scaled by the same factor. A row whose interval is missing
  # belongs to no interval and keeps the itinerary as drawn. The
  # intervals do not depend on each other, so the bisection runs on
  # all of them at once.
  # -------------------------------------------------------------
  {
    if (length(asset_ids) > 1) {
      n_slots <- length(band$bound)

      # The quantities of one asset at a factor per row: the plan at
      # 0, the itinerary as drawn at 1.
      scaled <- function(margin, factor_row) {
        out <- margin$profile
        for (CONT_001 in names(out)) {
          plan    <- margin$plan[[CONT_001]]
          profile <- margin$profile[[CONT_001]]
          out[[CONT_001]] <- ifelse(
            factor_row == 1, profile,
            ifelse(factor_row == 0, plan,
                   plan + factor_row * (profile - plan)))
        }
        return(out)
      }

      # The net electricity of each interval at a factor per interval.
      net_by_slot <- function(factor_slot) {
        factor_row <- c(1, factor_slot)[band$slot_id + 1L]
        # The operation margin_energy of the model of each asset
        # (building_margin_energy() for a building) is called for the
        # electricity of its quantities at that factor.
        net <- Reduce(`+`, lapply(asset_ids, function(one_id) {
          models[[one_id]]$margin_energy(
            margin  = margins[[one_id]],
            control = scaled(margins[[one_id]], factor_row),
            asset   = parameters$assets[[one_id]]
          )
        }))
        return(vapply(seq_len(n_slots), function(one_slot) {
          sum(net[band$slot_id == one_slot], na.rm = TRUE)
        }, numeric(1)))
      }

      # Upward the net of an interval must stay at or below its bound;
      # downward, at or above it. A comparison that cannot be made
      # counts as outside.
      inside <- function(value) {
        result <- if (identical(leg, "up")) {
          value <= band$bound
        } else {
          value >= band$bound
        }
        return(result & !is.na(result))
      }

      plan_inside <- inside(net_by_slot(rep(0, n_slots)))
      flex_inside <- inside(net_by_slot(rep(1, n_slots)))
      searched    <- plan_inside & !flex_inside
      settled     <- ifelse(plan_inside, 1, 0)

      # low is the deepest factor tested that stays inside the band,
      # high the shallowest that does not.
      low   <- rep(0, n_slots)
      high  <- rep(1, n_slots)
      steps <- parameters$control$flexibility_commitment_bisection_steps
      if (any(searched)) {
        for (CONT_002 in seq_len(steps)) {
          middle <- (low + high) / 2
          kept   <- inside(net_by_slot(ifelse(searched, middle, settled)))
          low[searched & kept]   <- middle[searched & kept]
          high[searched & !kept] <- middle[searched & !kept]
        }
        rm(list = c("CONT_002", "middle", "kept"))
      }

      factor_row <- c(1, ifelse(searched, low, settled))[band$slot_id + 1L]
      margined   <- lapply(margins, scaled, factor_row = factor_row)

      rm(list = c("n_slots", "scaled", "net_by_slot", "inside", "plan_inside",
                  "flex_inside", "searched", "settled", "low", "high", "steps",
                  "factor_row"))
    }
  }

  # -------------------------------------------------------------
  # 3. Bring back to the plan the intervals below their minimum
  # Only for a new window, and only when the minimum is above zero:
  # with a minimum of zero no interval can sell less than it. What an
  # interval sells is read on the net, as system_flex_commitment()
  # reads it: downward, the net of the plan less the net of the
  # itinerary; upward, the net of the itinerary less the net of the
  # plan, bounded at 0 from below.
  # -------------------------------------------------------------
  {
    if (isTRUE(enforce_minimum) && any(band$minimum > 0)) {
      # The operation margin_energy of the model of each asset
      # (building_margin_energy() for a building) is called for the
      # electricity of its plan and of its itinerary after the margin;
      # the net is their sum over the assets.
      net_plan <- Reduce(`+`, lapply(asset_ids, function(one_id) {
        models[[one_id]]$margin_energy(
          margin  = margins[[one_id]],
          control = margins[[one_id]]$plan,
          asset   = parameters$assets[[one_id]]
        )
      }))
      net_flex <- Reduce(`+`, lapply(asset_ids, function(one_id) {
        models[[one_id]]$margin_energy(
          margin  = margins[[one_id]],
          control = margined[[one_id]],
          asset   = parameters$assets[[one_id]]
        )
      }))
      committed_row <- if (identical(leg, "up")) {
        pmax(net_flex - net_plan, 0)
      } else {
        net_plan - net_flex
      }

      tol_energy <- parameters$computing$flex_energy_tol
      for (CONT_003 in seq_along(band$minimum)) {
        rows      <- which(band$slot_id == CONT_003)
        committed <- sum(committed_row[rows], na.rm = TRUE)
        if (committed > tol_energy &&
            committed < band$minimum[CONT_003] - tol_energy) {
          for (CONT_004 in asset_ids) {
            for (CONT_005 in names(margined[[CONT_004]])) {
              margined[[CONT_004]][[CONT_005]][rows] <-
                margins[[CONT_004]]$plan[[CONT_005]][rows]
            }
          }
        }
      }

      rm(list = intersect(
        c("net_plan", "net_flex", "committed_row", "tol_energy",
          "CONT_003", "rows", "committed", "CONT_004", "CONT_005"),
        ls()
      ))
    }

    rm(list = c("band", "models", "asset_ids"))
  }

  return(margined)
}
