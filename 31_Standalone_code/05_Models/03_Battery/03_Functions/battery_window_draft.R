# -------------------------------------------------------------
# Function: battery_window_draft.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Drafts the contribution of a battery to one flexibility window of
# the system, of one leg, downward or upward: the electricity of its
# Commitment Phase as drawn before the commitment margin, and the
# margin data it hands the system. It is the operation window_draft
# of the type of model Battery (model_type_contract()).
# The system fixes the window (system_flex_window()). The margin is
# one, of the set of assets that contribute to it, so the system
# first asks every asset for its draft, then applies the margin to
# the set (system_commitment_margin()), and only then lets each asset
# draw its contribution with what the margin left
# (battery_window_contribution()).
# -------------------------------------------------------------
# The shape of the contribution
# The leg of a battery follows the electricity it had before the
# window, b (kWh of the system side, positive to charge). The window
# moves it away from b in the rows of its Commitment Phase, towards
# the limit of the leg: the most the battery can give downward, -P_d
# times the duration of the row, and the most it can take upward, P_c
# times the duration of the row. With f the fraction of flexibility
# of the row, set by the system, and phi a factor of the battery
# between 0 and 1, the electricity of each row of the Commitment
# Phase is
#   e = b + phi * f * (limit - b)
# It is the shape of the contribution of a building, in electricity.
# phi is the largest factor with which the leg can be carried out
# until the end of the Neutral Phase: the energy it stores, with the
# request e in the Commitment Phase and b in the Neutral Phase, from
# the energy it has before the window, breaks no limit of the battery
# (battery_free_trajectory()). phi is 1 when the leg can be carried
# out at the limit, and it is found by bisection otherwise
# (battery_factor_search()). If not even phi = 0 can be carried out,
# or the window moves less than the energy tolerance, the battery has
# nothing to offer.
# A window that restates a commitment already sold (window$restating)
# is never refused by the battery for its Recovery Phase: the window
# is drawn as the plan allows, and what the battery does not reach is
# bought again by the economic chain. So phi is the largest factor
# with which the leg can be carried out until the close of the control
# horizon with the least correction of the Recovery Phase
# (battery_recovery_correction()), whether that correction is needed
# or not. When the window has no Recovery Phase in the chunk, because
# it is cut by its end, that is the largest factor with which the leg
# is carried out without correction.
# A battery that has nothing to offer on a window that restates a
# commitment accepts it with no energy (accepted): it does not refuse
# it, and the system does not ask it to hold what the other assets
# do not reach of it, which is bought again.
# The margin data are those of the rows of the guard zone: the
# electricity before the window, the one drafted and the limit of the
# leg. The quantity the margin scales is the electricity itself.
# -------------------------------------------------------------
# Inputs
#   leg          : Character scalar, "down" or "up". The leg the
#                  window belongs to.
#   period_chunk : Data frame. The view of the battery of the piece
#                  (see piece_asset_view()), with the phases of the
#                  window already written by the system and, for the
#                  itinerary of the leg, the columns time,
#                  Elec_charge_plan_flex_<leg>,
#                  Elec_discharge_plan_flex_<leg> and
#                  Stored_energy_plan_flex_<leg>.
#   window       : Named list. The window the system fixed, as
#                  system_flex_window() builds it. Reads rows,
#                  phase, commitment, delta_t_h, guard_row,
#                  fraction_row and, when the window restates a
#                  commitment already sold, restating and
#                  i_end_control.
#   parameters   : Named list. Reads
#                  parameters$control$
#                  flexibility_commitment_bisection_steps and
#                  parameters$computing$flex_energy_tol (kWh).
#   asset        : Named list. The parameters of the battery, its
#                  entry of parameters$assets.
# -------------------------------------------------------------
# Outputs
#   A named list, the draft of the battery:
#   drawn   : Logical scalar. FALSE when the battery has nothing to
#             offer on the window; the other fields but accepted are
#             then absent.
#   accepted : Logical scalar, only when drawn is FALSE. TRUE when
#             the window restates a commitment already sold: the
#             battery accepts it with no energy.
#   profile : Named list with the vector Elec (kWh), the electricity
#             of each row of the Commitment Phase before the margin.
#   margin  : The margin data of the battery on the rows of the guard
#             zone, or NULL when no row is in the guard zone: plan
#             and profile, lists with the vector Elec, and
#             limit_energy, the electricity of each row at the limit
#             of the leg (kWh).
#   phi     : Numeric scalar. The factor of the battery.
# -------------------------------------------------------------
# Code outline
# 1. Read the window
# 2. The electricity at the limit of the leg
# 3. The factor of the battery
# 4. The draft
# -------------------------------------------------------------
# Usage instructions
# draft <- battery_window_draft(leg          = "down",
#                               period_chunk = view,
#                               window       = window,
#                               parameters   = parameters,
#                               asset        = asset)
# -------------------------------------------------------------

