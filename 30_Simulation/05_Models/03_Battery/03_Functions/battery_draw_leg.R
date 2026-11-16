# -------------------------------------------------------------
# Function: battery_draw_leg.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Draws the itinerary of a flexibility leg of a battery over a run of
# consecutive rows, from the energy each row asks of it, and carries
# the difference that this leaves in the stored energy to the rows
# after the run.
# The run starts from the energy that the leg holds in the row before
# it. battery_trajectory() computes the electricity and the energy of
# each row of the run within the limits of the battery, and they are
# written in the columns of the leg: Elec_charge, Elec_discharge,
# Elec_total and Stored_energy. The rows after the run keep their
# electricity: the leg follows the energy it had. Their stored energy
# changes by the difference the run left in its last row, kept only
# in the share that the self-discharge leaves from row to row. No
# limit is checked on those rows: the caller checks the ones that
# matter.
# -------------------------------------------------------------
# Inputs
#   period_chunk   : Data frame. The view of the battery, with the
#                    columns time and, for the leg,
#                    Elec_charge_plan_flex_<leg>,
#                    Elec_discharge_plan_flex_<leg>,
#                    Elec_total_plan_flex_<leg> and
#                    Stored_energy_plan_flex_<leg>.
#   leg            : Character scalar. down or up.
#   rows           : Integer vector. The rows of the run, consecutive
#                    and from row 2 on: the row before the first one
#                    holds its initial condition.
#   energy_request : Numeric vector, as long as rows. The energy each
#                    row asks of the battery (kWh of the system side,
#                    positive to charge). It may be Inf or -Inf.
#   asset          : Named list. The parameters of the battery, its
#                    entry of parameters$assets.
# -------------------------------------------------------------
# Outputs
#   Data frame. The chunk with the leg drawn over the rows and the
#   stored energy of the rows after them moved by the difference.
#   The run stops if the rows are not valid.
# -------------------------------------------------------------
# Code outline
# 1. Check the rows
# 2. Draw the run
# 3. Carry the difference to the following rows
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- battery_draw_leg(
#   period_chunk   = period_chunk,
#   leg            = "down",
#   rows           = 5:8,
#   energy_request = rep(-1, 4),
#   asset          = asset
# )
# -------------------------------------------------------------

battery_draw_leg <- function(period_chunk,
                             leg,
                             rows,
                             energy_request,
                             asset
                             ) {

  # -------------------------------------------------------------
  # 1. Check the rows
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("battery_draw_leg: leg must be \"down\" or \"up\"")
    }
    if (length(rows) == 0 || anyNA(rows) || rows[1] < 2 ||
        any(diff(rows) != 1) || rows[length(rows)] > nrow(period_chunk) ||
        length(energy_request) != length(rows)) {
      stop("battery_draw_leg: rows must be consecutive rows of the ",
           "chunk from row 2 on, with one request each (",
           asset$asset_id, ")")
    }

    sfx       <- paste0("_plan_flex_", leg)
    n_rows    <- nrow(period_chunk)
    delta_t_h <- diff(as.numeric(period_chunk$time)) / 3600
  }

  # -------------------------------------------------------------
  # 2. Draw the run
  # -------------------------------------------------------------
  {
    # battery_trajectory is called to compute the electricity and the
    # energy of each row of the run, within the limits of the
    # battery, from the energy that the leg holds before it.
    run <- battery_trajectory(
      stored_energy_start = period_chunk[[paste0("Stored_energy",
                                                  sfx)]][rows[1] - 1],
      delta_t_h           = delta_t_h[rows - 1],
      energy_request      = energy_request,
      battery             = asset$battery
    )

    energy_before <- period_chunk[[paste0("Stored_energy",
                                          sfx)]][rows[length(rows)]]

    period_chunk[[paste0("Stored_energy", sfx)]][rows]  <- run$stored_energy
    period_chunk[[paste0("Elec_charge", sfx)]][rows]    <- run$charge
    period_chunk[[paste0("Elec_discharge", sfx)]][rows] <- run$discharge
    period_chunk[[paste0("Elec_total", sfx)]][rows]     <-
      run$charge - run$discharge
  }

  # -------------------------------------------------------------
  # 3. Carry the difference to the following rows
  # The share of the difference that the battery keeps in each row
  # is the product of the shares of the self-discharge of the rows
  # in between. The hours of a day and the percent are conversions
  # of unit.
  # -------------------------------------------------------------
  {
    last_row <- rows[length(rows)]
    if (last_row < n_rows) {
      after      <- (last_row + 1):n_rows
      keep       <- (1 - asset$battery$Self_discharge / 100)^
        (delta_t_h[after - 1] / 24)
      difference <- run$stored_energy[length(rows)] - energy_before

      period_chunk[[paste0("Stored_energy", sfx)]][after] <-
        period_chunk[[paste0("Stored_energy", sfx)]][after] +
        difference * cumprod(keep)

      rm(list = c("after", "keep", "difference"))
    }

    rm(list = c("sfx", "n_rows", "delta_t_h", "run", "energy_before",
                "last_row"))
  }

  return(period_chunk)
}
