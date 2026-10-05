# -------------------------------------------------------------
# Function: aggregate_by_market_slot.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Adds up a per-timestep quantity into one total per market slot, which
# is the unit every marginal cost and revenue is valued on.
#
# The three functions that value a candidate - the marginal energy
# cost, the marginal distribution cost and the marginal flexibility
# revenue - all need this same total. The slot of each timestep is
# given as a factor (market_slot_index()), so the candidate is split
# once instead of being compared with every market slot in turn,
# which is costly on POSIXct vectors.
#
# Why the sum is not vectorised further
# -------------------------------------------------------------
# Floating point addition is not associative, so the order the terms
# are added in decides the last bit of the result. split() hands each
# group to sum() in the order of its rows, so each total is the plain
# sum of its timesteps in time order. rowsum() is faster but adds in
# another order: it can differ by one unit in the last place, and a
# search that compares candidates can turn that into a different
# optimum.
# -------------------------------------------------------------
# Inputs
# values     : Numeric vector, one entry per timestep of the candidate.
# slot_index : Factor, the same length as values, whose levels are the
#              market slots in the order the totals are wanted. Built
#              by market_slot_index() from the candidate's MarketUTC
#              and the target market instants.
# -------------------------------------------------------------
# Outputs
# Numeric vector, one entry per level of slot_index, in that order. A
# slot no timestep belongs to gets a total of zero.
# -------------------------------------------------------------
# Code outline
# 1. Split the values by slot and add each group up.
# -------------------------------------------------------------
# Usage instructions
# slot_index <- market_slot_index(period_chunk$MarketUTC, market_utc)
# totals     <- aggregate_by_market_slot(E_candidate, slot_index)
# -------------------------------------------------------------
# Where this function/script is used
#   - compute_marginal_distribution_cost()
#   - compute_marginal_energy_cost()
#   - compute_marginal_flex_revenue()
# -------------------------------------------------------------
# functions/scripts called
# None.
# -------------------------------------------------------------

aggregate_by_market_slot <- function(values, slot_index) {

  # -------------------------------------------------------------
  # 1. Split the values by slot and add each group up
  # split() drops nothing: the factor carries one level per target
  # slot, so a slot with no timestep comes back as an empty group and
  # sum() gives it a zero.
  # -------------------------------------------------------------

  {
    totals <- unname(vapply(split(values, slot_index), sum, numeric(1)))
  }

  return(totals)
}
