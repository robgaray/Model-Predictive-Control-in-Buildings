# -------------------------------------------------------------
# Function: system_flex_frame.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Prepares the frame of one flexibility window of the system, on one
# leg: everything system_flex_window() needs that does not depend on
# the fraction of flexibility of the window, nor on the thermal system
# of a restated upward window. The frame is:
#   - the rows of the window, its three phases, the rows of its
#     Commitment Phase, their time steps and which of them are in the
#     guard zone;
#   - the piece with the phases of the window written in the table of
#     the system;
#   - the operations of the type of model of every asset
#     (model_type_contract()) and its view of that piece
#     (piece_asset_view()).
# When a window already sold is restated (derive_flex_itineraries()),
# system_flex_window() is called many times for the same window, with
# a different fraction each time, to find the fraction that keeps the
# commitment. The frame is prepared once for the window and handed to
# every call, so that this work is not repeated. A call without a
# frame prepares its own, so the window is the same either way.
# The rows, the phases and the bounds of the window follow the rules
# described in the header of system_flex_window().
# -------------------------------------------------------------
# Inputs
#   leg                : Character scalar, "down" or "up". The leg the
#                        window belongs to.
#   piece              : List. The piece of the planning period, as
#                        system_flex_window() receives it.
#   parameters         : Named list. Model and control parameters.
#                        Reads:
#                          - parameters$assets, the asset registry
#                          - parameters$control$neutral_phase_timespan
#                            and recovery_phase_timespan (h)
#                          - parameters$computing$main_resolution_sec
#                            (s), the time step
#                          - parameters$joined_cols, the order of the
#                            columns of the view of an asset
#   simulation_control : Named list. Simulation control object. Reads:
#                          - indexes_local$i_flex and
#                            indexes_local$i_end_control
#                          - flexibility$commitment_phase_length
#                          - flexibility$restating and
#                            flexibility$restatement_mode, optional
#                        as described in the header of
#                        system_flex_window(). It does not read the
#                        fractions of flexibility nor hvac_up.
# -------------------------------------------------------------
# Outputs
#   A named list with:
#   done         : Named list or NULL. When the window cannot be built
#                  whatever its fraction, the answer of
#                  system_flex_window() (piece, refusal and
#                  contributors): a new window that does not fit by the
#                  close of the control horizon ("no_room"), or an
#                  upward window with no row in its Commitment Phase.
#                  NULL otherwise, and then the other elements hold
#                  the frame. When done is not NULL, they are absent.
#   window       : Named list. What the system hands each asset, but
#                  the fraction of each row and hvac_up:
#                    - i_flex, the first row of the Commitment Phase
#                    - rows and phase, the rows of the window and the
#                      phase code of each (0 for the initial
#                      condition)
#                    - commitment, the positions in rows of the
#                      Commitment Phase
#                    - delta_t_h, the time step of each of them (h)
#                    - guard_row, whether each of them is in the guard
#                      zone
#                    - restating, whether the window is restated
#                    - i_end_control, the last row of the control
#                      horizon in the piece
#   window_piece : List. The piece with Flex_phase_<leg>_plan of the
#                  table of the system set to the phase of each row of
#                  the window after its initial condition.
#   models       : Named list, by asset_id. The operations of the type
#                  of model of each asset.
#   views        : Named list, by asset_id. The view of each asset of
#                  window_piece.
# -------------------------------------------------------------
# Code outline
# 1. Read the window
# 2. Bound the window by the control horizon
# 3. Take the rows of the window
# 4. The Commitment Phase
# 5. Mark the three phases
# 6. The operations and the view of each asset
# -------------------------------------------------------------
# Usage instructions
# frame <- system_flex_frame(leg                = "down",
#                            piece              = piece,
#                            parameters         = parameters,
#                            simulation_control = simulation_control)
# built <- system_flex_window(leg                = "down",
#                             piece              = piece,
#                             parameters         = parameters,
#                             simulation_control = simulation_control,
#                             frame              = frame)
# -------------------------------------------------------------

