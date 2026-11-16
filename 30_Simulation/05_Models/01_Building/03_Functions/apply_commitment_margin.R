# -------------------------------------------------------------
# Function: apply_commitment_margin.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Keeps an electrical headroom on the flexibility itinerary of a
# building, so that a later re-optimization still has room to move
# the operation without breaking a commitment that was already sold.
# It fits the itinerary inside the band the system gives when the
# building is the only asset that contributes to the window.
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
# The asset and the system
# -------------------------------------------------------------
# The headroom is a commercial rule on energy, and the itinerary it
# acts on is a physical profile of heat. The two are kept apart:
#   - The margin is one, of the set of assets that contribute to the
#     window. system_commitment_margin() is the side of the system:
#     from the electricity of the set at the limit of the leg, the
#     market interval of each row and the margin, it asks
#     commitment_margin_bound() for the band every interval must keep,
#     on the net. It knows nothing of heat, systems or COP.
#   - This function and apply_commitment_margin_cpp() are the side of
#     the building. When the building is the only asset that
#     contributes to the window, the system hands it the band, and the
#     building fits the heat of its itinerary inside it. It is the
#     operation margin_fit of the type of model Building
#     (model_type_contract()).
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
# Upward: the electricity of the slot must stay below what the
# building would draw at the ceiling the window is built against, by
# at least the margin. When the plan itself is already above that
# threshold the slot has no upward service to offer and its itinerary
# is left equal to the plan.
#
# Downward: the electricity of the slot must stay above what the
# building draws at its floor, nothing, by at least the margin. When
# the plan itself is already below it the slot has no downward
# service to offer and its itinerary is left equal to the plan.
#
# How a slot is brought back inside the band
# -------------------------------------------------------------
# By scaling that slot's whole departure from the plan by a single
# factor between 0 and 1, on both systems at once, so the itinerary
# keeps its shape and only its depth changes. The electricity of a step
# is a monotone, piecewise linear function of the heat of that step,
# so the electricity of the slot is monotone in the factor and a
# bisection on the closed form finds it without simulating anything.
# The bisection runs flexibility_commitment_bisection_steps halvings.
# The minimum flexibility of each slot is applied afterwards by the
# system, on the net (system_commitment_margin()).
#
# Where the bisection runs
# -------------------------------------------------------------
# In compiled code, in apply_commitment_margin_cpp(), with the
# electrical model the period simulation uses (heat_pump_cop_cpp() and
# heat_pump_electricity_step()). The margin is applied to every window
# built, and the bisection evaluates the electricity of a slot many
# times, so running it in R would be several times slower. This
# function hands the margin data of the building and the band over.
# -------------------------------------------------------------
# Inputs
#   margin     : Named list. The margin data of the building on the
#                rows of the guard zone, as building_margin_data()
#                gives it. Reads plan and profile (the heating and
#                cooling of the plan and of the itinerary before the
#                margin, in kWh), Text and delta_t_h.
#   band       : Named list. The band of the system, as
#                commitment_margin_bound() gives it. Reads slot_id
#                and bound.
#   leg        : Character, "up" or "down".
#   parameters : Named list. Reads
#                parameters$control$flexibility_commitment_bisection_steps.
#   asset      : Named list. The parameters of the building, its entry
#                of parameters$assets. Reads asset$model, for the heat
#                pump.
# -------------------------------------------------------------
# Outputs
# Named list with two numeric vectors, one entry per row of the margin
# data:
#   Q_heat : heating of the itinerary after the margin
#   Q_cool : cooling of the itinerary after the margin
# A slot that has no service to offer comes back equal to the plan on
# both.
# -------------------------------------------------------------
# Code outline
# 1. One slot at a time, find the deepest factor that keeps the
#    itinerary inside the band, in compiled code.
# -------------------------------------------------------------
# Usage instructions
# Needs period_simulation_cpp.cpp compiled with Rcpp::sourceCpp(),
# which exports apply_commitment_margin_cpp(). Called by
# system_commitment_margin(), through the operation margin_fit of the
# model of the building:
# margined <- apply_commitment_margin(margin     = margin,
#                                     band       = band,
#                                     leg        = "up",
#                                     parameters = parameters,
#                                     asset      = asset)
# -------------------------------------------------------------

apply_commitment_margin <- function(margin,
                                    band,
                                    leg,
                                    parameters,
                                    asset) {

  # -------------------------------------------------------------
  # 1. One slot at a time, find the deepest factor that keeps the
  # itinerary inside the band
  # apply_commitment_margin_cpp() applies, slot by slot, the two
  # rules of the file header, with the electrical model of the period
  # simulation.
  # -------------------------------------------------------------

  {
    model <- asset$model

    # apply_commitment_margin_cpp is called to run the bisection of
    # every slot in compiled code.
    margined <- apply_commitment_margin_cpp(
      Q_heat_flex         = margin$profile$Q_heat,
      Q_heat_plan         = margin$plan$Q_heat,
      Q_cool_flex         = margin$profile$Q_cool,
      Q_cool_plan         = margin$plan$Q_cool,
      slot_id             = band$slot_id,
      bound               = band$bound,
      Text                = margin$Text,
      delta_t_h           = margin$delta_t_h,
      leg_up              = identical(leg, "up"),
      bisection_steps     = parameters$control$flexibility_commitment_bisection_steps,
      COP_hp_heat_1_coef1 = model$COP_hp_heat_1_coef1,
      COP_hp_heat_1_coef2 = model$COP_hp_heat_1_coef2,
      COP_hp_heat_1_coef3 = model$COP_hp_heat_1_coef3,
      Tsup_hp_heat        = model$Tsup_hp_heat,
      Text_ref_hp_heat    = model$Text_ref_hp_heat,
      Tsup_ref_hp_heat    = model$Tsup_ref_hp_heat,
      Q_hp_heat_1         = model$Q_hp_heat_1,
      COP_hp_cool         = model$COP_hp_cool
    )

    rm(list = "model")
  }

  return(list(Q_heat = margined$Q_heat, Q_cool = margined$Q_cool))
}
