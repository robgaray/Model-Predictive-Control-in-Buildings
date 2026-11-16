# -------------------------------------------------------------
# Function: spread_slot_energy.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Spreads an energy given per market interval over the internal time
# steps of the working table: the energy of each interval is divided
# evenly between the steps of the interval. Row 1 is the initial
# condition, whose time step lies before the first instant of the
# call, so it carries no energy and gets 0.
# -------------------------------------------------------------
# Inputs
#   slot_energy : Numeric vector. The energy of each market interval
#                 of the input, in kWh, in the order of the intervals.
#   grid        : Named list. The time grid of the working table, as
#                 the market process builds it. Uses:
#                 - slot_of_row: integer vector, the position in the
#                   input of the interval of each row
#                 - steps_per_slot: numeric scalar, the number of
#                   internal time steps of a market interval
# -------------------------------------------------------------
# Outputs
#   Numeric vector, one value per row of the working table, in kWh.
# -------------------------------------------------------------
# Code outline
# 1. Divide the interval energy between its steps
# -------------------------------------------------------------
# Usage instructions
# row_energy <- spread_slot_energy(itinerary$Elec_total, grid)
# -------------------------------------------------------------

spread_slot_energy <- function(slot_energy,
                               grid
                               ) {

  # -------------------------------------------------------------
  # 1. Divide the interval energy between its steps
  # -------------------------------------------------------------
  {
    row_energy    <- slot_energy[grid$slot_of_row] / grid$steps_per_slot
    row_energy[1] <- 0
  }

  return(row_energy)
}
