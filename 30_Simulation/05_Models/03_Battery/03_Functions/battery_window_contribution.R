# -------------------------------------------------------------
# Function: battery_window_contribution.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Draws the contribution of a battery to one flexibility window of
# the system, of one leg, with its draft and with what the commitment
# margin of the set left, and applies the technical rules of the
# battery to it. It is the operation window_contribution of the type
# of model Battery (model_type_contract()).
# The leg of the battery follows the electricity it had before the
# window, b. The window changes it in two phases:
#   - In the Commitment Phase the battery draws the electricity that
#     its draft gave, with the rows of the guard zone replaced by the
#     electricity the margin left. If that moves the leg by no more
#     than the energy tolerance, the battery has nothing to offer and
#     contributes nothing.
#   - In the Neutral Phase it follows b.
#   - In the Recovery Phase it follows b too, unless the leg cannot
#     be carried out until the close of the control horizon. The leg
#     can be carried out when no step, from the start of the window to
#     the row where the control horizon closes, breaks a limit of the
#     battery (battery_free_trajectory()). If it cannot, the battery
#     corrects its Recovery Phase: it buys energy after a downward
#     window and sells it after an upward one, at one power over the
#     steps of the Recovery Phase (battery_recovery_correction()),
#     until the leg is back on the energy it had stored before the
#     window, where the correction stops.
#     If not even the most the battery can do in the Recovery Phase
#     carries the leg out, the battery refuses the window, with the
#     reason no_recovery.
#     A window that restates a commitment already sold
#     (window$restating) is never refused: its draft already is the
#     largest the least correction carries out, and what the
#     battery does not reach is bought again by the economic chain.
# The window carries the way the Recovery Phase is drawn in recovery.
# Without it, or with minimum, the correction is the least that
# carries the leg out. With plan, the battery buys or sells until it
# is back on the energy it had stored before the window, or as far as
# its power allows, never less than the least correction.
# After the window, the leg keeps the electricity it had, and its
# stored energy keeps the difference that the window left
# (battery_draw_leg()).
# -------------------------------------------------------------
# Inputs
#   leg          : Character scalar, "down" or "up".
#   period_chunk : Data frame. The view of the battery of the piece
#                  (see piece_asset_view()), with the phases of the
#                  window written by the system and, for the
#                  itinerary of the leg, the columns time,
#                  Elec_charge_plan_flex_<leg>,
#                  Elec_discharge_plan_flex_<leg>,
#                  Elec_total_plan_flex_<leg> and
#                  Stored_energy_plan_flex_<leg>.
#   window       : Named list. The window the system fixed, as
#                  system_flex_window() builds it. Reads rows, phase,
#                  commitment, guard_row, i_end_control and, when
#                  present, recovery (minimum or plan) and restating.
#   draft        : Named list. The draft of the battery
#                  (battery_window_draft()).
#   margined     : Named list or NULL. What the commitment margin of
#                  the set left: the vector Elec (kWh), one entry per
#                  row of the guard zone. NULL when the window has no
#                  row in the guard zone.
#   parameters   : Named list. Reads
#                  parameters$control$
#                  flexibility_commitment_bisection_steps and
#                  parameters$computing$flex_energy_tol (kWh).
#   asset        : Named list. The parameters of the battery, its
#                  entry of parameters$assets.
# -------------------------------------------------------------
# Outputs
#   A named list with:
#   chunk   : Data frame. The view with the leg of the battery drawn
#             over the rows of the window, or untouched when the
#             battery has nothing to offer or refuses the window.
#   refusal : Character scalar or NULL. no_recovery when the battery
#             refuses the window, NULL otherwise.
#   drawn   : Logical scalar. TRUE when the leg was drawn.
#   accepted : Logical scalar, only when drawn is FALSE and there is
#             no refusal. TRUE when the window restates a commitment
#             already sold and the margin leaves the battery no
#             energy to draw: the battery accepts it with no energy.
# -------------------------------------------------------------
# Code outline
# 1. Read the window
# 2. The Commitment Phase
# 3. The Recovery Phase
# 4. Draw the leg
# -------------------------------------------------------------
# Usage instructions
# contribution <- battery_window_contribution(
#   leg          = "down",
#   period_chunk = view,
#   window       = window,
#   draft        = draft,
#   margined     = margined,
#   parameters   = parameters,
#   asset        = asset
# )
# -------------------------------------------------------------

