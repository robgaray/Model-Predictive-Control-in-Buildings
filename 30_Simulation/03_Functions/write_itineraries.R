# -------------------------------------------------------------
# Function: write_itineraries.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Works out how the decision of a single Scheduling or Piloting market
# is written into the tables of the simulation, for the current
# simulation step. The market writes the plan it ends with, the two
# flexibility itineraries and the commitments of the two legs
# (Elec_flex_down_plan and Elec_flex_up_plan), as absolute values on
# the rows it controls. The plan and the two flexibility itineraries
# of each asset are written into the table of that asset; the
# commitments belong to the system, and are written into Main_df.
# The function never writes into Main_df: it returns the writes, and
# the simulation loop (run_market_role()) applies them. The settlement
# of the market (settle_market()) reads the energy of these
# itineraries once the writes are applied.
# The phase codes are the optimizer's own labels: scratch state of the
# search, reset on every candidate by derive_flex_itineraries(). They
# are not written back. The settlement commits the energy of the _plan
# itinerary and the phase-1 flexibility, and neither needs the label,
# because the contingent recovery is not committed.
# -------------------------------------------------------------
# Inputs
# piece               : List. The piece of the market, as returned by
#                        run_market_process(): the table of the system
#                        and the table of each asset, with the columns
#                        of the plan, of the two flexibility
#                        itineraries and of the commitments for the
#                        market's period.
# simulation_control  : Named list. Must contain
#                        indexes_global$idx_ctrl and
#                        indexes_local$idx_ctrl for the current market.
# parameters          : Named list. Model parameters; reads the
#                        variables of the itineraries through
#                        itinerary_columns().
# -------------------------------------------------------------
# Outputs
# Named list with:
#   - system : List of writes for Main_df: the commitments of the two
#     legs.
#   - assets : Named list, one element per asset, in the order of the
#     asset registry. Each one is the list of writes for the table of
#     that asset: its plan and its two flexibility itineraries.
# The writes of each list are in the order in which they have to be
# applied. Each write is a list with:
#   - column : Character. Column of the table written.
#   - rows   : Integer vector. Rows of the table (the control rows).
#   - value  : Numeric vector, as long as rows.
#   - mode   : Character. "assign": the values replace the current
#     ones.
# There is one write per column of the plan, of the two flexibility
# itineraries and of the commitments that the tables of the piece
# hold.
# -------------------------------------------------------------
# Code outline
# 1. Columns of the itineraries and the commitments
# 2. Absolute writes over the control rows
# -------------------------------------------------------------
# Usage instructions
# itinerary_writes <- write_itineraries(
#   piece              = market_piece,
#   simulation_control = simulation_control,
#   parameters         = parameters
# )
# -------------------------------------------------------------

write_itineraries <- function(piece,
                              simulation_control,
                              parameters) {

  # -------------------------------------------------------------
  # 1. Columns of the itineraries and the commitments
  # The columns of the plan and of the two flexibility itineraries,
  # kept only where the table of each asset holds them, and the
  # commitments of the two legs, kept only where the table of the
  # system holds them.
  # -------------------------------------------------------------
  {
    # itinerary_columns is called to name the columns of the plan and
    # of the two flexibility itineraries.
    itinerary_cols <- c(itinerary_columns("plan", parameters),
                        itinerary_columns("plan_flex_down", parameters),
                        itinerary_columns("plan_flex_up", parameters))

    system_cols <- intersect(
      c("Elec_flex_down_plan", "Elec_flex_up_plan"),
      names(piece$system)
    )
  }

  # -------------------------------------------------------------
  # 2. Absolute writes over the control rows
  # Each column is written on the control rows of its table with the
  # values of the control rows of the same column of the piece. The
  # tables of the piece are plain data frames, so they keep ordinary
  # data.frame indexing.
  # -------------------------------------------------------------
  {
    asset_writes <- list()
    for (CONT_005 in names(piece$assets)) {
      asset_writes[[CONT_005]] <- list()
      asset_cols <- intersect(itinerary_cols,
                              setdiff(names(piece$assets[[CONT_005]]$df), "time"))
      for (CONT_006 in asset_cols) {
        asset_writes[[CONT_005]][[length(asset_writes[[CONT_005]]) + 1L]] <- list(
          column = CONT_006,
          rows   = simulation_control$indexes_global$idx_ctrl,
          value  = piece$assets[[CONT_005]]$df[[CONT_006]][simulation_control$indexes_local$idx_ctrl],
          mode   = "assign"
        )
      }
    }

    system_writes <- list()
    for (CONT_007 in system_cols) {
      system_writes[[length(system_writes) + 1L]] <- list(
        column = CONT_007,
        rows   = simulation_control$indexes_global$idx_ctrl,
        value  = piece$system[[CONT_007]][simulation_control$indexes_local$idx_ctrl],
        mode   = "assign"
      )
    }

    rm(list = intersect(c("itinerary_cols", "system_cols", "asset_cols",
                          "CONT_005", "CONT_006", "CONT_007"), ls()))
  }

  return(list(system = system_writes, assets = asset_writes))
}
