# -------------------------------------------------------------
# Function: pre_horizon_window_tails.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Finds, for each flexibility leg, the windows already committed whose
# Commitment Phase starts in the simulated stretch of a market, between
# i0 and i_begin_horizon, and returns the row where the last of them
# ends: the end of its Recovery Phase.
# A window like that started before the market optimizes anything, but
# its Neutral and Recovery Phases may run into the optimization
# horizon. The market has to rebuild it whole, and it may not start a
# new window of the same leg until it is over.
# -------------------------------------------------------------
# Inputs
#   period_chunk    : Data frame starting at i0 (row 1). Must contain
#                     time, MarketUTC and the committed energy columns
#                     Elec_flex_down_plan and Elec_flex_up_plan.
#   i_begin_horizon : Integer. Row of period_chunk where the
#                     optimization horizon starts.
#   parameters      : Named list. Used by reconstruct_flex_phases().
# -------------------------------------------------------------
# Outputs
#   Named list with one integer per leg, down and up: the last row of
#   period_chunk occupied by a window of that leg whose Commitment
#   Phase starts before i_begin_horizon. 0 when there is none.
# -------------------------------------------------------------
# Code outline
# 1. Phases of each leg, and the windows that start before the horizon
# -------------------------------------------------------------
# Usage instructions
# tails <- pre_horizon_window_tails(period_chunk, i_begin_horizon, parameters)
# -------------------------------------------------------------
# Where this function/script is used
#   - run_market_process(): sizes the simulated stretch so that those
#     windows are projected whole, and hands their tail to the
#     optimization (hand_over_window_tail()).
# -------------------------------------------------------------
# functions/scripts called
#   - reconstruct_flex_phases(): the phases of the windows of a leg,
#     from its committed energy
# -------------------------------------------------------------

pre_horizon_window_tails <- function(period_chunk, i_begin_horizon, parameters) {

  # -------------------------------------------------------------
  # 1. Phases of each leg, and the windows that start before the horizon
  # -------------------------------------------------------------
  # A window is a stretch of Commitment Phase rows (phase 1) followed by
  # its Neutral and Recovery rows (phases 2 and 3). It ends at the last
  # of those rows before a row out of any window or the start of the
  # next window.
  # -------------------------------------------------------------
  {
    tails <- list(down = 0L, up = 0L)

    for (CONT_001 in c("down", "up")) {
      # reconstruct_flex_phases is called to lay the three phases of
      # every window of this leg from its committed energy.
      phase <- reconstruct_flex_phases(period_chunk, CONT_001, parameters)
      n     <- length(phase)

      commit_starts <- which(phase == 1L & c(TRUE, phase[-n] != 1L))
      commit_starts <- commit_starts[commit_starts < i_begin_horizon]

      for (CONT_002 in commit_starts) {
        window_end <- CONT_002
        while (window_end < n && phase[window_end + 1] != 0L &&
               !(phase[window_end + 1] == 1L && phase[window_end] != 1L)) {
          window_end <- window_end + 1L
        }
        tails[[CONT_001]] <- max(tails[[CONT_001]], window_end)
      }

      rm(phase, n, commit_starts)
    }
  }

  return(tails)
}
