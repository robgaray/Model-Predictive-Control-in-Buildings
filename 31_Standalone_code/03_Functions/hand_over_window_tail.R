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
# the rows the tail occupies, their phases, and, for each asset, the
# state the window left in its itinerary at i_begin_horizon and the
# system of the asset that provides it.
# The itinerary of the tail itself is not handed over. The optimization
# continues it over the plan of each candidate, from that state.
# -------------------------------------------------------------
# Inputs
#   stretch_piece   : The piece of the simulated stretch, rows 1 to the
#                     end of the tail, after derive_flex_itineraries()
#                     has projected the windows over it. The phases are
#                     read from its table of the system, and the state
#                     of each asset from its view.
#   committed_system: Data frame. The table of the system of the same
#                     rows before the projection, carrying the committed
#                     energy (Elec_flex_down_plan, Elec_flex_up_plan) as
#                     it stands.
#   i_begin_horizon : Integer. Row of the stretch where the optimization
#                     horizon starts.
#   tail_end        : Integer. Last row of the stretch occupied by the
#                     window, as pre_horizon_window_tails() returns it.
#   leg             : Character scalar, "down" or "up".
#   parameters      : Named list. Used by reconstruct_flex_phases().
#                     parameters$joined_cols is the order of the view of
#                     each asset. Its asset registry (parameters$assets)
#                     gives the type of model and the parameters of
#                     every asset.
# -------------------------------------------------------------
# Outputs
#   Named list:
#     rows   : Integer vector. Rows of the tail, counted from the first
#              row of the optimization chunk (i_begin_horizon is row 1).
#     phases : Integer vector, one per row: 1 Commitment, 2 Neutral,
#              3 Recovery.
#     state  : Named list, one entry per asset (named by its
#              asset_id), each a one-row data frame. The state of the
#              itinerary of the leg of that asset at i_begin_horizon,
#              as the operation tail_state of its type of model gives
#              it (for a building: Ti, Te, Act_heat, Act_cool,
#              Thermostat_heat, Thermostat_cool, Q_heat and Q_cool).
#     system : Named list, one entry per asset (named by its
#              asset_id), each "heat", "cool" or "none". The system of
#              the asset that provides the window, read over its
#              Commitment Phase with the rule the building
#              contributes to a window with, flex_evaluation().
# -------------------------------------------------------------
# Code outline
# 1. Rows and phases of the tail
# 2. State at i_begin_horizon and system of the window, per asset
# -------------------------------------------------------------
# Usage instructions
# tail <- hand_over_window_tail(stretch_piece, committed_system,
#                               i_begin_horizon, tail_end, "down", parameters)
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - A window the projection could not draw is held with its
#     Commitment Phase alone (hold_standing_window()). Its Neutral and
#     Recovery Phases are then read from the committed energy
#     (reconstruct_flex_phases()), because they still belong to it.
#   - A window held that way leaves the plan's state in its itinerary.
# -------------------------------------------------------------

hand_over_window_tail <- function(stretch_piece,
                                  committed_system,
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
    reconstructed <- reconstruct_flex_phases(committed_system, leg, parameters)
    projected     <- stretch_piece$system[[phase_column]]
    phases        <- ifelse(projected > 0, projected, reconstructed)

    rm(list = c("reconstructed", "projected"))
  }

  # -------------------------------------------------------------
  # 2. State at i_begin_horizon and system of the window, per asset
  # What the window left in each asset, and which of its systems
  # provides it, belong to the type of model of the asset. Both are
  # gathered in lists named by the asset_id.
  # -------------------------------------------------------------
  {
    state  <- list()
    system <- list()

    for (CONT_001 in names(parameters$assets)) {

      # The operations of the type of model receive the parameters of
      # the asset, its entry of parameters$assets.
      asset <- parameters$assets[[CONT_001]]

      # model_type_contract is called to take the operations of the
      # type of model of the asset, through which its state is read.
      model <- model_type_contract(asset$asset_type)

      # piece_asset_view is called to take the table of the asset of the
      # stretch joined with that of the system, from which its state is
      # read.
      view <- piece_asset_view(
        piece        = stretch_piece,
        asset_id     = CONT_001,
        column_order = parameters$joined_cols
      )

      # The operation tail_state of the model is called to read the
      # state the window left at i_begin_horizon and the system that
      # provides it.
      tail_state <- model$tail_state(
        stretch_chunk   = view,
        i_begin_horizon = i_begin_horizon,
        leg             = leg,
        asset           = asset
      )
      state[[CONT_001]]  <- tail_state$state
      system[[CONT_001]] <- tail_state$system

      rm(list = c("asset", "model", "view", "tail_state"))
    }
    rm(list = "CONT_001")
  }

  tail <- list(
    rows   = tail_rows - i_begin_horizon + 1L,
    phases = as.integer(phases[tail_rows]),
    state  = state,
    system = system
  )

  rm(list = c("phase_column", "tail_rows", "phases", "state", "system"))

  return(tail)
}
