# -------------------------------------------------------------
# Function: apply_commitment_margin.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Keeps an electrical headroom on a flexibility itinerary, so that a
# later re-optimization still has room to move the operation without
# breaking a commitment that was already sold.
#
# Why the headroom exists
# -------------------------------------------------------------
# A flexibility window is sold against a concrete itinerary. Every
# market that clears afterwards derives that itinerary again, and if
# the new one can no longer sustain what was sold, the run is penalised
# as technically infeasible. The itinerary that leaves no room at all -
# the upward one pinned at the system's limit, the downward one pinned
# at zero - is the one that cannot absorb any change, however small.
# Leaving flexibility_commitment_margin of electricity unused on both
# sides is what gives the next market something to work with.
#
# Where the headroom is measured
# -------------------------------------------------------------
# On the market slot, which is the unit that is traded and settled, and
# not on the individual timestep. A slot meets the rule when the
# electricity its rows add up to stays inside the band; a single step
# may sit at the limit as long as another step of the same slot makes
# up for it.
#
# The two rules
# -------------------------------------------------------------
# Upward: the electricity of the slot must stay below what the system
# would draw at the ceiling the window is built against, by at least
# the margin. When the plan itself is already above that threshold the
# slot has no upward service to offer and its itinerary is left equal
# to the plan.
#
# Downward: the electricity of the slot must stay above the margin.
# When the plan itself is already below it the slot has no downward
# service to offer and its itinerary is left equal to the plan.
#
# How a slot is brought back inside the band
# -------------------------------------------------------------
# By scaling that slot's whole departure from the plan by a single
# factor between 0 and 1, on both systems at once, so the itinerary
# keeps its shape and only its depth changes. The electricity of a step
# is a monotone, piecewise linear function of the heat of that step -
# see elec_from_heat() below, which mirrors period_simulation_cpp.cpp -
# so the electricity of the slot is monotone in the factor and a
# bisection on the closed form finds it without simulating anything.
# -------------------------------------------------------------
# Inputs
# All the vectors are the same length, one entry per row of the
# Commitment Phase, and all the heat quantities are energies in kWh.
# Q_heat_flex    : Numeric vector. Heating of the itinerary the caller
#                  built, before the margin.
# Q_heat_plan    : Numeric vector. Heating of the plan on those rows.
# Q_cool_flex    : Numeric vector. Cooling of the itinerary.
# Q_cool_plan    : Numeric vector. Cooling of the plan.
# Q_heat_ceiling : Numeric vector. Heating the window is built against
#                  at its ceiling, zero when the window does not use
#                  the heating system. Only read when leg is "up".
# Q_cool_ceiling : Numeric vector. The same for cooling.
# market_slot    : Vector. The market slot each row belongs to.
# Text           : Numeric vector. Outdoor temperature, for the COP.
# delta_t_h      : Numeric vector. Timestep in hours.
# leg            : Character, "up" or "down".
# parameters     : Named list. Reads parameters$model for the heat pump
#                  and parameters$control$flexibility_commitment_margin.
# -------------------------------------------------------------
# Outputs
# Named list with two numeric vectors the length of the inputs:
#   Q_heat : heating of the itinerary after the margin
#   Q_cool : cooling of the itinerary after the margin
# A slot that has no service to offer comes back equal to the plan on
# both.
# -------------------------------------------------------------
# Code outline
# 1. The margin, and the electricity of a candidate heat pair.
# 2. One slot at a time, find the deepest factor that meets the rule.
# -------------------------------------------------------------
# Usage instructions
# Called from inside flex_evaluation_up() and flex_evaluation_down(),
# on the rows of the Commitment Phase, right after the heat of the
# itinerary has been imposed and before the phases are marked.
# -------------------------------------------------------------
# Where this function/script is used
#   - flex_evaluation_down()
#   - flex_evaluation_up()
# -------------------------------------------------------------
# functions/scripts called
# None.
# -------------------------------------------------------------

