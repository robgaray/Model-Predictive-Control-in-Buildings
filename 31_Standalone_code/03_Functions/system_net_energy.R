# -------------------------------------------------------------
# Function: system_net_energy.R
# Part of the Model Predictive Control in buildings repository
# <https://github.com/robgaray/Model-Predictive-Control-in-Buildings>
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the net electricity of the system for one itinerary. It is
# the one place where the economic side reads the energy of the
# system: the column Elec_total_<itinerary> (kWh per row, positive
# when imported). The table of the system holds it as the sum over
# the assets of the column of the same name of each asset
# (sum_asset_energy()). The piece a market works on joins the table
# of the system and the table of each asset, so there the column is
# the sum over the assets.
# -------------------------------------------------------------
# Inputs
#   itinerary_table : data.frame or data.table that holds the
#                     itinerary columns (the table of the
#                     system, a market piece, the joined results
#                     table).
#   itinerary       : Character scalar. One of "exec", "plan",
#                     "plan_flex_down" or "plan_flex_up".
# -------------------------------------------------------------
# Outputs
#   Numeric vector: the net electricity of the system, one value
#   per row of itinerary_table (kWh, positive imported). It is the
#   full column: callers index it.
# -------------------------------------------------------------
# Code outline
# 1. Get the column name
# 2. Check the column and return its values
# -------------------------------------------------------------
# Usage instructions
# system_net_energy(piece$system, "plan")
# -------------------------------------------------------------

system_net_energy <- function(itinerary_table,
                              itinerary) {

  # -------------------------------------------------------------
  # 1. Get the column name
  # -------------------------------------------------------------
  {
    # system_net_energy_column checks the itinerary and gives the
    # name of the column, so the naming rule exists only once.
    column_name <- system_net_energy_column(itinerary = itinerary)
  }

  # -------------------------------------------------------------
  # 2. Check the column and return its values
  # -------------------------------------------------------------
  {
    if (!(column_name %in% names(itinerary_table))) {
      stop("system_net_energy: column ", column_name,
           " is missing in itinerary_table.")
    }
    net_energy <- itinerary_table[[column_name]]
    rm(list = "column_name")
  }

  return(net_energy)
}
