# -------------------------------------------------------------
# Function: hand_over_window_tail.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Packs what the optimization of a market needs to continue a
# flexibility window whose Commitment Phase started in the simulated
# stretch before i_begin_horizon and whose tail runs into the horizon:
# the rows the tail occupies, their phases, the state the window left
# in its itinerary at i_begin_horizon, and the system that provides it.
# The itinerary of the tail itself is not handed over. The optimization
# continues it over the plan of each candidate, from that state.
# -------------------------------------------------------------
# Inputs
#   stretch_chunk   : Data frame. The simulated stretch, rows 1 to the
#                     end of the tail, after derive_flex_itineraries()
#                     has projected the windows over it.
#   committed_chunk : Data frame. The same rows before the projection,
#                     carrying the committed energy (Elec_flex_down_plan,
#                     Elec_flex_up_plan) as it stands.
#   i_begin_horizon : Integer. Row of the stretch where the optimization
#                     horizon starts.
#   tail_end        : Integer. Last row of the stretch occupied by the
#                     window, as pre_horizon_window_tails() returns it.
#   leg             : Character scalar, "down" or "up".
#   parameters      : Named list. Used by reconstruct_flex_phases().
# -------------------------------------------------------------
# Outputs
#   Named list:
#     rows   : Integer vector. Rows of the tail, counted from the first
#              row of the optimization chunk (i_begin_horizon is row 1).
#     phases : Integer vector, one per row: 1 Commitment, 2 Neutral,
#              3 Recovery.
#     state  : One-row data frame. Ti, Te, Act_heat, Act_cool, Q_heat
#              and Q_cool of the itinerary of the leg at i_begin_horizon.
#     system : Character scalar, "heat", "cool" or "none". The system
#              that provides the window, read over its Commitment Phase
#              with the rule of the window builders.
# -------------------------------------------------------------
# Code outline
# 1. Rows and phases of the tail
# 2. State at i_begin_horizon and system of the window
# -------------------------------------------------------------
# Usage instructions
# tail <- hand_over_window_tail(stretch_chunk, committed_chunk,
#                               i_begin_horizon, tail_end, "down", parameters)
# -------------------------------------------------------------
# Where this function/script is used
#   - run_market_process()
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - A window the projection could not draw is held with its
#     Commitment Phase alone (hold_standing_window()). Its Neutral and
#     Recovery Phases are then read from the committed energy
#     (reconstruct_flex_phases()), because they still belong to it.
#   - A window held that way leaves the plan's state in its itinerary.
# -------------------------------------------------------------
# functions/scripts called
#   reconstruct_flex_phases() - the phases of the window from the
#     committed energy
# -------------------------------------------------------------

hand_over_window_tail <- function(stretch_chunk,
                                  committed_chunk,
                                  i_begin_horizon,
                                  tail_end,
                                  leg,
                                  parameters) {

  # -------------------------------------------------------------
  # 1. Rows and phases of the tail
  # -------------------------------------------------------------
  {
    phase_column <- paste0("Flex_phase_", leg, "_plan")
    tail_rows    <- (i_begin_horizon + 1):tail_end

    # reconstruct_flex_phases is called to read the phases of a window
    # that the projection held with its Commitment Phase alone.
    reconstructed <- reconstruct_flex_phases(committed_chunk, leg, parameters)
    projected     <- stretch_chunk[[phase_column]]
    phases        <- ifelse(projected > 0, projected, reconstructed)

    rm(reconstructed, projected)
  }

  # -------------------------------------------------------------
  # 2. State at i_begin_horizon and system of the window
  # -------------------------------------------------------------
  # The Commitment Phase of the window is the last stretch of phase 1
  # that starts before i_begin_horizon. The system is the one the
  # builders take: downward, the one with the larger heat in the plan;
  # upward, the one the window raises.
  # -------------------------------------------------------------
  {
    state_columns <- paste0(c("Ti", "Te", "Act_heat", "Act_cool", "Q_heat", "Q_cool"),
                            "_plan_flex_", leg)
    state <- stretch_chunk[i_begin_horizon, state_columns, drop = FALSE]
    rownames(state) <- NULL

    in_commitment <- stretch_chunk[[phase_column]] == 1L
    starts        <- which(in_commitment & c(TRUE, !in_commitment[-length(in_commitment)]))
    starts        <- starts[starts < i_begin_horizon]

    system <- "none"
    if (length(starts) > 0) {
      commitment_end <- max(starts)
      while (commitment_end < length(in_commitment) && in_commitment[commitment_end + 1]) {
        commitment_end <- commitment_end + 1
      }
      commitment_rows <- max(starts):commitment_end

      if (leg == "down") {
        S_heat <- sum(stretch_chunk$Q_heat_plan[commitment_rows], na.rm = TRUE)
        S_cool <- sum(stretch_chunk$Q_cool_plan[commitment_rows], na.rm = TRUE)
      } else {
        S_heat <- sum(pmax(stretch_chunk$Q_heat_plan_flex_up -
                             stretch_chunk$Q_heat_plan, 0)[commitment_rows], na.rm = TRUE)
        S_cool <- sum(pmax(stretch_chunk$Q_cool_plan_flex_up -
                             stretch_chunk$Q_cool_plan, 0)[commitment_rows], na.rm = TRUE)
      }

      if (S_heat > 0 || S_cool > 0) {
        system <- if (S_heat >= S_cool) "heat" else "cool"
      }
      rm(commitment_end, commitment_rows, S_heat, S_cool)
    }

    rm(state_columns, in_commitment, starts)
  }

  tail <- list(
    rows   = tail_rows - i_begin_horizon + 1L,
    phases = as.integer(phases[tail_rows]),
    state  = state,
    system = system
  )

  rm(phase_column, tail_rows, phases, state, system)

  return(tail)
}
