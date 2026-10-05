# -------------------------------------------------------------
# Function: flex_window_is_feasible.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Says whether a flexibility window is technically feasible: inside it,
# the itinerary may not raise the electricity of BOTH thermal systems
# over the _plan itinerary. The system that provides the service may go
# up; the other one may not.
# -------------------------------------------------------------
# Why the whole window and not each phase
# The case this rule exists to forbid splits the increase between the
# Commitment Phase and the Recovery Phase - heating up front, cooling on
# the way back - and raises both systems at no single instant. A rule
# applied phase by phase, or step by step, would see nothing wrong in
# either half. Measured over the three phases at once, it is caught.
# -------------------------------------------------------------
# Why electricity and not heat
# The same thermal increment costs different electricity depending on
# the COP, and above Q_hp_heat_1 the surplus is served at COP 1. What is
# sold and what is paid for is electricity, so that is what is measured.
# -------------------------------------------------------------
# The tolerance
# It is the larger of a share of the dominant increment and an absolute
# floor, both read from 08_Flexibility_Event_Configuration.csv:
#   tol = max(flex_feasibility_tolerance/100 * max(|inc_heat|, |inc_cool|),
#             flex_feasibility_floor)
# The dominant system always clears its own share - its increment IS the
# maximum, and a positive number always exceeds its own five per cent -
# so the condition reduces to asking whether the secondary system's
# increment passes that tolerance. The floor is not numerical residue:
# an increment under a quarter of a kilowatt hour does not count as a
# decision, whoever made it. The two meet at a dominant increment of
# 5 kWh with the production values.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. Must carry, for the leg being judged, the
#                  phase column and the four electricity columns named
#                  below.
#   leg          : Character. "down" or "up".
#   parameters   : Named list. parameters$control$flex_feasibility_tolerance
#                  (%) and parameters$control$flex_feasibility_floor (kWh).
# -------------------------------------------------------------
# Outputs
#   Logical scalar. TRUE when the window may be committed, FALSE when
#   both systems raise their electricity over the plan beyond the
#   tolerance. A chunk with no window at all is feasible: there is
#   nothing to judge.
# -------------------------------------------------------------
# Code outline
# 1. The rows of the window, and the two increments over the plan
# 2. The tolerance, and the verdict
# -------------------------------------------------------------
# Usage instructions
# if (!flex_window_is_feasible(period_chunk, "up", parameters)) { ... }
# -------------------------------------------------------------
# Where this function/script is used
#   - flex_evaluation_down()
#   - flex_evaluation_up()
#   - reward_function()
# -------------------------------------------------------------
# EXCEPTIONS AND SPECIAL CASES:
#   - The rule is applied to both legs. Downward, the phenomenon is less
#     likely - cutting consumption does not push the other system - and
#     it is not observed in any available run, but the symmetry costs
#     nothing and leaves that leg covered if a recovery ever pushes it.
#   - It does not forbid one system rising while the other FALLS. That
#     case exists and is frequent in warm weather, and it is allowed:
#     the service sold is real, and the other system switching itself
#     off is a consequence of the control, not an order. It is not the
#     alternating use of heating and cooling the rule is about.
#   - build_system_lock_caps() already forbids the non-providing system
#     from raising its power during the Recovery Phase. That lock shapes
#     the itinerary while it is simulated; this rule judges the finished
#     window. Both are kept.
# -------------------------------------------------------------
# functions/scripts called
# (none)
# -------------------------------------------------------------

flex_window_is_feasible <- function(period_chunk, leg, parameters) {

  # 1. The rows of the window, and the two increments over the plan
  # -------------------------------------------------------------
  {
    phase_col <- paste0("Flex_phase_", leg, "_plan")
    heat_col  <- paste0("Elec_heat_plan_flex_", leg)
    cool_col  <- paste0("Elec_cool_plan_flex_", leg)

    needed  <- c(phase_col, heat_col, cool_col, "Elec_heat_plan", "Elec_cool_plan")
    missing <- needed[!needed %in% names(period_chunk)]
    if (length(missing) > 0) {
      stop("flex_window_is_feasible: period_chunk is missing required columns: ",
           paste(missing, collapse = ", "))
    }

    window_rows <- which(period_chunk[[phase_col]] > 0L)

    if (length(window_rows) == 0) {
      return(TRUE)
    }

    increase_heat <- sum(period_chunk[[heat_col]][window_rows] -
                           period_chunk$Elec_heat_plan[window_rows], na.rm = TRUE)
    increase_cool <- sum(period_chunk[[cool_col]][window_rows] -
                           period_chunk$Elec_cool_plan[window_rows], na.rm = TRUE)
  }

  # 2. The tolerance, and the verdict
  # -------------------------------------------------------------
  {
    tolerance <- max(
      parameters$control$flex_feasibility_tolerance / 100 *
        max(abs(increase_heat), abs(increase_cool)),
      parameters$control$flex_feasibility_floor
    )

    feasible <- !(increase_heat > tolerance && increase_cool > tolerance)
  }

  rm(phase_col, heat_col, cool_col, needed, missing, window_rows,
     increase_heat, increase_cool, tolerance)

  return(feasible)
}
