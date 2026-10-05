# -------------------------------------------------------------
# Function: continue_standing_tail.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Continues, over the plan of a chunk, the tail of a flexibility window
# whose Commitment Phase ended before the chunk starts. Only its
# Neutral and Recovery Phases are left, and they are simulated here
# from the state the window left at the first row of the chunk.
# -------------------------------------------------------------
# Why the tail is simulated again and not copied
# In the Neutral Phase the power of every step is imposed from the plan,
# so the flexibility itinerary spends exactly what the plan spends. The
# plan of the chunk is not the plan the window was built over: the
# chunk simulates it again, and a market that optimizes energy changes
# it with every candidate. A tail copied from the earlier plan would
# stop spending what the current plan spends, and the difference would
# show up as a flexibility the window never sold. Continuing the tail
# over the current plan keeps the Neutral Phase neutral, and the
# Recovery Phase starts from the state the window actually left.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. The chunk being derived, with both
#                  flexibility itineraries already laid as a copy of
#                  _plan, and the state of the window written on row 1
#                  of the flexibility columns of the leg.
#   leg          : Character scalar, "down" or "up".
#   tail         : Named list, as run_market_process() builds it:
#                    rows   - Integer vector. Rows of the chunk occupied
#                             by the tail.
#                    phases - Integer vector, one per row of rows. Phase
#                             code of every row: 2 Neutral, 3 Recovery.
#                    system - Character scalar, "heat", "cool" or
#                             "none". The system that provided the
#                             service, which the Recovery Phase may not
#                             replace with the other one.
#   parameters   : Named list. Model parameters, passed to
#                  period_calculation().
# -------------------------------------------------------------
# Outputs
#   The chunk with the flexibility itinerary of the leg simulated over
#   the rows of the tail, and Flex_phase_<leg>_plan set to its phases.
# -------------------------------------------------------------
# Code outline
# 1. The rows to simulate and their phases
# 2. Simulate the tail
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- continue_standing_tail(period_chunk, "down", tail, parameters)
# -------------------------------------------------------------
# Where this function/script is used
#   - derive_flex_itineraries()
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - Row 1 is the initial state of the simulation and is never
#     simulated: it keeps the state of the window handed over by the
#     caller.
#   - The Neutral Phase is simulated with the power imposed
#     (calculation_mode 2), read from the flexibility columns, which
#     are the copy of the plan. The Recovery Phase is simulated with the
#     setpoints and the caps of build_system_lock_caps()
#     (calculation_mode 3), except its first row, which keeps the
#     imposed power, as in flex_evaluation_down() and
#     flex_evaluation_up(). A tail continued over the same plan is
#     therefore the same itinerary the builder drew.
# -------------------------------------------------------------
# functions/scripts called
#   build_system_lock_caps() - per-step power caps of the Recovery Phase
#   period_calculation() - core building physics simulation
# -------------------------------------------------------------

continue_standing_tail <- function(period_chunk, leg, tail, parameters) {

  # -------------------------------------------------------------
  # 1. The rows to simulate and their phases
  # -------------------------------------------------------------
  {
    if (!leg %in% c("down", "up")) {
      stop("continue_standing_tail: leg must be 'down' or 'up'")
    }

    phase_col <- paste0("Flex_phase_", leg, "_plan")
    last_row  <- min(max(tail$rows), nrow(period_chunk))
    keep      <- tail$rows <= last_row

    subset_rows   <- seq_len(last_row)
    chunk_subset  <- period_chunk[subset_rows, ]
    chunk_subset[[phase_col]][tail$rows[keep]] <- tail$phases[keep]

    # The same modes the window builders use: the power is imposed up to
    # and including the row where the Recovery Phase starts, and the
    # thermostat decides, under the caps, from the next one.
    calculation_mode_vec <- ifelse(chunk_subset[[phase_col]] == 3L, 3L, 2L)
    first_recovery_row   <- which(chunk_subset[[phase_col]] == 3L)[1]
    if (!is.na(first_recovery_row)) {
      calculation_mode_vec[first_recovery_row] <- 2L
    }

    rm(last_row, keep, first_recovery_row)
  }

  # -------------------------------------------------------------
  # 2. Simulate the tail
  # -------------------------------------------------------------
  {
    # build_system_lock_caps is called to keep the system that did not
    # provide the service from taking over in the Recovery Phase.
    lock_caps <- build_system_lock_caps(period_chunk_subset = chunk_subset,
                                        phase_vec           = chunk_subset[[phase_col]],
                                        system_used         = tail$system,
                                        plan_suffix         = "_plan")

    # period_calculation is called to simulate the tail over the plan of
    # this chunk.
    chunk_subset <- period_calculation(chunk_subset,
                                       parameters,
                                       calculation_mode    = calculation_mode_vec,
                                       calculation_context = paste0("plan_flex_", leg),
                                       Q_heat_cap          = lock_caps$Q_heat_cap,
                                       Q_cool_cap          = lock_caps$Q_cool_cap)

    period_chunk[subset_rows, ] <- chunk_subset

    rm(lock_caps, chunk_subset, subset_rows, calculation_mode_vec, phase_col)
  }

  return(period_chunk)
}
