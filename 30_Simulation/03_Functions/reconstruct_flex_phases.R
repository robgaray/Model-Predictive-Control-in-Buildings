# -------------------------------------------------------------
# Function: reconstruct_flex_phases.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Rebuilds the phase of every row of a flexibility window from the
# committed energy that Main_df already stores, without any label of
# its own. The phase codes are:
#   - 1 Commitment
#   - 2 Neutral
#   - 3 Recovery
#   - 0 outside the window
# See 01_Agent_Comments/20260918g_Plan_Compromiso_Vigente.md
# -------------------------------------------------------------
# Why there is no label to read
# Because storing one would be storing the same fact twice. The
# commitment is already written, row by row, in Elec_flex_down_plan and
# Elec_flex_up_plan, and a label beside it could only ever agree with it
# or contradict it. With a single source there is nothing to reconcile.
# The Commitment Phase is the support of that column - reward_function()
# defines the commitment as the energy difference multiplied by
# (phase == 1), so it is zero everywhere else by construction - and the
# other two phases follow from it: they are neutral_phase_timespan and
# recovery_phase_timespan hours long, both read from
# 08_Flexibility_Event_Configuration.csv.
# -------------------------------------------------------------
# Why it works on market slots and not on rows
# A Commitment Phase is assembled from whole market slots, so that is
# the grain the reconstruction has to use. Read row by row it would
# break on a case that is not rare at all: a row INSIDE the commitment
# whose committed energy is exactly zero, which happens whenever the
# flexible itinerary consumes the same as the plan at that instant -
# because the machine was already off, for example. Row by row that row
# would split one window into two and drop a Neutral Phase in the
# middle of a commitment. Slot by slot the slot stays in the phase as
# long as any of its rows carries something.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. Must carry time, MarketUTC and the
#                  committed-energy column of the leg being rebuilt.
#   leg          : Character. "down" or "up".
#   parameters   : Named list. parameters$control$neutral_phase_timespan
#                  and recovery_phase_timespan (h),
#                  commitment_phase_length_max (h), and
#                  parameters$computing$flex_energy_tol.
# -------------------------------------------------------------
# Outputs
#   Integer vector, one entry per row of period_chunk: 1 inside a
#   Commitment Phase, 2 inside a Neutral Phase, 3 inside a Recovery
#   Phase, 0 outside any window.
# -------------------------------------------------------------
# Code outline
# 1. Which market slots carry a commitment
# 2. Group them into windows, and lay the three phases on each
# -------------------------------------------------------------
# Usage instructions
# phase <- reconstruct_flex_phases(period_chunk, "up", parameters)
# -------------------------------------------------------------
# Where this function/script is used
# Called by derive_flex_itineraries(), which needs to know where each
# phase of a standing commitment falls before it can hold it over a new
# plan.
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - A stretch of committed slots longer than commitment_phase_length_max
#     cannot be one Commitment Phase, so it is cut into consecutive
#     windows of at most that length. It should not arise once windows
#     are written whole, and cutting it is the honest reading if it
#     does.
#   - The two legs are rebuilt independently and may overlap each other.
#     That is intended: they are two different itineraries living in
#     two different sets of columns.
#   - A window whose Neutral or Recovery Phase runs past the end of the
#     chunk simply has it truncated. What is outside the chunk is not
#     this chunk's business.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

reconstruct_flex_phases <- function(period_chunk, leg, parameters) {

  # 1. Which market slots carry a commitment
  # -------------------------------------------------------------
  {
    committed_col <- paste0("Elec_flex_", leg, "_plan")

    needed  <- c("time", "MarketUTC", committed_col)
    missing <- needed[!needed %in% names(period_chunk)]
    if (length(missing) > 0) {
      stop("reconstruct_flex_phases: period_chunk is missing required columns: ",
           paste(missing, collapse = ", "))
    }

    phase <- integer(nrow(period_chunk))
    if (nrow(period_chunk) == 0) {
      return(phase)
    }

    tol <- parameters$computing$flex_energy_tol

    carries <- !is.na(period_chunk[[committed_col]]) &
      abs(period_chunk[[committed_col]]) > tol

    if (!any(carries)) {
      return(phase)
    }

    slot_key    <- as.numeric(period_chunk$MarketUTC)
    slots       <- unique(slot_key)
    slot_carries <- vapply(slots, function(one_slot) {
      any(carries[slot_key == one_slot])
    }, logical(1))
  }

  # 2. Group them into windows, and lay the three phases on each
  # -------------------------------------------------------------
  {
    time_sec  <- as.numeric(period_chunk$time)
    neutral_h <- parameters$control$neutral_phase_timespan
    recovery_h <- parameters$control$recovery_phase_timespan
    max_commit_sec <- parameters$control$commitment_phase_length_max * 3600

    stretches <- rle(slot_carries)
    ends      <- cumsum(stretches$lengths)
    starts    <- ends - stretches$lengths + 1

    for (CONT_001 in which(stretches$values)) {

      stretch_slots <- slots[starts[CONT_001]:ends[CONT_001]]

      # A stretch longer than the maximum Commitment Phase cannot be one
      # window, so it is cut into consecutive ones.
      while (length(stretch_slots) > 0) {

        commit_begin <- min(time_sec[slot_key %in% stretch_slots])
        keep         <- stretch_slots[
          vapply(stretch_slots, function(one_slot) {
            min(time_sec[slot_key == one_slot]) - commit_begin < max_commit_sec
          }, logical(1))
        ]

        commit_rows <- which(slot_key %in% keep)
        phase[commit_rows] <- 1L

        commit_end   <- max(time_sec[commit_rows])
        neutral_end  <- commit_end + neutral_h * 3600
        recovery_end <- neutral_end + recovery_h * 3600

        phase[time_sec > commit_end  & time_sec <= neutral_end  & phase == 0L] <- 2L
        phase[time_sec > neutral_end & time_sec <= recovery_end & phase == 0L] <- 3L

        stretch_slots <- setdiff(stretch_slots, keep)
      }
    }
  }

  rm(committed_col, needed, missing, tol, carries, slot_key, slots,
     slot_carries, time_sec, neutral_h, recovery_h, max_commit_sec,
     stretches, ends, starts)

  return(phase)
}
