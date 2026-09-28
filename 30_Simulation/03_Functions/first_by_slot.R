# -------------------------------------------------------------
# Function: first_by_slot.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Takes, for each market slot of the economic analysis, the value of a
# Main_df column on the first row of that slot.
#
# Prices are a property of the market slot, not of the timestep, so
# the slot's own price is taken from its first row rather than
# aggregated - the same rule integrate_market_process.R uses to read
# Flex_Probab_down / Flex_Probab_up for a target interval. A slot with
# no Main_df row comes back as 0.
# -------------------------------------------------------------
# Inputs
#   values       : Numeric vector, one entry per row of Main_df.
#   slot_group   : Numeric vector, the same length as values: the
#                  market slot of each row, as.numeric(Main_df$MarketUTC).
#   slot_targets : Numeric vector: the slots of the economic analysis,
#                  as.numeric(economic_analysis$slot$time), in the order
#                  the values are wanted.
# -------------------------------------------------------------
# Outputs
#   Numeric vector, one value per entry of slot_targets, 0 where no row
#   belongs to the slot.
# -------------------------------------------------------------
# Code outline
# 1. Take the first value of each slot, and place it on its target
#    slot.
# -------------------------------------------------------------
# Usage instructions
# price <- first_by_slot(Main_df$Elec_unit_cost_import_buy,
#                        slot_group, slot_targets)
# -------------------------------------------------------------
# Where this function/script is used
# 15_economic_analysis_finalize.R, for the prices of each slot.
# -------------------------------------------------------------
# functions/scripts called
# None.
# -------------------------------------------------------------

first_by_slot <- function(values,
                          slot_group,
                          slot_targets
                          ) {

  # -------------------------------------------------------------
  # 1. Take the first value of each slot, and place it on its target
  # slot
  # -------------------------------------------------------------
  {
    aggregated <- tapply(values, slot_group, function(v) v[1])
    result     <- as.numeric(aggregated[match(slot_targets, as.numeric(names(aggregated)))])
    result[is.na(result)] <- 0
  }

  return(result)
}
