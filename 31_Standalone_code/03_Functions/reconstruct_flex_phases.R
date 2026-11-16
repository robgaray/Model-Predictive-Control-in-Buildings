# -------------------------------------------------------------
# Function: reconstruct_flex_phases.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Rebuilds the phase of every row of a flexibility window from the
# committed energy that the plan itinerary already carries, without any label of
# its own. The phase codes are:
#   - 1 Commitment
#   - 2 Neutral
#   - 3 Recovery
#   - 0 outside the window
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
# Why a gap may be inside a window
# A whole market slot inside a Commitment Phase may carry no commitment
# either: downward, when the plan consumes nothing in it, or less than
# the commitment margin, the flexible itinerary stays equal to the plan
# there. The committed slots of such a window form two stretches with
# a gap between them, and the gap belongs to the window.
# Two windows of the same leg that one market sees are never that
# close. evaluate_control() does not open a window whose Commitment,
# Neutral or Recovery Phase touches a row another window of the leg
# occupies, so the first row of the later window always comes more than
# neutral_phase_timespan + recovery_phase_timespan hours after the last
# row of the Commitment Phase of the earlier one. A window whose
# Commitment Phase ended before the chunk is not in the committed
# energy of the chunk at all, so it cannot be joined to a later one.
# The next committed stretch therefore joins the window when both:
#   - its first row falls within the Neutral or Recovery Phase that the
#     window would lay after its last committed slot, that is, no more
#     than neutral_phase_timespan + recovery_phase_timespan hours after
#     the last row of that slot;
#   - the window, from its first slot to the last slot of that stretch,
#     still fits within commitment_phase_length_max, with the same test
#     that cuts a longer stretch (see below).
# The slots of the gap are then part of the Commitment Phase, with no
# committed energy. A stretch that fails either test starts a window
# of its own. Slots with no commitment at the edges of a window are not
# part of it: the window simply starts at its first committed slot and
# ends at its last one.
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
# 2. Join the committed stretches that belong to one window
# 3. Lay the three phases on each window
# -------------------------------------------------------------
# Usage instructions
# phase <- reconstruct_flex_phases(period_chunk, "up", parameters)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - A stretch of committed slots longer than commitment_phase_length_max
#     cannot be one Commitment Phase, so it is cut into consecutive
#     windows of at most that length. It should not arise once windows
#     are written whole, and cutting it is the honest reading if it
#     does. Such a stretch is never joined to the stretch before or
#     after it, because the joined window could not fit either.
#   - The two legs are rebuilt independently and may overlap each other.
#     That is intended: they are two different itineraries living in
#     two different sets of columns.
#   - A window whose Neutral or Recovery Phase runs past the end of the
#     chunk simply has it truncated. What is outside the chunk is not
#     this chunk's business.
# -------------------------------------------------------------

reconstruct_flex_phases <- function(period_chunk, leg, parameters) {

  # -------------------------------------------------------------
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

    slot_key     <- as.numeric(period_chunk$MarketUTC)
    slots        <- unique(slot_key)
    slot_carries <- vapply(slots, function(one_slot) {
      any(carries[slot_key == one_slot])
    }, logical(1))

    # The first and the last row of every slot, by time, which the two
    # tests of block 2 and the cut of block 3 compare.
    time_sec   <- as.numeric(period_chunk$time)
    slot_first <- vapply(slots, function(one_slot) {
      min(time_sec[slot_key == one_slot])
    }, numeric(1))
    slot_last  <- vapply(slots, function(one_slot) {
      max(time_sec[slot_key == one_slot])
    }, numeric(1))
  }

  # -------------------------------------------------------------
  # 2. Join the committed stretches that belong to one window
  # A stretch is a run of consecutive committed slots. Each one, in time
  # order, either joins the window the stretches before it form, with
  # the slots of the gap between them, or starts a window of its own
  # (see "Why a gap may be inside a window" in the header).
  # window_first and window_last hold the index in slots of the first
  # and the last committed slot of each window.
  # -------------------------------------------------------------
  {
    separation_sec <- (parameters$control$neutral_phase_timespan +
                         parameters$control$recovery_phase_timespan) * 3600
    max_commit_sec <- parameters$control$commitment_phase_length_max * 3600

    stretches <- rle(slot_carries)
    ends      <- cumsum(stretches$lengths)
    starts    <- ends - stretches$lengths + 1

    window_first <- integer(0)
    window_last  <- integer(0)

    for (CONT_001 in which(stretches$values)) {

      n_windows <- length(window_first)

      joins <- n_windows > 0 &&
        slot_first[starts[CONT_001]] - slot_last[window_last[n_windows]] <=
        separation_sec &&
        slot_first[ends[CONT_001]] - slot_first[window_first[n_windows]] <
        max_commit_sec

      if (joins) {
        window_last[n_windows] <- ends[CONT_001]
      } else {
        window_first <- c(window_first, starts[CONT_001])
        window_last  <- c(window_last, ends[CONT_001])
      }

      rm(list = c("n_windows", "joins"))
    }
    rm(list = "CONT_001")
  }

  # -------------------------------------------------------------
  # 3. Lay the three phases on each window
  # Every slot of a window, the ones of its gaps included, is in its
  # Commitment Phase. The Neutral and Recovery Phases follow the last
  # row of the Commitment Phase, over rows no other window claims.
  # -------------------------------------------------------------
  {
    neutral_h  <- parameters$control$neutral_phase_timespan
    recovery_h <- parameters$control$recovery_phase_timespan

    for (CONT_002 in seq_along(window_first)) {

      window_slots <- window_first[CONT_002]:window_last[CONT_002]

      # A stretch longer than the maximum Commitment Phase cannot be one
      # window, so it is cut into consecutive ones.
      while (length(window_slots) > 0) {

        keep <- window_slots[slot_first[window_slots] -
                               slot_first[window_slots[1]] < max_commit_sec]

        commit_rows <- which(slot_key %in% slots[keep])
        phase[commit_rows] <- 1L

        commit_end   <- max(time_sec[commit_rows])
        neutral_end  <- commit_end + neutral_h * 3600
        recovery_end <- neutral_end + recovery_h * 3600

        phase[time_sec > commit_end & time_sec <= neutral_end &
                phase == 0L] <- 2L
        phase[time_sec > neutral_end & time_sec <= recovery_end &
                phase == 0L] <- 3L

        window_slots <- setdiff(window_slots, keep)
      }
    }
    rm(list = c("CONT_002", "window_slots", "keep", "commit_rows", "commit_end",
                "neutral_end", "recovery_end"))
  }

  rm(list = c("committed_col", "needed", "missing", "tol", "carries",
              "slot_key", "slots", "slot_carries", "time_sec", "slot_first",
              "slot_last", "separation_sec", "max_commit_sec", "stretches",
              "ends", "starts", "window_first", "window_last", "neutral_h",
              "recovery_h"))

  return(phase)
}
