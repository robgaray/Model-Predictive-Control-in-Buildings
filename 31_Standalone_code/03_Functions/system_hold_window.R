# -------------------------------------------------------------
# Function: system_hold_window.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Holds, within the limits of the equipment of some assets, the part
# of a flexibility window already sold that the window of the system
# does not deliver over the new plan. It is called when a window is
# restated (derive_flex_itineraries()) and some assets refuse to
# redraw it.
# -------------------------------------------------------------
# Who holds the window
# The commitment of a window is that of the net, and how the assets
# shared it is not stored. When it is restated, the assets that can
# redraw it cover what was sold with their common fraction of
# flexibility (system_flex_window()). What they do not deliver is
# held by the assets that refuse the window, the holders, each within
# the limits of its equipment. What is still missing is not held: the
# commitment the itineraries carry is then smaller than the one sold,
# and the economic chain books the difference as a re-purchase.
# When no asset redraws the window, the holders are all the assets,
# and what they hold is the whole commitment that stands.
# -------------------------------------------------------------
# The share of each holder
#   - A single holder holds what is missing, as far as its equipment
#     allows (the operation window_hold of its type of model).
#   - Several holders share it in proportion to what each one can
#     hold on each row (the operation hold_room of its type of model):
#     when they can hold all of it together, each one holds the same
#     fraction of its room; otherwise each one holds all its room.
# Each holder works in its view of the piece (piece_asset_view()) and
# writes its share on its electricity itinerary of the leg there. That
# share comes back into the table of the holder, with the net
# electricity of the system summed again (piece_absorb_asset()). The
# phases of a window are of the system: it marks the rows held as
# Commitment Phase in its own table.
# -------------------------------------------------------------
# The Recovery Phase of a window held
# A window that is held keeps its Neutral and Recovery Phases after
# its Commitment Phase. An asset that stores energy, a battery, also
# has to leave its leg realizable until the close of the control
# horizon, so it corrects the Recovery Phase of the window it holds
# (the operation window_hold of its type of model). For that, each
# holder receives the window held: its phases, the row where the
# control horizon closes, and, when it offers alternatives for the
# Recovery Phase, the one to draw it with.
# The system marks the Neutral and Recovery Phases of the window in
# its own table when one of the assets that offer alternatives holds
# energy in the rows held, because the cost of the energy the asset
# buys or sells in the Recovery Phase is read on the rows marked. An
# asset that offers none leaves the table as it was.
# When the valuation is given and one of those assets holds energy,
# the window is held again with each alternative of the Recovery
# Phase, with the same shares, and choose_recovery() keeps the piece
# with the best reward. An alternative that leaves the electricity of
# every asset as the first one did is not valued.
# -------------------------------------------------------------
# Inputs
#   piece        : List. The piece being derived, with the windows
#                  already restated on it.
#   leg          : Character scalar, "down" or "up".
#   window_rows  : Integer vector. The rows of the Commitment Phase
#                  held. Row 1 is the initial state of the piece and is
#                  never held.
#   need         : Numeric vector as long as the piece has rows. The
#                  energy to hold on each row, in kWh.
#   holders      : Character vector. The asset_id of each asset that
#                  holds, names of parameters$assets.
#   parameters   : Named list. Model and control parameters. Reads the
#                  asset registry (parameters$assets), whose entries
#                  are handed to the operations of their types of
#                  model, and what those operations read,
#                  parameters$joined_cols, the order of the columns of
#                  the view of a holder, and
#                  parameters$computing$flex_energy_tol (kWh).
#   hold         : Named list. The window held:
#                  phase         - integer vector, one per row of the
#                                  piece: the phase of the window on
#                                  the row (1 Commitment, 2 Neutral,
#                                  3 Recovery, 0 outside it).
#                  i_end_control - the row where the control horizon
#                                  closes in the piece.
#   recovery_valuation : Named list or NULL (default NULL).
#                  build_recovery_valuation() gives it: the
#                  alternatives for the Recovery Phase and what is
#                  needed to value them. With NULL nothing is chosen.
# -------------------------------------------------------------
# Outputs
#   The piece with the electricity itinerary of the leg of each holder
#   carrying its share over window_rows in its table, the net
#   electricity of the system summed again, and Flex_phase_<leg>_plan
#   of the table of the system set to 1 over the rows held and, when
#   an asset that offers alternatives for the Recovery Phase holds
#   energy there, to the phase of the window on its Neutral and
#   Recovery rows.
# -------------------------------------------------------------
# Code outline
# 1. Check the holders
# 2. The share of each holder
# 3. Each holder holds its share
# 4. The system marks the rows held
# 5. The Recovery Phase of the window held
# -------------------------------------------------------------
# Usage instructions
# piece <- system_hold_window(piece       = piece,
#                             leg         = "up",
#                             window_rows = rows,
#                             need        = need,
#                             holders     = names(parameters$assets),
#                             parameters  = parameters,
#                             hold        = list(phase = phase,
#                                                i_end_control = 40))
# -------------------------------------------------------------

