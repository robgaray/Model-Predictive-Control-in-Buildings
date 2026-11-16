# -------------------------------------------------------------
# Function: battery_continue_window_tail.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Continues, over the plan of a chunk, the tail of a flexibility
# window of a battery whose Commitment Phase ended before the chunk
# starts. Only its Neutral and Recovery Phases are left. It is the
# operation continue_window_tail of the type of model Battery
# (model_type_contract()).
# The window left the leg of the battery with some energy on row 1,
# the state of the tail, which the caller has written there. On the
# rows of the tail, the leg follows the electricity of the plan, b
# (kWh of the system side, positive to charge), from that energy. The
# leg is carried out when no step from row 2 to the close of the
# control horizon breaks a limit of the battery
# (battery_free_trajectory()). If it is not, the battery corrects its
# Recovery Phase as for a window it draws
# (battery_recovery_correction()): one power over the rows of phase 3
# of the tail, or what a row can still take if it is less, in the
# direction that gives the energy back, until the leg is back on the
# energy of the plan, where the correction stops. A tail cannot be
# refused, so when no correction carries the leg out the battery
# takes the largest one it can make.
# The correction is the one the tail asks (tail$recovery, minimum or
# plan). Without it, or with minimum, it is the least that carries
# the leg out. With plan, the battery buys or sells until it is back
# on the energy of the plan at the last row of the Recovery Phase, or
# as far as its power allows, never less than the least correction.
# The leg is drawn from row 2 to the last row of the tail, and its
# stored energy keeps on the rows after it the difference the tail
# left (battery_draw_leg()). The phases of the tail are of the
# system, so the battery marks none.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. The view of the battery of the piece
#                  being derived, with both flexibility itineraries
#                  laid as a copy of the plan, and the state of the
#                  tail written on row 1 of
#                  Stored_energy_plan_flex_<leg>. Reads time and,
#                  for the leg, Elec_charge_plan_flex_<leg>,
#                  Elec_discharge_plan_flex_<leg> and
#                  Stored_energy_plan_flex_<leg>.
#   leg          : Character scalar, "down" or "up".
#   tail         : Named list, the view of this battery of the tail:
#                    rows            - Integer vector. Rows of the
#                                      chunk occupied by the tail.
#                    phases          - Integer vector, one per row of
#                                      rows: 2 Neutral, 3 Recovery.
#                    i_end_control   - Integer. The row where the
#                                      control horizon closes.
#                    bisection_steps - Integer. The halvings of each
#                                      bisection of the correction.
#                    tolerance       - Numeric. The tolerance of the
#                                      comparisons with the limits
#                                      (kWh).
#                    recovery        - minimum or plan; absent or
#                                      NULL for minimum.
#                  The state and the system of the tail are not read:
#                  the state is already on row 1.
#   asset        : Named list. The parameters of the battery, its
#                  entry of parameters$assets.
# -------------------------------------------------------------
# Outputs
#   Data frame. The view with the leg of the battery drawn over the
#   rows of the tail, and the stored energy of the rows after them
#   moved by the difference.
# -------------------------------------------------------------
# Code outline
# 1. Read the tail
# 2. The correction of the Recovery Phase
# 3. Draw the leg
# -------------------------------------------------------------
# Usage instructions
# view <- battery_continue_window_tail(
#   period_chunk = view,
#   leg          = "down",
#   tail         = list(rows = 2:5, phases = c(2L, 2L, 3L, 3L),
#                       i_end_control = 8, bisection_steps = 24,
#                       tolerance = 1e-9, recovery = NULL),
#   asset        = asset
# )
# -------------------------------------------------------------

