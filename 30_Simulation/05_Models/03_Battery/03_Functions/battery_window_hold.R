# -------------------------------------------------------------
# Function: battery_window_hold.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Holds, on the itinerary of one leg of a battery, the part of a
# flexibility window already sold that the system asks the battery to
# keep (system_hold_window()), and carries the leg out until the
# close of the control horizon. It is the operation window_hold of
# the type of model Battery (model_type_contract()).
# The leg of the battery follows the electricity it had, b (kWh of
# the system side, positive to charge). Holding moves it away from b
# in the rows of the Commitment Phase, by what the system asks
# (standing, kWh): downward the battery discharges that much more,
# upward it charges that much more. The window holds in three steps:
#   - The most the battery can hold. The request b minus standing
#     (downward) or b plus standing (upward) is run through the
#     battery with its limits (battery_trajectory()). What the
#     battery moves away from b on each row, after the limits cut the
#     request, is the hold, h.
#   - The factor of the hold. The leg is requested with b minus theta
#     times h (downward) or b plus theta times h (upward) on the rows
#     of the Commitment Phase, and b on the others. With theta = 1,
#     the leg is carried out when no step from the start of the
#     window to the close of the control horizon breaks a limit of
#     the battery (battery_free_trajectory()). If it does not, the
#     battery corrects its Recovery Phase as for a window it draws
#     (battery_recovery_correction()). If not even that carries the
#     leg out, or the window has no Recovery Phase, theta is the
#     largest factor, found by bisection (battery_factor_search()),
#     with which the leg can be carried out, with the correction or
#     without it. A battery never
#     refuses a window it holds: what it cannot hold is bought again
#     by the economic chain. If not even theta = 0 carries the leg
#     out, the battery holds nothing.
#   - The Recovery Phase. It is the one the hold asks (hold$recovery,
#     minimum or plan), with the same factor theta, because the hold
#     is the commitment and does not change with it. Without it, or
#     with minimum, the correction is the least that carries the leg
#     out. With plan, the battery buys or sells until it is back on
#     the energy the leg stored before the hold, or as far as its
#     power allows, never less than the least correction. In both,
#     the correction stops where the leg is back on the energy it
#     stored before the hold.
# The leg is drawn from the first row held to the last row of the
# Recovery Phase, or of the rows held when the window has none, and
# its stored energy keeps the difference that the hold left on the
# rows after it (battery_draw_leg()). The phases of the window are of
# the system, so the battery marks none.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. The view of the battery of the piece
#                  (see piece_asset_view()), with, for the itinerary
#                  of the leg, the columns time,
#                  Elec_charge_plan_flex_<leg>,
#                  Elec_discharge_plan_flex_<leg>,
#                  Elec_total_plan_flex_<leg> and
#                  Stored_energy_plan_flex_<leg>.
#   leg          : Character scalar, "down" or "up".
#   window_rows  : Integer vector. The rows of the Commitment Phase
#                  held. Row 1 is never held.
#   standing     : Numeric vector as long as the chunk has rows. The
#                  energy to hold on each row (kWh), not negative.
#   hold         : Named list. The window held:
#                  phase         - integer vector, one per row of the
#                                  chunk: the phase of the window on
#                                  the row (1 Commitment, 2 Neutral,
#                                  3 Recovery, 0 outside it).
#                  i_end_control - the row where the control horizon
#                                  closes.
#                  recovery      - minimum or plan; absent or NULL
#                                  for minimum.
#   parameters   : Named list. Reads
#                  parameters$control$
#                  flexibility_commitment_bisection_steps and
#                  parameters$computing$flex_energy_tol (kWh).
#   asset        : Named list. The parameters of the battery, its
#                  entry of parameters$assets.
# -------------------------------------------------------------
# Outputs
#   Data frame. The view with the leg of the battery drawn over the
#   rows of the hold, or untouched when the battery holds nothing.
# -------------------------------------------------------------
# Code outline
# 1. Read the window
# 2. The most the battery can hold
# 3. The factor of the hold and the Recovery Phase
# 4. Draw the leg
# -------------------------------------------------------------
# Usage instructions
# view <- battery_window_hold(
#   period_chunk = view,
#   leg          = "down",
#   window_rows  = 2:4,
#   standing     = need,
#   hold         = list(phase = phase, i_end_control = 12,
#                       recovery = NULL),
#   parameters   = parameters,
#   asset        = asset
# )
# -------------------------------------------------------------

