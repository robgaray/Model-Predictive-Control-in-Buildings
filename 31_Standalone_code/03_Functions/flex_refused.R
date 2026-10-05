# -------------------------------------------------------------
# Function: flex_refused.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Tags a period chunk that flex_evaluation_down() or
# flex_evaluation_up() is returning unbuilt, with the reason why.
# -------------------------------------------------------------
# Why a reason is needed
# The two builders have four exits that return the chunk untouched:
# the window does not fit the control horizon, a defensive row check
# fails, the recovery does not converge, and the two thermal systems
# would be raised at once. Only the last of those is technical
# infeasibility in the sense the rule was written for, and only that
# one should reach the reward as such.
# Without this tag, the caller would have to guess from the rebuilt
# phases, for instance by testing whether the phase is all zero. That
# test only holds for the first window of a leg: from the second on the
# chunk already carries the phases of the earlier ones, so a refusal
# would go unnoticed and the standing commitment would be lost in
# silence.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. The chunk the builder is returning.
#   reason       : Character scalar. One of "no_room", "row_mismatch",
#                  "no_convergence", "opposed_systems".
# -------------------------------------------------------------
# Outputs
#   The same data frame, carrying the reason in the attribute
#   "flex_refusal". A chunk the builder did build carries no such
#   attribute, so attr(x, "flex_refusal") is NULL exactly when the
#   window was accepted.
# -------------------------------------------------------------
# Code outline
# 1. Check the reason is one of the four
# 2. Tag and return
# -------------------------------------------------------------
# Usage instructions
# return(flex_refused(period_chunk, "no_room"))
# and, on the reading side:
# reason <- attr(built, "flex_refusal")
# -------------------------------------------------------------
# Where this function/script is used
#   - flex_evaluation_down()
#   - flex_evaluation_up()
# -------------------------------------------------------------
# functions/scripts called
#   (none)
# -------------------------------------------------------------
flex_refused <- function(period_chunk, reason) {

  # 1. Check the reason is one of the four
  # -------------------------------------------------------------
  {
    known <- c("no_room", "row_mismatch", "no_convergence", "opposed_systems")
    if (!is.character(reason) || length(reason) != 1 || !reason %in% known) {
      stop("flex_refused: reason must be one of ",
           paste(known, collapse = ", "))
    }
  }

  # 2. Tag and return
  # -------------------------------------------------------------
  {
    attr(period_chunk, "flex_refusal") <- reason
  }

  return(period_chunk)
}
