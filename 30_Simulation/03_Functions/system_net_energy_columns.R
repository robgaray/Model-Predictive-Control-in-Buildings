# -------------------------------------------------------------
# Function: system_net_energy_columns.R
# Part of the Model Predictive Control in buildings repository
# <https://github.com/robgaray/Model-Predictive-Control-in-Buildings>
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the names of the columns that hold the net electricity of
# the system, one per itinerary. These are the only columns that
# Main_df and the table of an asset hold both with a different
# meaning: in Main_df the column is the sum over the assets of the
# column of the same name in the table of each asset. Every place
# that has to decide whether a column is written again as that sum
# asks this function, so the decision lives only here.
# -------------------------------------------------------------
# Inputs
# None.
# -------------------------------------------------------------
# Outputs
#   Character vector of four names: the column of the itineraries
#   "exec", "plan", "plan_flex_down" and "plan_flex_up", in that
#   order.
# -------------------------------------------------------------
# Code outline
# 1. Name the column of each itinerary
# -------------------------------------------------------------
# Usage instructions
# net_columns <- system_net_energy_columns()
# -------------------------------------------------------------

system_net_energy_columns <- function() {

  # -------------------------------------------------------------
  # 1. Name the column of each itinerary
  # system_net_energy_column is called once per itinerary, so the
  # naming rule is read from the function that owns it.
  # -------------------------------------------------------------
  {
    net_columns <- vapply(
      c("exec", "plan", "plan_flex_down", "plan_flex_up"),
      function(CONT_001) system_net_energy_column(itinerary = CONT_001),
      character(1),
      USE.NAMES = FALSE
    )
  }

  return(net_columns)
}