apply_commitment_margin <- function(Q_heat_flex,
                                    Q_heat_plan,
                                    Q_cool_flex,
                                    Q_cool_plan,
                                    Q_heat_ceiling,
                                    Q_cool_ceiling,
                                    market_slot,
                                    Text,
                                    delta_t_h,
                                    leg,
                                    parameters) {

  # -------------------------------------------------------------
  # 1. The margin, and the electricity of a candidate heat pair
  # elec_from_heat() is the same expression period_simulation_cpp.cpp
  # evaluates: the heat pump covers up to its first rated point at the
  # COP of the moment and the backup resistances cover the rest at COP
  # 1, while cooling has a single constant COP. Writing it here in
  # closed form is what lets the margin be met exactly without running
  # the simulation once per attempt.
  # -------------------------------------------------------------

  {
    margin <- parameters$control$flexibility_commitment_margin

    cop_heat <- parameters$model$COP_hp_heat_1_coef1 +
      parameters$model$COP_hp_heat_1_coef2 *
        (Text - parameters$model$Text_ref_hp_heat) +
      parameters$model$COP_hp_heat_1_coef3 *
        (parameters$model$Tsup_hp_heat - parameters$model$Tsup_ref_hp_heat)

    hp_heat_step <- parameters$model$Q_hp_heat_1 * delta_t_h

    elec_from_heat <- function(Q_heat, Q_cool, rows) {
      sum(pmin(Q_heat[rows], hp_heat_step[rows]) / cop_heat[rows] +
            pmax(Q_heat[rows] - hp_heat_step[rows], 0) +
            Q_cool[rows] / parameters$model$COP_hp_cool,
          na.rm = TRUE)
    }
  }

  # -------------------------------------------------------------
  # 2. One slot at a time, find the deepest factor that meets the rule
  # -------------------------------------------------------------

  {
    Q_heat_out <- Q_heat_flex
    Q_cool_out <- Q_cool_flex

    bisection_steps <- 24

    for (CONT_001 in unique(market_slot)) {

      rows <- which(market_slot == CONT_001)

      # The bound of this slot, in electricity. Upward it is what the
      # system draws at its ceiling, less the margin; downward it is
      # the margin itself. inside() carries the direction, so the rest
      # of the block is the same for both legs.
      margin_energy <- margin * sum(delta_t_h[rows], na.rm = TRUE)

      if (identical(leg, "up")) {
        bound  <- elec_from_heat(Q_heat_ceiling, Q_cool_ceiling, rows) - margin_energy
        inside <- function(value) value <= bound
      } else {
        bound  <- margin_energy
        inside <- function(value) value >= bound
      }

      # The plan itself outside the band means the slot has no service
      # to offer, whatever the factor, so it is left as the plan.
      if (!inside(elec_from_heat(Q_heat_plan, Q_cool_plan, rows))) {
        Q_heat_out[rows] <- Q_heat_plan[rows]
        Q_cool_out[rows] <- Q_cool_plan[rows]
        next
      }

      # The itinerary as the caller built it already inside the band
      # needs nothing.
      if (inside(elec_from_heat(Q_heat_flex, Q_cool_flex, rows))) {
        next
      }

      # low is the deepest factor tested that stays inside the band,
      # high the shallowest that does not, so the bisection closes on
      # the deepest itinerary the margin allows.
      low  <- 0
      high <- 1

      for (CONT_002 in seq_len(bisection_steps)) {
        middle <- (low + high) / 2
        candidate_heat <- Q_heat_out
        candidate_cool <- Q_cool_out
        candidate_heat[rows] <- Q_heat_plan[rows] +
          middle * (Q_heat_flex[rows] - Q_heat_plan[rows])
        candidate_cool[rows] <- Q_cool_plan[rows] +
          middle * (Q_cool_flex[rows] - Q_cool_plan[rows])
        if (inside(elec_from_heat(candidate_heat, candidate_cool, rows))) {
          low  <- middle
        } else {
          high <- middle
        }
      }

      Q_heat_out[rows] <- Q_heat_plan[rows] +
        low * (Q_heat_flex[rows] - Q_heat_plan[rows])
      Q_cool_out[rows] <- Q_cool_plan[rows] +
        low * (Q_cool_flex[rows] - Q_cool_plan[rows])

      rm(candidate_heat, candidate_cool, middle, low, high)
    }

    rm(list = intersect(c("CONT_001", "CONT_002", "rows", "bound", "inside",
                          "margin_energy", "bisection_steps"), ls()))
  }

  return(list(Q_heat = Q_heat_out, Q_cool = Q_cool_out))
}