battery_window_contribution <- function(leg,
                                        period_chunk,
                                        window,
                                        draft,
                                        margined,
                                        parameters,
                                        asset
                                        ) {

  # -------------------------------------------------------------
  # 1. Read the window
  # The rows of the window after its initial condition are
  # consecutive. The stretch that is checked goes from the first of
  # them to the row where the control horizon closes, or to the end
  # of the window if that is later.
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("battery_window_contribution: leg must be \"down\" or ",
           "\"up\"")
    }
    if (!is.null(window$recovery) &&
        !(length(window$recovery) == 1 &&
          window$recovery %in% c("minimum", "plan"))) {
      stop("battery_window_contribution: window$recovery must be ",
           "\"minimum\" or \"plan\" (", asset$asset_id, ")")
    }

    sfx        <- paste0("_plan_flex_", leg)
    rows       <- window$rows[-1]
    rows_flex  <- window$rows[window$commitment]
    first_row  <- rows[1]
    last_row   <- rows[length(rows)]
    if (any(diff(rows) != 1)) {
      stop("battery_window_contribution: the rows of the window after ",
           "its initial condition must be consecutive")
    }

    tol        <- parameters$computing$flex_energy_tol
    leg_energy <- period_chunk[[paste0("Elec_charge", sfx)]] -
      period_chunk[[paste0("Elec_discharge", sfx)]]
    time_sec   <- as.numeric(period_chunk$time)
    stretch    <- first_row:min(max(window$i_end_control, last_row),
                                nrow(period_chunk))
    delta_t_h  <- (time_sec[stretch] - time_sec[stretch - 1]) / 3600
    rm(list = "time_sec")
  }

  # -------------------------------------------------------------
  # 2. The Commitment Phase
  # The electricity of the draft, with the rows of the guard zone
  # replaced by the electricity the margin left. A window that moves
  # the leg by no more than the energy tolerance is not drawn; when it
  # restates a commitment, the battery accepts it with no energy.
  # -------------------------------------------------------------
  {
    drawn_energy <- draft$profile$Elec
    if (!is.null(margined)) {
      drawn_energy[window$guard_row] <- margined$Elec
    }

    if (max(abs(drawn_energy - leg_energy[rows_flex])) <= tol) {
      return(list(chunk = period_chunk, refusal = NULL, drawn = FALSE,
                  accepted = isTRUE(window$restating)))
    }

    request <- leg_energy[stretch]
    request[rows_flex - first_row + 1] <- drawn_energy
  }

  # -------------------------------------------------------------
  # 3. The Recovery Phase
  # The steps of the Recovery Phase are corrected so that the leg
  # can be carried out until the close of the control horizon. The
  # correction gives back what the window took and stops where the
  # leg is back on the energy it had stored before the window, its
  # reference. With the alternative plan, the target is that energy at
  # the end of the Recovery Phase.
  # -------------------------------------------------------------
  {
    rows_recovery <- rows[window$phase[-1] == 3L]
    steps_recovery <- rows_recovery - first_row + 1

    target <- NULL
    if (identical(window$recovery, "plan") && length(rows_recovery) > 0) {
      target <- period_chunk[[paste0("Stored_energy",
                                     sfx)]][max(rows_recovery)]
    }

    # battery_recovery_correction is called to find the correction of
    # the Recovery Phase, if the leg needs it, and whether the leg can
    # be carried out until the close of the control horizon with it.
    correction <- battery_recovery_correction(
      stored_energy_start = period_chunk[[paste0("Stored_energy",
                                                  sfx)]][window$rows[1]],
      delta_t_h           = delta_t_h,
      base_request        = request,
      reference_energy    = period_chunk[[paste0("Stored_energy",
                                                  sfx)]][stretch],
      recovery_steps      = steps_recovery,
      check_steps         = seq_along(stretch),
      direction           = if (leg == "down") 1 else -1,
      target_energy       = target,
      battery             = asset$battery,
      bisection_steps     =
        parameters$control$flexibility_commitment_bisection_steps,
      tolerance           = tol
    )

    if (!correction$fits && !isTRUE(window$restating)) {
      # flex_refused is called to check the reason the window is
      # refused and to pair it with the chunk, handed back as it came
      # in.
      refused <- flex_refused(
        period_chunk = period_chunk,
        reason       = "no_recovery"
      )
      return(list(chunk = refused$chunk, refusal = refused$refusal,
                  drawn = FALSE))
    }
  }

  # -------------------------------------------------------------
  # 4. Draw the leg
  # The window is drawn with the request of the Commitment and
  # Neutral Phases and the corrected request of the Recovery Phase.
  # The rows after the window keep their electricity and carry the
  # difference of the stored energy.
  # -------------------------------------------------------------
  {
    in_window <- seq_along(rows)

    # battery_draw_leg is called to draw the leg over the rows of the
    # window, within the limits of the battery, and to carry the
    # difference of the stored energy to the rows after it.
    period_chunk <- battery_draw_leg(
      period_chunk   = period_chunk,
      leg            = leg,
      rows           = rows,
      energy_request = request[in_window] + correction$extra[in_window],
      asset          = asset
    )

    rm(list = c("sfx", "rows", "rows_flex", "first_row", "last_row", "tol",
                "leg_energy", "stretch", "delta_t_h", "drawn_energy", "request",
                "rows_recovery", "steps_recovery", "target", "correction",
                "in_window"))
  }

  return(list(chunk = period_chunk, refusal = NULL, drawn = TRUE))
}
