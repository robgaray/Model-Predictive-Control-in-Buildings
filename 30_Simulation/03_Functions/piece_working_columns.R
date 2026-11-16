# -------------------------------------------------------------
# Function: piece_working_columns.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Adds to the table of the system of a market piece the working
# columns of the market: the columns an evaluation of a candidate
# writes there and Main_df does not hold. They are:
#   - the net electricity of the two flexibility itineraries,
#     written by derive_flex_itineraries()
#   - the phases of the flexibility windows, written by
#     derive_flex_itineraries()
#   - the number of legs held, written by evaluate_control()
#   - the terms of the reward and Reward, written by
#     reward_function()
# An evaluation writes every one of them whole, so the value they
# hold before it is never read.
# They are added once, before the genetic algorithm, so that the
# layout of the views (piece_layout()) describes the piece in every
# evaluation, which then adds no column to it.
# The columns are declared in the order an evaluation creates them
# on a piece that holds none, so a piece prepared here and one that
# is not hold the same columns in the same order after an
# evaluation. No result depends on that order.
# A column the piece already holds is kept as it is. A column an
# evaluation writes and this list does not declare changes no
# result: the views are laid out again, at a cost in time.
# -------------------------------------------------------------
# Inputs
#   piece : List. The piece of a market, as build_market_piece()
#           gives it.
# -------------------------------------------------------------
# Outputs
#   List. The piece with every working column in the table of the
#   system, with 0 on every row of those it did not hold.
# -------------------------------------------------------------
# Code outline
# 1. The working columns
# 2. Add those the table of the system lacks
# -------------------------------------------------------------
# Usage instructions
# piece <- piece_working_columns(piece = piece)
# -------------------------------------------------------------

piece_working_columns <- function(piece
                                  ) {

  # -------------------------------------------------------------
  # 1. The working columns
  # In the order an evaluation creates them: first the net
  # electricity of the itineraries and the phases of the derivation,
  # then the legs held, then the terms of the reward and Reward.
  # -------------------------------------------------------------
  {
    working_columns <- c(
      "Elec_total_plan_flex_down",
      "Elec_total_plan_flex_up",
      "Flex_phase_down_plan",
      "Flex_phase_up_plan",
      "Standing_commitment_held_legs_plan",
      "Elec_Cost_plan",
      "Elec_Cost_distribution_plan",
      "Technical_feasibility_penalty_plan",
      "Elec_flex_com_revenue_plan",
      "Elec_flex_exec_revenue_plan",
      "Reward"
    )
  }

  # -------------------------------------------------------------
  # 2. Add those the table of the system lacks
  # Each one is written with 0 on every row.
  # -------------------------------------------------------------
  {
    missing_columns <- working_columns[!(working_columns %in%
                                           names(piece$system))]
    piece$system[missing_columns] <- 0
    rm(list = c("working_columns", "missing_columns"))
  }

  return(piece)
}
