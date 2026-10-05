# -------------------------------------------------------------
# Function: market_slot_index.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Says which market slot each timestep of a candidate belongs to, as a
# factor whose levels are the target slots in their own order.
#
# With this index, aggregate_by_market_slot() adds a candidate up per
# slot in a single split, instead of comparing the candidate's
# MarketUTC with every target slot in turn.
# -------------------------------------------------------------
# Inputs
# candidate_market_utc : POSIXct vector. The market slot of each
#                        timestep of the candidate.
# market_utc           : POSIXct vector. The target market slots, in
#                        the order the totals are wanted.
# -------------------------------------------------------------
# Outputs
# Factor, the same length as candidate_market_utc, with one level per
# entry of market_utc. A timestep whose slot is not among the targets
# comes back as NA, and aggregate_by_market_slot() then leaves it out
# of every total.
# -------------------------------------------------------------
# Code outline
# 1. Match each timestep against the target slots.
# -------------------------------------------------------------
# Usage instructions
# slot_index <- market_slot_index(period_chunk$MarketUTC, market_utc)
# -------------------------------------------------------------
# Where this function/script is used
#   - compute_marginal_distribution_cost()
#   - compute_marginal_energy_cost()
#   - compute_marginal_flex_revenue()
# -------------------------------------------------------------
# functions/scripts called
# None.
# -------------------------------------------------------------

market_slot_index <- function(candidate_market_utc, market_utc) {

  # -------------------------------------------------------------
  # 1. Match each timestep against the target slots
  # The levels are the positions of market_utc, so the totals come out
  # in the order the caller declared its slots, and a slot with no
  # timestep still gets its place.
  # -------------------------------------------------------------

  {
    slot_index <- factor(match(candidate_market_utc, market_utc),
                         levels = seq_along(market_utc))
  }

  return(slot_index)
}
