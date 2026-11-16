# -------------------------------------------------------------
# Function: battery_window_feasible.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation window_feasible of the type of model Battery: says
# whether the flexibility windows of one leg are a service the
# battery can render, by the limits of its equipment.
# The rows judged are those of the Commitment Phase (phase 1) and of
# the Recovery Phase (phase 3) of the leg, the only rows on which the
# battery moves its energy away from the one it had before the
# window. On each of them:
#   - the electricity it takes does not exceed the charge power of
#     the battery times the duration of the step, and the
#     electricity it gives does not exceed the discharge power times
#     the duration of the step;
#   - if it charges, the energy it stores does not exceed E_max, and
#     if it discharges, it is not below E_min.
# All the comparisons have the tolerance of the energy of the
# flexibility, parameters$computing$flex_energy_tol (kWh).
# The rows of the other phases are not judged: after the control
# horizon closes the energy of a leg follows its earlier energy
# without limits.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. The view of the battery, with the
#                  columns time, Flex_phase_<leg>_plan and, for the
#                  itinerary of the leg, Elec_charge_plan_flex_<leg>,
#                  Elec_discharge_plan_flex_<leg> and
#                  Stored_energy_plan_flex_<leg>.
#   leg          : Character scalar. down or up.
#   parameters   : Named list. parameters$computing$flex_energy_tol
#                  (kWh).
#   asset        : Named list. The parameters of the battery, its
#                  entry of parameters$assets.
# -------------------------------------------------------------
# Outputs
#   Logical scalar. TRUE when no judged row breaks a limit, and when
#   the chunk has no row of those phases.
# -------------------------------------------------------------
# Code outline
# 1. The rows of the window
# 2. The limits and the verdict
# -------------------------------------------------------------
# Usage instructions
# if (!battery_window_feasible(period_chunk, "down", parameters,
#                              asset)) { ... }
# -------------------------------------------------------------

battery_window_feasible <- function(period_chunk,
                                    leg,
                                    parameters,
                                    asset
                                    ) {

  # -------------------------------------------------------------
  # 1. The rows of the window
  # Row 1 is the initial condition and is never judged.
  # -------------------------------------------------------------
  {
    sfx       <- paste0("_plan_flex_", leg)
    phase_col <- paste0("Flex_phase_", leg, "_plan")
    needed    <- c("time", phase_col, paste0("Elec_charge", sfx),
                   paste0("Elec_discharge", sfx),
                   paste0("Stored_energy", sfx))
    missing_cols <- setdiff(needed, names(period_chunk))
    if (length(missing_cols) > 0) {
      stop("battery_window_feasible: period_chunk is missing required ",
           "columns: ", paste(missing_cols, collapse = ", "))
    }

    n_rows      <- nrow(period_chunk)
    window_rows <- which(period_chunk[[phase_col]] %in% c(1L, 3L))
    window_rows <- window_rows[window_rows >= 2]

    if (length(window_rows) == 0) {
      rm(list = c("sfx", "phase_col", "needed", "missing_cols", "n_rows",
                  "window_rows"))
      return(TRUE)
    }
  }

  # -------------------------------------------------------------
  # 2. The limits and the verdict
  # The hours of a day and the percent are conversions of unit.
  # -------------------------------------------------------------
  {
    battery    <- asset$battery
    tol        <- parameters$computing$flex_energy_tol
    delta_t_h  <- diff(as.numeric(period_chunk$time)) / 3600
    delta_rows <- delta_t_h[window_rows - 1]
    charge     <- period_chunk[[paste0("Elec_charge", sfx)]][window_rows]
    discharge  <- period_chunk[[paste0("Elec_discharge", sfx)]][window_rows]
    energy     <- period_chunk[[paste0("Stored_energy", sfx)]][window_rows]
    energy_max <- battery$SOC_max * battery$Capacity
    energy_min <- battery$SOC_min * battery$Capacity

    feasible <- all(
      charge    <= battery$Charge_power_max * delta_rows + tol,
      discharge <= battery$Discharge_power_max * delta_rows + tol,
      !(charge > 0 & energy > energy_max + tol),
      !(discharge > 0 & energy < energy_min - tol)
    )

    rm(list = c("sfx", "phase_col", "needed", "missing_cols", "n_rows",
                "window_rows", "battery", "tol", "delta_t_h", "delta_rows",
                "charge", "discharge", "energy", "energy_max", "energy_min"))
  }

  return(feasible)
}