battery_window_draft <- function(leg,
                                 period_chunk,
                                 window,
                                 parameters,
                                 asset
                                 ) {

  # -------------------------------------------------------------
  # 1. Read the window
  # The rows of the Commitment Phase, the electricity the leg had
  # on them, and the stretch that goes from the row after the
  # initial condition to the end of the Neutral Phase, on which the
  # factor is tested.
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("battery_window_draft: leg must be \"down\" or \"up\"")
    }
    if (length(window$commitment) == 0) {
      return(list(drawn = FALSE))
    }

    sfx        <- paste0("_plan_flex_", leg)
    battery    <- asset$battery
    rows_flex  <- window$rows[window$commitment]
    leg_energy <- period_chunk[[paste0("Elec_charge", sfx)]] -
      period_chunk[[paste0("Elec_discharge", sfx)]]
    before     <- leg_energy[rows_flex]

    rows_check <- window$rows[-1][window$phase[-1] %in% c(1L, 2L)]
    time_sec   <- as.numeric(period_chunk$time)
    delta_check <- (time_sec[rows_check] - time_sec[rows_check - 1]) / 3600
    base_check  <- leg_energy[rows_check]
    reference_check <- period_chunk[[paste0("Stored_energy",
                                            sfx)]][rows_check]
    flex_in_check <- match(rows_flex, rows_check)
    energy_start  <- period_chunk[[paste0("Stored_energy",
                                          sfx)]][window$rows[1]]
    tol           <- parameters$computing$flex_energy_tol

    # A window that restates a commitment is checked until the close of
    # the control horizon, with the correction of its Recovery Phase.
    restating <- isTRUE(window$restating)
    if (restating) {
      rows_after <- window$rows[-1]
      if (any(diff(rows_after) != 1)) {
        stop("battery_window_draft: the rows of the window after its ",
             "initial condition must be consecutive")
      }
      stretch <- rows_after[1]:min(max(window$i_end_control,
                                       rows_after[length(rows_after)]),
                                   nrow(period_chunk))
      delta_stretch   <- (time_sec[stretch] - time_sec[stretch - 1]) / 3600
      base_stretch    <- leg_energy[stretch]
      reference_stretch <- period_chunk[[paste0("Stored_energy",
                                                sfx)]][stretch]
      flex_in_stretch <- rows_flex - rows_after[1] + 1
      steps_recovery  <- rows_after[window$phase[-1] == 3L] -
        rows_after[1] + 1
      rm(list = c("rows_after", "stretch"))
    }

    rm(list = c("time_sec", "leg_energy"))
  }

  # -------------------------------------------------------------
  # 2. The electricity at the limit of the leg
  # -------------------------------------------------------------
  {
    limit_energy <- if (leg == "down") {
      -battery$Discharge_power_max * window$delta_t_h
    } else {
      battery$Charge_power_max * window$delta_t_h
    }
    reach <- window$fraction_row * (limit_energy - before)
  }

  # -------------------------------------------------------------
  # 3. The factor of the battery
  # The leg can be carried out with a factor when no step of the
  # stretch breaks a limit. If the factor 1 can, it is 1. Otherwise
  # a bisection keeps the factor that can, and a window that not even
  # the factor 0 can carry out has nothing to offer. A window that
  # restates a commitment is carried out when the least correction of
  # its Recovery Phase keeps the leg inside the limits until the close
  # of the control horizon.
  # A window that restates a commitment and has nothing to offer is
  # accepted with no energy.
  # -------------------------------------------------------------
  {
    # battery_factor_search is called to find the largest factor with
    # which the leg is carried out: until the end of the Neutral Phase
    # with no correction for a new window, and until the close of the
    # control horizon with the least correction of the Recovery Phase
    # for a window that restates a commitment.
    search <- if (restating) {
      battery_factor_search(
        stored_energy_start = energy_start,
        delta_t_h           = delta_stretch,
        base_request        = base_stretch,
        reference_energy    = reference_stretch,
        factor_steps        = flex_in_stretch,
        factor_energy       = reach,
        with_recovery       = TRUE,
        recovery_steps      = steps_recovery,
        direction           = if (leg == "down") 1 else -1,
        battery             = battery,
        bisection_steps     =
          parameters$control$flexibility_commitment_bisection_steps,
        tolerance           = tol
      )
    } else {
      battery_factor_search(
        stored_energy_start = energy_start,
        delta_t_h           = delta_check,
        base_request        = base_check,
        reference_energy    = reference_check,
        factor_steps        = flex_in_check,
        factor_energy       = reach,
        with_recovery       = FALSE,
        recovery_steps      = integer(0),
        direction           = if (leg == "down") 1 else -1,
        battery             = battery,
        bisection_steps     =
          parameters$control$flexibility_commitment_bisection_steps,
        tolerance           = tol
      )
    }

    if (!search$found) {
      rm(list = c("sfx", "battery", "rows_flex", "before", "rows_check",
                  "delta_check", "base_check", "reference_check",
                  "flex_in_check", "energy_start", "tol", "limit_energy",
                  "reach", "search"))
      if (restating) {
        rm(list = c("delta_stretch", "base_stretch", "reference_stretch",
                    "flex_in_stretch", "steps_recovery"))
      }
      accepted <- restating
      rm(list = "restating")
      return(list(drawn = FALSE, accepted = accepted))
    }
    phi <- search$factor
    rm(list = "search")
  }

  # -------------------------------------------------------------
  # 4. The draft
  # A window that moves the leg by no more than the energy tolerance
  # in every row has nothing to offer. The margin data are those of
  # the rows of the guard zone.
  # -------------------------------------------------------------
  {
    drafted <- before + phi * reach

    if (max(abs(drafted - before)) <= tol) {
      drawn <- FALSE
    } else {
      drawn <- TRUE
    }

    margin <- if (any(window$guard_row)) {
      list(plan         = list(Elec = before[window$guard_row]),
           profile      = list(Elec = drafted[window$guard_row]),
           limit_energy = limit_energy[window$guard_row])
    } else {
      NULL
    }

    rm(list = c("sfx", "battery", "rows_flex", "before", "rows_check",
                "delta_check", "base_check", "reference_check",
                "flex_in_check", "energy_start", "tol", "limit_energy",
                "reach"))
    if (restating) {
      rm(list = c("delta_stretch", "base_stretch", "reference_stretch",
                  "flex_in_stretch", "steps_recovery"))
    }
    accepted <- restating
    rm(list = "restating")
  }

  if (!drawn) {
    return(list(drawn = FALSE, accepted = accepted))
  }

  return(list(drawn   = TRUE,
              profile = list(Elec = drafted),
              margin  = margin,
              phi     = phi))
}
