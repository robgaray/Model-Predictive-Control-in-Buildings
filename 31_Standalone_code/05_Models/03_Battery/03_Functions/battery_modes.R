# -------------------------------------------------------------
# Function: battery_modes.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the five modes a battery is operated in, with their codes.
# It is the one place where the codes are written. On each market
# interval a battery works in one of them:
#   - surplus_charge (1): it charges only from the electricity the
#       rest of the system exports, never from the grid.
#   - charge (2): it charges as much as its limits allow, also from
#       the grid.
#   - local_discharge (3): it discharges only to cover what the
#       rest of the system imports, never to export.
#   - discharge (4): it discharges as much as its limits allow,
#       also exporting to the grid.
#   - stop (5): it neither charges nor discharges. It is the mode
#       of a row that no market has decided.
# -------------------------------------------------------------
# Inputs
#   None.
# -------------------------------------------------------------
# Outputs
#   Named integer vector. The codes of the modes, named
#   surplus_charge, charge, local_discharge, discharge and stop.
# -------------------------------------------------------------
# Code outline
# 1. Give the codes
# -------------------------------------------------------------
# Usage instructions
# battery_modes()[["stop"]]
# -------------------------------------------------------------

battery_modes <- function() {

  # -------------------------------------------------------------
  # 1. Give the codes
  # The codes are the structure of the modes, not parameters: they
  # are the position of each mode in the list of the header.
  # -------------------------------------------------------------
  {
    modes <- c(surplus_charge  = 1L,
               charge          = 2L,
               local_discharge = 3L,
               discharge       = 4L,
               stop            = 5L)
  }

  return(modes)
}
