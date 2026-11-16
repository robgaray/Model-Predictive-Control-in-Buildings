# -------------------------------------------------------------
# Function: flex_commitment_profile.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Draws the heating and cooling of the Commitment Phase of one
# flexibility window of a building, for the downward or the upward
# leg, and the margin data of the building on the rows of the guard
# zone. This is the part of a window where the two legs differ: the
# phases are fixed by the system, system_flex_window(), and the
# simulation and the checks of the building are shared by
# flex_evaluation().
# -------------------------------------------------------------
# The downward profile
# Heating and cooling are both reduced. With Q_r the planned heat of
# row r and f the flexibility fraction of the row:
#
#   Q_flex_down_r = max( 0, Q_r * (1 - f) )
#
# The max() clips at 0 from below.
# -------------------------------------------------------------
# The upward profile
# The system that provides the window, s, is raised towards its
# maximum power, and the other system, s', is switched off. With P_max_s
# the power that bounds the window (flex_up_power_limit()) and dt_r the
# timestep of the row in hours:
#
#   Q_s_flex_up_r  = min( P_max_s * dt_r,
#                         Q_s_r + f * (P_max_s * dt_r - Q_s_r) )
#   Q_s'_flex_up_r = 0
#
# It is the mirror of the downward expression: the min() clips at the
# physical maximum power. With f = 1 it reduces to P_max_s * dt_r
# unless the plan was already at, or above, the maximum power.
# -------------------------------------------------------------
# The commitment margin
# The profile above is the physical side of the window, as drawn
# before the commitment margin. Its commercial shaping is not decided
# here: the margin is one, of the set of assets that contribute to
# the window, and the system applies it (system_commitment_margin())
# on the rows of the guard zone, where it keeps
# flexibility_commitment_margin of net electricity unused against the
# limit of the set, and brings back to the plan the market slots of a
# new window that would sell less than minimum_flexibility. The
# profile with the margin is then put together by
# flex_margined_profile(). The other rows of a restated window are
# drawn as the plan allows, without the margin.
# What the building hands the system for it is its margin data
# (building_margin_data()), with the heat at the limit of the leg:
#   - upward, the maximum power of the system that provides the
#     window, the ceiling the window is built against, and nothing of
#     the other system;
#   - downward, no heat at all, with both systems off.
# The electricity of the margin data is measured at the outdoor
# temperature the itinerary is simulated with, the forecast
# (Text_forec), so that what the band computes is what the simulation
# gives.
# -------------------------------------------------------------
# Inputs
#   leg            : Character scalar, "down" or "up".
#   period_chunk   : Data frame. Holds the rows of the window. Reads
#                    the columns Q_heat_plan, Q_cool_plan and
#                    Text_forec.
#   flex_rows      : Integer vector. The rows of period_chunk in the
#                    Commitment Phase.
#   delta_t_h_flex : Numeric vector. The timestep of each of those
#                    rows, in hours.
#   guard_row      : Logical vector. TRUE for each of those rows that
#                    is in the guard zone.
#   fraction_row   : Numeric vector. The flexibility fraction of each
#                    of those rows, in (0, 1].
#   hvac_used      : Character scalar, "heat" or "cool": the system of
#                    an upward window, from resolve_flex_up_hvac(). Not
#                    read on the downward leg.
#   parameters     : Named list. Reads what flex_up_power_limit()
#                    reads.
#   asset          : Named list. The parameters of the building, its
#                    entry of parameters$assets. Read by
#                    flex_up_power_limit() and building_margin_data().
# -------------------------------------------------------------
# Outputs
#   Named list with:
#     Q_heat : numeric vector, one entry per row of flex_rows, the
#              heating (kWh) of the itinerary over the Commitment
#              Phase, before the margin
#     Q_cool : the same for cooling
#     margin : the margin data of the building on the rows of the
#              guard zone, as building_margin_data() gives it, or
#              NULL when no row is in the guard zone
# -------------------------------------------------------------
# Code outline
# 1. Downward profile
# 2. Upward profile
#   2.1. Raise the system towards its maximum power
#   2.2. The margin data of the building
# -------------------------------------------------------------
# Usage instructions
# profile <- flex_commitment_profile(
#   leg            = "down",
#   period_chunk   = period_chunk,
#   flex_rows      = flex_rows,
#   delta_t_h_flex = delta_t_h_flex,
#   guard_row      = guard_row,
#   fraction_row   = fraction_row,
#   hvac_used      = NULL,
#   parameters     = parameters,
#   asset          = asset
# )
# -------------------------------------------------------------
flex_commitment_profile <- function(leg,
                                    period_chunk,
                                    flex_rows,
                                    delta_t_h_flex,
                                    guard_row,
                                    fraction_row,
                                    hvac_used,
                                    parameters,
                                    asset) {

  # -------------------------------------------------------------
  # 1. Downward profile
  # Heating and cooling reduced by the fraction of every row, and never
  # below zero; and, on the rows of the guard zone, the margin data of
  # the building, whose floor is no heat at all.
  # -------------------------------------------------------------
  if (leg == "down") {
    Q_heat_plan_flex_down <- pmax(
      0,
      period_chunk$Q_heat_plan[flex_rows] * (1 - fraction_row)
    )
    Q_cool_plan_flex_down <- pmax(
      0,
      period_chunk$Q_cool_plan[flex_rows] * (1 - fraction_row)
    )

    margin <- NULL
    if (any(guard_row)) {
      margin_rows <- flex_rows[guard_row]
      no_heat     <- numeric(length(margin_rows))
      # building_margin_data is called to hand the system the heat of
      # the plan and of the itinerary on the rows of the guard zone,
      # and the electricity of the building at its floor.
      margin <- building_margin_data(
        Q_heat_flex  = Q_heat_plan_flex_down[guard_row],
        Q_heat_plan  = period_chunk$Q_heat_plan[margin_rows],
        Q_cool_flex  = Q_cool_plan_flex_down[guard_row],
        Q_cool_plan  = period_chunk$Q_cool_plan[margin_rows],
        Q_heat_limit = no_heat,
        Q_cool_limit = no_heat,
        Text         = period_chunk$Text_forec[margin_rows],
        delta_t_h    = delta_t_h_flex[guard_row],
        asset        = asset
      )
      rm(list = c("margin_rows", "no_heat"))
    }

    return(list(Q_heat = Q_heat_plan_flex_down,
                Q_cool = Q_cool_plan_flex_down,
                margin = margin))
  }

  # -------------------------------------------------------------
  # 2. Upward profile
  # The selected system raised towards its maximum power, the other
  # one switched off.
  # Sub-blocks:
  #   2.1. Raise the system towards its maximum power
  #   2.2. The margin data of the building
  # -------------------------------------------------------------

  # -------------------------------------------------------------
  # 2.1. Raise the system towards its maximum power
  # By the fraction of every row, and never above the physical maximum
  # power of the system.
  # -------------------------------------------------------------
  {
    # flex_up_power_limit is called for the heat power the selected
    # system may be raised to, the same bound a standing window is
    # held under when it cannot be rebuilt.
    P_max <- flex_up_power_limit(hvac_used, parameters, asset)

    col_used <- if (hvac_used == "heat") "Q_heat_plan" else "Q_cool_plan"

    Q_used_plan <- period_chunk[[col_used]][flex_rows]
    Q_used_max  <- P_max * delta_t_h_flex

    Q_used_flex_up <- pmin(
      Q_used_max,
      Q_used_plan + fraction_row * (Q_used_max - Q_used_plan)
    )
    rm(list = c("P_max", "col_used", "Q_used_plan"))
  }

  # -------------------------------------------------------------
  # 2.2. The margin data of the building
  # On the rows of the guard zone, the heat of the plan and of the
  # itinerary, with the other system off, and the ceiling the window
  # is built against: the maximum power of the system that provides
  # it, and nothing of the other one.
  # -------------------------------------------------------------
  {
    margin <- NULL
    if (any(guard_row)) {
      n_guard        <- sum(guard_row)
      margin_rows    <- flex_rows[guard_row]
      Q_heat_flex    <- if (hvac_used == "heat") Q_used_flex_up[guard_row] else rep(0, n_guard)
      Q_cool_flex    <- if (hvac_used == "heat") rep(0, n_guard) else Q_used_flex_up[guard_row]
      Q_heat_ceiling <- if (hvac_used == "heat") Q_used_max[guard_row] else rep(0, n_guard)
      Q_cool_ceiling <- if (hvac_used == "heat") rep(0, n_guard) else Q_used_max[guard_row]

      # building_margin_data is called to hand the system the heat of
      # the plan and of the itinerary on the rows of the guard zone,
      # and the electricity of the building at the ceiling of the
      # window.
      margin <- building_margin_data(
        Q_heat_flex  = Q_heat_flex,
        Q_heat_plan  = period_chunk$Q_heat_plan[margin_rows],
        Q_cool_flex  = Q_cool_flex,
        Q_cool_plan  = period_chunk$Q_cool_plan[margin_rows],
        Q_heat_limit = Q_heat_ceiling,
        Q_cool_limit = Q_cool_ceiling,
        Text         = period_chunk$Text_forec[margin_rows],
        delta_t_h    = delta_t_h_flex[guard_row],
        asset        = asset
      )

      rm(list = c("Q_heat_flex", "Q_cool_flex", "Q_heat_ceiling",
                  "Q_cool_ceiling", "margin_rows", "n_guard"))
    }
    rm(list = "Q_used_max")
  }

  Q_off <- numeric(length(flex_rows))
  if (hvac_used == "heat") {
    return(list(Q_heat = Q_used_flex_up, Q_cool = Q_off, margin = margin))
  }
  return(list(Q_heat = Q_off, Q_cool = Q_used_flex_up, margin = margin))
}
