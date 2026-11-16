# -------------------------------------------------------------
# Function: building_hold_room.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives, row by row, the most electricity a building can hold of a
# flexibility commitment already sold, on one leg, when it does not
# redraw the window: how far its electricity itinerary can move away
# from its plan within the limits of its equipment. It is the
# operation hold_room of the type of model Building
# (model_type_contract()).
# A window already sold that an asset refuses to redraw is held by
# the assets that refuse it, within the limits of their equipment
# (system_hold_window()). With several of them, the system shares
# what is missing among them in proportion to what each one can hold,
# and asks each one here how much that is.
# -------------------------------------------------------------
# The limits of the equipment
#   - Downward: the itinerary cannot spend less than nothing, so a row
#     holds at most the electricity of the plan.
#   - Upward: the itinerary cannot spend more than the system that
#     provides the window draws at the heat power that bounds an
#     upward window (flex_up_power_limit()), so a row holds at most
#     that electricity less the plan. The system is the one
#     resolve_flex_up_hvac() picks from the start of the window. When
#     it picks none, the bound is the higher of the two systems:
#     whichever of them serves the window, the itinerary cannot go
#     above it.
# The electricity of a system at that heat power is measured at the
# outdoor temperature the plan is simulated with, the forecast
# (Text_forec), so that the bound and the plan it is compared with
# agree. A row whose plan is already at, or above, the bound holds
# nothing.
# -------------------------------------------------------------
# Inputs
#   period_chunk : Data frame. The chunk being derived. Reads the
#                  columns time, Text_forec, Elec_total_plan,
#                  Elec_heat_plan and Elec_cool_plan.
#   leg          : Character scalar, "down" or "up".
#   window_rows  : Integer vector. Rows of the Commitment Phase held,
#                  from row 2 on: each row is measured back to the row
#                  before.
#   parameters   : Named list. Reads what flex_up_power_limit() and
#                  resolve_flex_up_hvac() read: the bound of an upward
#                  window and the horizons and threshold of the
#                  choice of its system.
#   asset        : Named list. The parameters of the building, its
#                  entry of parameters$assets. Reads the model of the
#                  heat pump (heat_pump_cop(), heat_pump_electricity()
#                  and flex_up_power_limit()).
# -------------------------------------------------------------
# Outputs
#   Numeric vector, one entry per element of window_rows: the most
#   electricity (kWh) the building can hold on that row, 0 or more.
# -------------------------------------------------------------
# Code outline
# 1. Check the leg
# 2. The most each row can hold
# -------------------------------------------------------------
# Usage instructions
# room <- building_hold_room(period_chunk = period_chunk,
#                            leg          = "up",
#                            window_rows  = rows,
#                            parameters   = parameters,
#                            asset        = asset)
# -------------------------------------------------------------

building_hold_room <- function(period_chunk,
                               leg,
                               window_rows,
                               parameters,
                               asset) {

  # -------------------------------------------------------------
  # 1. Check the leg
  # -------------------------------------------------------------
  {
    if (!is.character(leg) || length(leg) != 1 ||
        !leg %in% c("down", "up")) {
      stop("building_hold_room: leg must be 'down' or 'up'")
    }
    plan_elec <- period_chunk$Elec_total_plan[window_rows]
  }

  # -------------------------------------------------------------
  # 2. The most each row can hold
  # Downward, the electricity of the plan. Upward, what the system of
  # the window draws at its bound, less the plan.
  # -------------------------------------------------------------
  {
    if (leg == "down") {
      room <- pmax(plan_elec, 0)
    } else {
      # A row holds the energy of the time step that ends at it, so its
      # step is measured back to the row before.
      delta_t_h <- (as.numeric(period_chunk$time[window_rows]) -
                      as.numeric(period_chunk$time[window_rows - 1])) / 3600
      no_heat   <- rep(0, length(window_rows))

      # heat_pump_cop is called for the COP of the heat pump on each
      # row, from the forecast of its outdoor temperature, which is the
      # one the plan is simulated with.
      cop_rows <- heat_pump_cop(period_chunk$Text_forec[window_rows], asset)

      # resolve_flex_up_hvac is called to know which system provides
      # the window, with the same rule the builder applies.
      hvac_up <- resolve_flex_up_hvac(period_chunk, window_rows[1], parameters)
      systems <- if (hvac_up == "none") c("heat", "cool") else hvac_up

      # flex_up_power_limit and heat_pump_electricity are called for
      # the electricity each system draws at the bound of an upward
      # window; the highest of them is the ceiling of the row.
      ceiling_elec <- do.call(pmax, lapply(systems, function(one_system) {
        bound_heat <- flex_up_power_limit(one_system, parameters, asset) *
          delta_t_h
        heat_pump_electricity(
          Q_heat     = if (one_system == "heat") bound_heat else no_heat,
          Q_cool     = if (one_system == "cool") bound_heat else no_heat,
          cop_heat   = cop_rows,
          delta_t_h  = delta_t_h,
          asset      = asset
        )
      }))

      room <- pmax(ceiling_elec - plan_elec, 0)

      rm(list = c("delta_t_h", "cop_rows", "no_heat", "hvac_up", "systems",
                  "ceiling_elec"))
    }
    rm(list = "plan_elec")
  }

  return(room)
}
