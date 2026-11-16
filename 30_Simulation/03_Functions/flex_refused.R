# -------------------------------------------------------------
# Function: flex_refused.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Pairs a period chunk that a flexibility window is returned with,
# unbuilt, with the reason why. The window is built by the system,
# system_flex_window(), with the contribution each asset draws
# through the operation window_contribution of its type of model
# (flex_evaluation() for a building). Both use it.
# -------------------------------------------------------------
# Why a reason is needed
# A window can be refused for seven reasons, and each returns the chunk
# untouched. Three are of the system, checked by system_flex_window():
#   - no_room: a new window does not fit the control horizon;
#   - below_minimum: a market interval of a new window sells something,
#     on the net, but less than the minimum flexibility;
#   - empty_edge: the first or the last market interval of a new
#     window sells nothing on the net.
# Four are of an asset, checked when it draws its contribution. For a
# building, by flex_evaluation():
#   - row_mismatch: a defensive row check fails;
#   - no_convergence: the recovery of a new window does not converge;
#   - opposed_hvac: the two thermal systems would be raised at once.
# For a battery, by battery_window_contribution():
#   - no_recovery: the leg of the battery cannot be carried out until
#     the close of the control horizon, and its Recovery Phase cannot
#     correct it.
# An asset that refuses contributes nothing, and the window is refused
# with its reason only when no asset contributes to it.
# A new window that is refused is simply not sold. A window that is
# restated can only be refused by an asset, for row_mismatch or
# opposed_hvac. derive_flex_itineraries() then has the assets that
# refuse it hold what the others do not deliver, within the limits of
# their equipment (system_hold_window()), and reports each of them as
# not technically feasible on that leg when the window has rows in the
# guard zone.
# Without this reason, the caller would have to guess from the rebuilt
# phases, for instance by testing whether the phase is all zero. That
# test only holds for the first window of a leg: from the second on the
# chunk already carries the phases of the earlier ones, so a refusal
# would go unnoticed and the standing commitment would be lost in
# silence.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame or list. What the builder hands back
#                  untouched: the chunk of an asset, or the piece of
#                  the market when the window of the system is refused.
#   reason       : Character scalar. One of "no_room", "row_mismatch",
#                  "no_convergence", "opposed_hvac", "no_recovery",
#                  "below_minimum", "empty_edge".
# -------------------------------------------------------------
# Outputs
#   A named list with:
#   chunk   : The same object handed in.
#   refusal : Character scalar. The reason.
#   system_flex_window() returns the same two fields, with refusal
#   NULL when the window was accepted or when no asset had anything to
#   offer on it. flex_evaluation() adds a third, drawn.
# -------------------------------------------------------------
# Code outline
# 1. Check the reason is one of the seven
# 2. Pair and return
# -------------------------------------------------------------
# Usage instructions
# return(flex_refused(period_chunk, "no_room"))
# and, on the reading side:
# reason <- built$refusal
# -------------------------------------------------------------
flex_refused <- function(period_chunk, reason) {

  # 1. Check the reason is one of the seven
  # -------------------------------------------------------------
  {
    known <- c("no_room", "row_mismatch", "no_convergence", "opposed_hvac",
               "no_recovery", "below_minimum", "empty_edge")
    if (!is.character(reason) || length(reason) != 1 || !reason %in% known) {
      stop("flex_refused: reason must be one of ",
           paste(known, collapse = ", "))
    }
  }

  # 2. Pair and return
  # -------------------------------------------------------------
  {
    refused <- list(chunk = period_chunk, refusal = reason)
  }

  return(refused)
}
