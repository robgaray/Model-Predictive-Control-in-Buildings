# -------------------------------------------------------------
# Function: battery_hold_room.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the most electricity a battery can hold, on each row, of a
# flexibility window already sold that it does not redraw. It is the
# operation hold_room of the type of model Battery
# (model_type_contract()).
# The system uses it to share what a window misses among the assets
# that hold it (system_hold_window()). The room is by row, with no
# effect of one row on the next: it is the distance, on that row,
# between the electricity the leg of the battery has and the most the
# battery can discharge there (downward), or the most it can charge
# (upward).
# With E the energy the leg stores before the row, and f the share
# the battery keeps of it in the row (its self-discharge), the energy
# the row starts from is f * E. Downward, the most the battery
# discharges is the smaller of its discharge power times the duration
# of the row and the energy above its minimum that reaches the system
# (times its discharge efficiency). Upward, it is the smaller of its
# charge power times the duration of the row and the room under its
# maximum energy (divided by its charge efficiency). The room is that
# amount minus the electricity the leg already has on the row, never
# below 0.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. The view of the battery, with the
#                  columns time and, for the itinerary of the leg,
#                  Elec_charge_plan_flex_<leg>,
#                  Elec_discharge_plan_flex_<leg> and
#                  Stored_energy_plan_flex_<leg>.
#   leg          : Character scalar, "down" or "up".
#   window_rows  : Integer vector. The rows of the window held, from
#                  row 2 on.
#   parameters   : Named list. Not read.
#   asset        : Named list. The parameters of the battery, its
#                  entry of parameters$assets.
# -------------------------------------------------------------
# Outputs
#   Numeric vector (kWh), not negative, one value per row of
#   window_rows.
# -------------------------------------------------------------
# Code outline
# 1. Check the inputs
# 2. The room of each row
# -------------------------------------------------------------
# Usage instructions
# room <- battery_hold_room(period_chunk = view,
#                           leg          = "down",
#                           window_rows  = 2:5,
#                           parameters   = parameters,
#                           asset        = asset)
# -------------------------------------------------------------

battery_hold_room <- function(period_chunk,
                              leg,
                              window_rows,
                              parameters,
                              asset
                              ) {

  # -------------------------------------------------------------
  # 1. Check the inputs
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("battery_hold_room: leg must be \"down\" or \"up\"")
    }
    if (!is.numeric(window_rows) || anyNA(window_rows) ||
        any(window_rows != round(window_rows)) ||
        (length(window_rows) > 0 &&
         (any(window_rows < 2) || any(window_rows > nrow(period_chunk))))) {
      stop("battery_hold_room: window_rows must be integer rows of ",
           "period_chunk from row 2 on")
    }

    sfx    <- paste0("_plan_flex_", leg)
    needed <- c("time", paste0("Elec_charge", sfx),
                paste0("Elec_discharge", sfx), paste0("Stored_energy", sfx))
    missing_cols <- setdiff(needed, names(period_chunk))
    if (length(missing_cols) > 0) {
      stop("battery_hold_room: period_chunk is missing required columns: ",
           paste(missing_cols, collapse = ", "))
    }
  }

  # -------------------------------------------------------------
  # 2. The room of each row
  # The hours of a day and the percent are conversions of unit.
  # -------------------------------------------------------------
  {
    battery    <- asset$battery
    delta_t_h  <- (as.numeric(period_chunk$time[window_rows]) -
                     as.numeric(period_chunk$time[window_rows - 1])) / 3600
    keep       <- (1 - battery$Self_discharge / 100)^(delta_t_h / 24)
    energy_0   <- keep *
      period_chunk[[paste0("Stored_energy", sfx)]][window_rows - 1]
    own        <- period_chunk[[paste0("Elec_charge", sfx)]][window_rows] -
      period_chunk[[paste0("Elec_discharge", sfx)]][window_rows]
    energy_max <- battery$SOC_max * battery$Capacity
    energy_min <- battery$SOC_min * battery$Capacity

    room <- if (leg == "down") {
      own + pmin(battery$Discharge_power_max * delta_t_h,
                 pmax(0, (energy_0 - energy_min) *
                        battery$Discharge_efficiency))
    } else {
      pmin(battery$Charge_power_max * delta_t_h,
           pmax(0, (energy_max - energy_0) /
                  battery$Charge_efficiency)) - own
    }
    room <- pmax(room, 0)

    rm(list = c("sfx", "needed", "missing_cols", "battery", "delta_t_h", "keep",
                "energy_0", "own", "energy_max", "energy_min"))
  }

  return(room)
}