system_flex_frame <- function(leg,
                              piece,
                              parameters,
                              simulation_control
                              ) {

  # -------------------------------------------------------------
  # 1. Read the window
  # The leg, the placement and length of the window, and whether it
  # is a new sale or a restatement.
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("system_flex_frame: leg must be \"down\" or \"up\"")
    }

    i_flex                  <- simulation_control$indexes_local$i_flex
    commitment_phase_length <- simulation_control$flexibility$commitment_phase_length

    neutral_phase_timespan  <- parameters$control$neutral_phase_timespan
    recovery_phase_timespan <- parameters$control$recovery_phase_timespan

    total_window_h <- commitment_phase_length + neutral_phase_timespan +
      recovery_phase_timespan

    if (!is.numeric(i_flex) || length(i_flex) != 1 ||
        i_flex < 2 || i_flex > nrow(piece$system)) {
      stop("system_flex_frame: indexes_local$i_flex must be a single ",
           "row of the piece from 2 on, because the row before it is ",
           "the initial condition of the window")
    }

    restating <- isTRUE(simulation_control$flexibility$restating)

    # The phases of the window are in phase_col.
    phase_col <- paste0("Flex_phase_", leg, "_plan")
  }

  # -------------------------------------------------------------
  # 2. Bound the window by the control horizon
  # A new window has to fit whole inside the CONTROL HORIZON, not
  # merely inside the piece. A window whose tail falls beyond the
  # control horizon is never written to Main_df: the rows that fall
  # outside are simply dropped, so the optimizer would count on an
  # energy that is then not recorded anywhere.
  # A window that is being RE-STATED is not a new sale: the energy was
  # already sold by an earlier market and what is left to do is to
  # carry it forward, wherever it falls. The restatement mode says
  # which rows of a restated Commitment Phase are in the guard zone
  # (see derive_flex_itineraries()): with "guard", the rows up to
  # i_end_control; with "projection", none. The rows out of the guard
  # zone take their own fraction, flexibility_projected, which
  # system_flex_window() gives them.
  # -------------------------------------------------------------
  {
    time_at_i_flex <- piece$system$time[i_flex]

    i_end_control <- simulation_control$indexes_local$i_end_control
    if (is.null(i_end_control) || !is.numeric(i_end_control) ||
        i_end_control < 1) {
      stop("system_flex_frame: simulation_control$indexes_local$",
           "i_end_control is mandatory and must be a row index of ",
           "the piece")
    }
    i_end_control <- min(as.integer(i_end_control), nrow(piece$system))
    time_at_end   <- piece$system$time[i_end_control]

    restatement_mode <- simulation_control$flexibility$restatement_mode
    if (is.null(restatement_mode)) {
      restatement_mode <- "guard"
    }

    if (!restating) {
      # A row holds the energy of the time step that ends at it, so the
      # window's first time step ends at i_flex and starts one step
      # earlier, and its last one may end at i_end_control itself.
      room_sec <- as.numeric(time_at_end) - as.numeric(time_at_i_flex) +
        parameters$computing$main_resolution_sec
      if (room_sec < total_window_h * 3600) {
        # flex_refused is called to check the reason the window is
        # refused and to pair it with the piece, handed back as it came
        # in.
        refused <- flex_refused(
          period_chunk = piece,
          reason       = "no_room"
        )
        return(list(done = list(piece        = refused$chunk,
                                refusal      = refused$refusal,
                                contributors = character(0))))
      }
      rm(list = "room_sec")
    }
    rm(list = "time_at_end")
  }

  # -------------------------------------------------------------
  # 3. Take the rows of the window
  # The initial condition, the row before i_flex, and then the rows
  # whose instant is in [t(i_flex), t(i_flex) + total_window_h): the
  # time steps of the three phases.
  # -------------------------------------------------------------
  {
    end_time_window <- time_at_i_flex + total_window_h * 3600
    window_rows     <- c(i_flex - 1L,
                         which(piece$system$time >= time_at_i_flex &
                                 piece$system$time <  end_time_window))
    window_time     <- piece$system$time[window_rows]
    rm(list = c("end_time_window", "total_window_h"))
  }

  # -------------------------------------------------------------
  # 4. The Commitment Phase
  # The Commitment Phase is the rows in the HALF-OPEN interval
  # [t0, t0 + L), with t0 the instant of i_flex. Closed on the right, a
  # window of L hours would reach into the market slot that begins at
  # t0 + L, and reconstruct_flex_phases() would then promote that whole
  # slot, so the window would grow by one slot at every market. The
  # initial condition, before t0, is in no phase.
  # For each row of the Commitment Phase, the system gives every asset
  # the same three things:
  #   - its time step, in HOURS, measured back to the row before,
  #     which is always a row of the window: the first row of the
  #     Commitment Phase follows the initial condition. A power (kW)
  #     times it is then an energy in kWh, directly comparable with
  #     the energy columns;
  #   - whether it is in the guard zone. Every row of a new sale is;
  #   - its fraction of flexibility, which system_flex_window() gives
  #     it, because it changes from one call to the next.
  # -------------------------------------------------------------
  {
    end_time_flex    <- time_at_i_flex + commitment_phase_length * 3600
    commitment_index <- which(window_time >= time_at_i_flex &
                                window_time <  end_time_flex)

    # An upward window with no row to raise has nothing to offer.
    if (length(commitment_index) == 0 && leg == "up") {
      return(list(done = list(piece = piece, refusal = NULL,
                              contributors = character(0))))
    }

    # as.numeric() on POSIXct gives seconds, so /3600 converts to
    # hours.
    window_sec <- as.numeric(window_time)
    delta_t_h  <- (window_sec[commitment_index] -
                     window_sec[commitment_index - 1]) / 3600
    rm(list = "window_sec")

    guard_row <- if (!restating) {
      rep(TRUE, length(commitment_index))
    } else if (restatement_mode == "guard") {
      window_rows[commitment_index] <= i_end_control
    } else {
      rep(FALSE, length(commitment_index))
    }

    rm(list = c("end_time_flex", "restatement_mode"))
  }

  # -------------------------------------------------------------
  # 5. Mark the three phases
  # With L the Commitment Phase, R the Neutral Phase and S the
  # Recovery Phase, and t0 the instant of i_flex:
  #   1 Commitment - [t0, t0 + L)
  #   2 Neutral    - [t0 + L, t0 + L + R)
  #   3 Recovery   - [t0 + L + R, t0 + L + R + S)
  # Half-open on the right, as the Commitment Phase above: the three
  # phases tile the window without any of them reaching into the slot
  # where the next one starts. The initial condition takes 0: it is
  # in no phase, and it is not written in the piece.
  # Only phase 1 carries an economic commitment: reward_function()
  # bounds Elec_flex_<leg>_plan to it, so that the rebound of the
  # Neutral and Recovery Phases is not sold as flexibility of the
  # opposite sign. The phase code is what lets reward_function() and
  # compute_recovery_energy_cost() agree on which rows belong to the
  # window without recomputing it.
  # The phases of the window are of the system and are written in its
  # table. The view of each asset carries them, because the technical
  # rules of an asset judge every window of the leg at once.
  # -------------------------------------------------------------
  {
    end_time_commitment <- time_at_i_flex + commitment_phase_length * 3600
    end_time_neutral    <- time_at_i_flex +
      (commitment_phase_length + neutral_phase_timespan) * 3600

    window_phase <- ifelse(window_time < end_time_commitment, 1L,
                    ifelse(window_time < end_time_neutral,    2L, 3L))
    window_phase[1] <- 0L

    window_piece <- piece
    window_piece$system[[phase_col]][window_rows[-1]] <- window_phase[-1]

    # What the system hands each asset, but the fraction of each row
    # and the thermal system of a restated upward window: the rows and
    # phases of the window, and the time step and guard zone of each
    # row of its Commitment Phase.
    window <- list(
      i_flex        = i_flex,
      rows          = window_rows,
      phase         = window_phase,
      commitment    = commitment_index,
      delta_t_h     = delta_t_h,
      guard_row     = guard_row,
      restating     = restating,
      i_end_control = i_end_control
    )

    rm(list = c("end_time_commitment", "end_time_neutral", "window_phase",
                "delta_t_h", "guard_row", "time_at_i_flex",
                "window_time", "commitment_phase_length",
                "neutral_phase_timespan", "recovery_phase_timespan",
                "i_end_control", "window_rows", "commitment_index",
                "phase_col", "i_flex", "restating"))
  }

  # -------------------------------------------------------------
  # 6. The operations and the view of each asset
  # The operations of the type of model of every asset of the
  # registry, and its view of the piece, with the phases of the window
  # written by the system. Neither depends on the fraction of
  # flexibility, so system_flex_window() takes them from here at every
  # call. A view takes the net columns from the table of its own
  # asset, so what another asset draws does not change it.
  # -------------------------------------------------------------
  {
    column_order <- parameters$joined_cols
    models       <- list()
    views        <- list()
    for (CONT_001 in names(parameters$assets)) {
      # model_type_contract is called to take the operations of the
      # type of model of the asset, through which its contribution is
      # drafted and drawn.
      models[[CONT_001]] <- model_type_contract(
        parameters$assets[[CONT_001]]$asset_type
      )

      # piece_asset_view is called to take the view of the asset, with
      # the phases of the window written by the system, on which the
      # asset drafts and then draws its contribution.
      views[[CONT_001]] <- piece_asset_view(
        piece        = window_piece,
        asset_id     = CONT_001,
        column_order = column_order
      )
    }
    rm(list = c("CONT_001", "column_order"))
  }

  return(list(done         = NULL,
              window       = window,
              window_piece = window_piece,
              models       = models,
              views        = views))
}