system_hold_window <- function(piece,
                               leg,
                               window_rows,
                               need,
                               holders,
                               parameters,
                               hold,
                               recovery_valuation = NULL) {

  # -------------------------------------------------------------
  # 1. Check the holders
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("system_hold_window: leg must be 'down' or 'up'")
    }
    if (!is.character(holders) || length(holders) == 0 ||
        !all(holders %in% names(parameters$assets))) {
      stop("system_hold_window: holders must name assets of the asset ",
           "registry")
    }
    if (length(need) != nrow(piece$system)) {
      stop("system_hold_window: need must have one value per row of ",
           "the piece")
    }
    if (length(hold$phase) != nrow(piece$system) ||
        !is.numeric(hold$i_end_control) || length(hold$i_end_control) != 1) {
      stop("system_hold_window: hold must hold one phase per row of the ",
           "piece and the row where the control horizon closes")
    }

    # model_type_contract is called for each holder, to take the
    # operations of its type of model through which it holds.
    models <- lapply(holders, function(one_holder) {
      model_type_contract(parameters$assets[[one_holder]]$asset_type)
    })
    names(models) <- holders

    # The operation recovery_choices of each holder is called to tell
    # which of them offer alternatives for the Recovery Phase.
    offering <- holders[vapply(holders, function(one_holder) {
      !is.null(models[[one_holder]]$recovery_choices(
        parameters$assets[[one_holder]]))
    }, logical(1))]

    # The view of each holder is taken once: what another holder holds
    # changes only its own table and the net of the system, which the
    # view of a holder takes from its own table.
    column_order <- parameters$joined_cols
    views <- lapply(setNames(holders, holders), function(one_holder) {
      # piece_asset_view is called to take the view of the holder, on
      # which it says what it can hold and holds its share.
      piece_asset_view(
        piece        = piece,
        asset_id     = one_holder,
        column_order = column_order
      )
    })
  }

  # -------------------------------------------------------------
  # 2. The share of each holder
  # A single holder receives the whole need, and its own operation
  # keeps it within its equipment. Several holders share it on each
  # row in proportion to their room (see "The share of each holder"
  # above).
  # -------------------------------------------------------------
  {
    shares <- list()
    if (length(holders) == 1) {
      shares[[holders]] <- need
    } else {
      rows   <- window_rows[window_rows > 1 & window_rows <= nrow(piece$system)]
      wanted <- need[rows]
      wanted[is.na(wanted)] <- 0
      wanted <- pmax(wanted, 0)

      rooms <- list()
      for (CONT_001 in holders) {
        # The operation hold_room of the model (building_hold_room()
        # for a building) is called for the most the holder can hold
        # on each row.
        rooms[[CONT_001]] <- models[[CONT_001]]$hold_room(
          period_chunk = views[[CONT_001]],
          leg          = leg,
          window_rows  = rows,
          parameters   = parameters,
          asset        = parameters$assets[[CONT_001]]
        )
      }
      total_room <- Reduce(`+`, rooms)
      scale      <- ifelse(total_room > wanted, wanted / total_room, 1)

      for (CONT_001 in holders) {
        one_share       <- numeric(nrow(piece$system))
        one_share[rows] <- rooms[[CONT_001]] * scale
        shares[[CONT_001]] <- one_share
        rm(list = "one_share")
      }
      rm(list = c("CONT_001", "rows", "wanted", "rooms", "total_room", "scale"))
    }
  }

  # -------------------------------------------------------------
  # 3. Each holder holds its share
  # -------------------------------------------------------------
  {
    for (CONT_002 in holders) {
      # The operation window_hold of the model (hold_standing_window()
      # for a building) is called to write the share of the holder on
      # its electricity itinerary of the leg, within the limits of its
      # equipment.
      view <- models[[CONT_002]]$window_hold(
        period_chunk = views[[CONT_002]],
        leg          = leg,
        window_rows  = window_rows,
        standing     = shares[[CONT_002]],
        hold         = hold,
        parameters   = parameters,
        asset        = parameters$assets[[CONT_002]]
      )

      # piece_absorb_asset is called to take the share held back into
      # the table of the holder, and to sum the net electricity of the
      # system again. The phases the holder marks in its view do not
      # come back: the system marks them in its table below.
      piece <- piece_absorb_asset(
        piece    = piece,
        asset_id = CONT_002,
        view     = view
      )
    }
    rm(list = c("CONT_002", "view", "column_order"))
  }

  # -------------------------------------------------------------
  # 4. The system marks the rows held
  # The phases of a window are of the system: the rows held are marked
  # as Commitment Phase in its table, over the rows of the piece after
  # its initial condition. When an asset that offers alternatives for
  # the Recovery Phase holds more than flex_energy_tol there, the
  # rows of the window after the last row held, that carry its
  # Neutral or Recovery Phase and no phase of the table yet, are
  # marked too.
  # -------------------------------------------------------------
  {
    held_rows <- window_rows[window_rows > 1 & window_rows <= nrow(piece$system)]
    if (length(held_rows) > 0) {
      phase_col <- paste0("Flex_phase_", leg, "_plan")
      piece$system[[phase_col]][held_rows] <- 1L

      held_energy <- vapply(offering, function(one_holder) {
        asset_df <- piece$assets[[one_holder]]$df
        sum(abs(asset_df[[paste0("Elec_total_plan_flex_", leg)]][held_rows] -
                  asset_df$Elec_total_plan[held_rows]), na.rm = TRUE)
      }, numeric(1))
      if (any(held_energy > parameters$computing$flex_energy_tol)) {
        after_rows <- which(hold$phase %in% c(2L, 3L) &
                              seq_along(hold$phase) > max(held_rows) &
                              piece$system[[phase_col]] == 0)
        piece$system[[phase_col]][after_rows] <-
          as.integer(hold$phase[after_rows])
        rm(list = "after_rows")
      }
      rm(list = c("phase_col", "held_energy"))
    }
    rm(list = "held_rows")
  }

  # -------------------------------------------------------------
  # 5. The Recovery Phase of the window held
  # The assets that offer alternatives and hold energy in the rows
  # held hold again with each alternative, from the view they had
  # before holding and with the same share, on a copy of the piece
  # that is marked already. The piece with the best reward is kept.
  # -------------------------------------------------------------
  {
    choosing <- character(0)
    if (!is.null(recovery_valuation)) {
      choosing <- intersect(offering, recovery_valuation$choosers)
      rows_held <- window_rows[window_rows > 1 &
                                 window_rows <= nrow(piece$system)]
      leg_electricity <- paste0("Elec_total_plan_flex_", leg)
      tol_energy      <- parameters$computing$flex_energy_tol
      choosing <- choosing[vapply(choosing, function(one_holder) {
        asset_df <- piece$assets[[one_holder]]$df
        sum(abs(asset_df[[leg_electricity]][rows_held] -
                  asset_df$Elec_total_plan[rows_held]),
            na.rm = TRUE) > tol_energy
      }, logical(1))]
    }

    if (length(choosing) > 0) {
      alternatives <- list()
      for (CONT_003 in recovery_valuation$choices[-1]) {
        hold_alternative          <- hold
        hold_alternative$recovery <- CONT_003
        piece_alternative         <- piece
        changed                   <- FALSE

        for (CONT_004 in choosing) {
          # The operation window_hold of the model is called to hold
          # the same share again, with this alternative of the
          # Recovery Phase.
          view <- models[[CONT_004]]$window_hold(
            period_chunk = views[[CONT_004]],
            leg          = leg,
            window_rows  = window_rows,
            standing     = shares[[CONT_004]],
            hold         = hold_alternative,
            parameters   = parameters,
            asset        = parameters$assets[[CONT_004]]
          )
          changed <- changed ||
            max(abs(view[[leg_electricity]] -
                      piece$assets[[CONT_004]]$df[[leg_electricity]]),
                na.rm = TRUE) > tol_energy

          # piece_absorb_asset is called to take the share held with
          # this alternative into the table of the holder, and to sum
          # the net electricity of the system again.
          piece_alternative <- piece_absorb_asset(
            piece    = piece_alternative,
            asset_id = CONT_004,
            view     = view
          )
          rm(list = "view")
        }

        if (changed) {
          alternatives[[length(alternatives) + 1]] <- piece_alternative
        }
        rm(list = c("hold_alternative", "piece_alternative", "changed",
                    "CONT_004"))
      }

      if (length(alternatives) > 0) {
        # choose_recovery is called to choose, among the window held
        # with the first alternative and with the others, the one with
        # the best reward on this leg.
        chosen <- choose_recovery(
          pieces             = c(list(piece), alternatives),
          leg                = leg,
          parameters         = parameters,
          recovery_valuation = recovery_valuation
        )
        if (chosen$index > 1) {
          piece <- alternatives[[chosen$index - 1]]
        }
        rm(list = "chosen")
      }
      rm(list = c("alternatives", "CONT_003"))
    }
    rm(list = intersect(c("rows_held", "leg_electricity", "tol_energy"),
                        ls()))
    rm(list = c("choosing", "shares", "models", "views", "offering"))
  }

  return(piece)
}