battery_window_hold <- function(period_chunk,
                                leg,
                                window_rows,
                                standing,
                                hold,
                                parameters,
                                asset
                                ) {

  # -------------------------------------------------------------
  # 1. Read the window
  # The rows held are the rows of the window after its initial
  # condition. The Recovery Phase is the rows of phase 3 after them.
  # The stretch that is checked goes from the first row held to the
  # row where the control horizon closes, or to the last row of the
  # window if that is later.
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("battery_window_hold: leg must be \"down\" or \"up\"")
    }
    n_rows <- nrow(period_chunk)
    if (length(standing) != n_rows || length(hold$phase) != n_rows ||
        !is.numeric(hold$i_end_control) ||
        length(hold$i_end_control) != 1) {
      stop("battery_window_hold: standing and hold$phase must have one ",
           "value per row of the chunk, and hold$i_end_control one row")
    }
    if (!is.null(hold$recovery) &&
        !(length(hold$recovery) == 1 &&
          hold$recovery %in% c("minimum", "plan"))) {
      stop("battery_window_hold: hold$recovery must be \"minimum\" or ",
           "\"plan\" (", asset$asset_id, ")")
    }

    rows_held <- window_rows[window_rows > 1 & window_rows <= n_rows]
    if (length(rows_held) == 0) {
      return(period_chunk)
    }

    sfx          <- paste0("_plan_flex_", leg)
    tol          <- parameters$computing$flex_energy_tol
    first_row    <- min(rows_held)
    last_held    <- max(rows_held)
    rows_recovery <- which(hold$phase == 3L)
    rows_recovery <- rows_recovery[rows_recovery > last_held &
                                     rows_recovery <= n_rows]
    last_row     <- max(c(last_held, rows_recovery))
    stretch      <- first_row:min(max(hold$i_end_control, last_row), n_rows)
    time_sec     <- as.numeric(period_chunk$time)
    delta_all    <- (time_sec[stretch] - time_sec[stretch - 1]) / 3600
    leg_energy   <- period_chunk[[paste0("Elec_charge", sfx)]] -
      period_chunk[[paste0("Elec_discharge", sfx)]]
    energy_start <- period_chunk[[paste0("Stored_energy",
                                         sfx)]][first_row - 1]
    reference    <- period_chunk[[paste0("Stored_energy",
                                         sfx)]][stretch]
    sign_leg     <- if (leg == "down") -1 else 1
    ask          <- standing[rows_held]
    ask[is.na(ask)] <- 0
    ask          <- pmax(ask, 0)
    steps_held   <- rows_held - first_row + 1
    steps_recovery <- rows_recovery - first_row + 1

    rm(list = "time_sec")
  }

  # -------------------------------------------------------------
  # 2. The most the battery can hold
  # The request of the leg with what the system asks to hold is run
  # through the battery, which cuts it with its limits. What the
  # battery moves away from the electricity it had is the hold, on
  # each row.
  # -------------------------------------------------------------
  {
    request_most <- leg_energy[stretch]
    request_most[steps_held] <- request_most[steps_held] + sign_leg * ask
    up_to_held   <- seq_len(last_held - first_row + 1)

    # battery_trajectory is called to run the request through the
    # battery with its limits, from the energy the leg holds before
    # the first row held.
    most <- battery_trajectory(
      stored_energy_start = energy_start,
      delta_t_h           = delta_all[up_to_held],
      energy_request      = request_most[up_to_held],
      battery             = asset$battery
    )
    moved <- (most$charge - most$discharge)[steps_held]
    hold_energy <- pmax(sign_leg * (moved - leg_energy[rows_held]), 0)
    rm(list = c("request_most", "up_to_held", "most", "moved"))
  }

  # -------------------------------------------------------------
  # 3. The factor of the hold and the Recovery Phase
  # The correction of a factor is the least one that carries the leg
  # out, and it stops where the leg is back on the energy it had
  # stored before the hold, its reference. The factor 1 is used when
  # the leg can be carried out with it. Otherwise a bisection keeps
  # the factor that can, and a leg that not even the factor 0 carries
  # out holds nothing.
  # -------------------------------------------------------------
  {
    request_of <- function(factor) {
      request <- leg_energy[stretch]
      request[steps_held] <- request[steps_held] +
        sign_leg * factor * hold_energy
      return(request)
    }
    correct_of <- function(factor, target) {

      # battery_recovery_correction is called to find the correction of
      # the Recovery Phase for this factor, if the leg needs it, and
      # whether the leg can be carried out with it.
      return(battery_recovery_correction(
        stored_energy_start = energy_start,
        delta_t_h           = delta_all,
        base_request        = request_of(factor),
        reference_energy    = reference,
        recovery_steps      = steps_recovery,
        check_steps         = seq_along(stretch),
        direction           = if (leg == "down") 1 else -1,
        target_energy       = target,
        battery             = asset$battery,
        bisection_steps     =
          parameters$control$flexibility_commitment_bisection_steps,
        tolerance           = tol
      ))
    }

    # battery_factor_search is called to find the largest factor of
    # the hold with which the least correction of the Recovery Phase
    # carries the leg out until the close of the control horizon.
    search <- battery_factor_search(
      stored_energy_start = energy_start,
      delta_t_h           = delta_all,
      base_request        = leg_energy[stretch],
      reference_energy    = reference,
      factor_steps        = steps_held,
      factor_energy       = sign_leg * hold_energy,
      with_recovery       = TRUE,
      recovery_steps      = steps_recovery,
      direction           = if (leg == "down") 1 else -1,
      battery             = asset$battery,
      bisection_steps     =
        parameters$control$flexibility_commitment_bisection_steps,
      tolerance           = tol
    )
    if (!search$found) {
      rm(list = c("sfx", "tol", "first_row", "last_held", "rows_recovery",
                  "last_row", "stretch", "delta_all", "leg_energy",
                  "energy_start", "reference", "sign_leg", "ask",
                  "steps_held", "steps_recovery", "hold_energy", "request_of",
                  "correct_of", "search", "n_rows", "rows_held"))
      return(period_chunk)
    }
    theta <- search$factor
    rm(list = "search")

    target <- NULL
    if (identical(hold$recovery, "plan") && length(rows_recovery) > 0) {
      target <- period_chunk[[paste0("Stored_energy",
                                     sfx)]][max(rows_recovery)]
    }
    correction <- correct_of(theta, target)
  }

  # -------------------------------------------------------------
  # 4. Draw the leg
  # The leg is drawn from the first row held to the last row of the
  # window, within the limits of the battery. The rows after it keep
  # their electricity and carry the difference of the stored energy.
  # -------------------------------------------------------------
  {
    in_window <- seq_len(last_row - first_row + 1)

    # battery_draw_leg is called to draw the leg over the rows of the
    # window, within the limits of the battery, and to carry the
    # difference of the stored energy to the rows after it.
    period_chunk <- battery_draw_leg(
      period_chunk   = period_chunk,
      leg            = leg,
      rows           = first_row:last_row,
      energy_request = request_of(theta)[in_window] +
        correction$extra[in_window],
      asset          = asset
    )

    rm(list = c("sfx", "tol", "first_row", "last_held", "rows_recovery",
                "last_row", "stretch", "delta_all", "leg_energy",
                "energy_start", "reference", "sign_leg", "ask",
                "steps_held", "steps_recovery", "hold_energy", "request_of",
                "correct_of", "theta", "target", "correction", "in_window",
                "n_rows", "rows_held"))
  }

  return(period_chunk)
}
