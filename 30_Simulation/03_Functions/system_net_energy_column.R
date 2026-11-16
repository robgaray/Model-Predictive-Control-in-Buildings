# -------------------------------------------------------------
# Function: system_net_energy_column.R
# Part of the Model Predictive Control in buildings repository
# <https://github.com/robgaray/Model-Predictive-Control-in-Buildings>
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the name of the column that holds the net electricity of
# the system for one itinerary. It is used by the places of the
# economic side that need a column name instead of the values
# (for example the weights and the per-interval sums by name).
# The column is Elec_total_<itinerary>: in Main_df it holds the sum
# over the assets, and in the table of each asset, which holds a
# column of the same name, the electricity of that asset. The naming
# rule lives only here, and system_net_energy() builds on it.
# -------------------------------------------------------------
# Inputs
#   itinerary : Character scalar. One of "exec", "plan",
#               "plan_flex_down" or "plan_flex_up".
# -------------------------------------------------------------
# Outputs
#   Character scalar: the column name, for example
#   "Elec_total_plan".
# -------------------------------------------------------------
# Code outline
# 1. Check the itinerary
# 2. Build the column name
# -------------------------------------------------------------
# Usage instructions
# system_net_energy_column("plan")
# -------------------------------------------------------------

system_net_energy_column <- function(itinerary) {

  # -------------------------------------------------------------
  # 1. Check the itinerary
  # The itinerary shall be one of the four known itineraries.
  # -------------------------------------------------------------
  {
    valid_itineraries <- c("exec", "plan", "plan_flex_down", "plan_flex_up")
    if (!is.character(itinerary) || length(itinerary) != 1 ||
        !(itinerary %in% valid_itineraries)) {
      stop("system_net_energy_column: itinerary must be one of ",
           paste(valid_itineraries, collapse = ", "), ".")
    }
    rm(list = "valid_itineraries")
  }

  # -------------------------------------------------------------
  # 2. Build the column name
  # -------------------------------------------------------------
  {
    column_name <- paste0("Elec_total_", itinerary)
  }

  return(column_name)
}