battery_continue_window_tail <- function(period_chunk,
                                         leg,
                                         tail,
                                         asset
                                         ) {

  # -------------------------------------------------------------
  # 1. Read the tail
  # The rows drawn go from row 2 to the last row of the tail inside
  # the chunk. The Recovery Phase is the rows of phase 3 among them.
  # The stretch that is checked goes from row 2 to the row where the
  # control horizon closes, or to the last row of the tail if that is
  # later.
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("battery_continue_window_tail: leg must be \"down\" or \"up\"")
    }
    if (length(tail$rows) == 0 || length(tail$phases) != length(tail$rows) ||
        !is.numeric(tail$i_end_control) ||
        length(tail$i_end_control) != 1 ||
        !is.numeric(tail$bisection_steps) ||
        length(tail$bisection_steps) != 1 ||
        !is.numeric(tail$tolerance) || length(tail$tolerance) != 1) {
      stop("battery_continue_window_tail: the tail must give its rows ",
           "with one phase each, i_end_control, bisection_steps and ",
           "tolerance (", asset$asset_id, ")")
    }
    if (!is.null(tail$recovery) &&
        !(length(tail$recovery) == 1 &&
          tail$recovery %in% c("minimum", "plan"))) {
      stop("battery_continue_window_tail: tail$recovery must be ",
           "\"minimum\" or \"plan\" (", asset$asset_id, ")")
    }

    n_rows   <- nrow(period_chunk)
    last_row <- min(max(tail$rows), n_rows)
    if (last_row < 2) {
      rm(list = c("n_rows", "last_row"))
      return(period_chunk)
    }

    sfx            <- paste0("_plan_flex_", leg)
    rows_recovery  <- tail$rows[tail$phases == 3L]
    rows_recovery  <- rows_recovery[rows_recovery >= 2 &
                                      rows_recovery <= last_row]
    stretch        <- 2:min(max(tail$i_end_control, last_row), n_rows)
    time_sec       <- as.numeric(period_chunk$time)
    delta_all      <- (time_sec[stretch] - time_sec[stretch - 1]) / 3600
    leg_energy     <- period_chunk[[paste0("Elec_charge", sfx)]] -
      period_chunk[[paste0("Elec_discharge", sfx)]]
    energy_start   <- period_chunk[[paste0("Stored_energy", sfx)]][1]
    reference      <- period_chunk[[paste0("Stored_energy", sfx)]][stretch]
    steps_recovery <- rows_recovery - 1

    rm(list = "time_sec")
  }

  # -------------------------------------------------------------
  # 2. The correction of the Recovery Phase
  # The least correction that carries the leg out, or, with plan, the
  # one that returns to the energy of the plan at the last row of the
  # Recovery Phase. A correction that does not carry the leg out is
  # kept as it is: it is the largest the battery can make.
  # -------------------------------------------------------------
  {
    target <- NULL
    if (identical(tail$recovery, "plan") && length(rows_recovery) > 0) {
      target <- period_chunk[[paste0("Stored_energy",
                                     sfx)]][max(rows_recovery)]
    }

    # battery_recovery_correction is called to find the correction of
    # the Recovery Phase of the tail, if the leg needs it.
    correction <- battery_recovery_correction(
      stored_energy_start = energy_start,
      delta_t_h           = delta_all,
      base_request        = leg_energy[stretch],
      reference_energy    = reference,
      recovery_steps      = steps_recovery,
      check_steps         = seq_along(stretch),
      direction           = if (leg == "down") 1 else -1,
      target_energy       = target,
      battery             = asset$battery,
      bisection_steps     = tail$bisection_steps,
      tolerance           = tail$tolerance
    )
  }

  # -------------------------------------------------------------
  # 3. Draw the leg
  # The leg is drawn from row 2 to the last row of the tail, within
  # the limits of the battery. The rows after it keep their
  # electricity and carry the difference of the stored energy.
  # -------------------------------------------------------------
  {
    in_tail <- seq_len(last_row - 1)

    # battery_draw_leg is called to draw the leg over the rows of the
    # tail, within the limits of the battery, and to carry the
    # difference of the stored energy to the rows after it.
    period_chunk <- battery_draw_leg(
      period_chunk   = period_chunk,
      leg            = leg,
      rows           = 2:last_row,
      energy_request = leg_energy[stretch][in_tail] +
        correction$extra[in_tail],
      asset          = asset
    )

    rm(list = c("n_rows", "last_row", "sfx", "rows_recovery", "stretch",
                "delta_all", "leg_energy", "energy_start", "reference",
                "steps_recovery", "target", "correction", "in_tail"))
  }

  return(period_chunk)
}
