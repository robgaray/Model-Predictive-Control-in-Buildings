# -------------------------------------------------------------
# Function: sum_by_slot.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Adds a per-timestep quantity of Main_df up into one total per market
# slot of the economic analysis, in the order of that table's slots.
#
# The grouping is done on the numeric form of the timestamps, not on
# their text form, so that the aggregation cannot be broken by a
# locale or timezone difference in how a POSIXct prints. A slot with no
# Main_df row would come back as NA from the match, so it is forced to
# 0: nothing was delivered there.
# -------------------------------------------------------------
# Inputs
#   values       : Numeric vector, one entry per row of Main_df.
#   slot_group   : Numeric vector, the same length as values: the
#                  market slot of each row, as.numeric(Main_df$MarketUTC).
#   slot_targets : Numeric vector: the slots of the economic analysis,
#                  as.numeric(economic_analysis$slot$time), in the order
#                  the totals are wanted.
# -------------------------------------------------------------
# Outputs
#   Numeric vector, one total per entry of slot_targets, 0 where no row
#   belongs to the slot.
# -------------------------------------------------------------
# Code outline
# 1. Add the values up per slot, and place each total on its target
#    slot.
# -------------------------------------------------------------
# Usage instructions
# energy_in <- sum_by_slot(pmax(Main_df$Elec_total_exec, 0),
#                          slot_group, slot_targets)
# -------------------------------------------------------------
# Where this function/script is used
# 15_economic_analysis_finalize.R, for every per-slot total of the
# execution phase.
# -------------------------------------------------------------
# functions/scripts called
# None.
# -------------------------------------------------------------

sum_by_slot <- function(values,
                        slot_group,
                        slot_targets
                        ) {

  # -------------------------------------------------------------
  # 1. Add the values up per slot, and place each total on its target
  # slot
  # -------------------------------------------------------------
  {
    aggregated <- tapply(values, slot_group, sum)
    result     <- as.numeric(aggregated[match(slot_targets, as.numeric(names(aggregated)))])
    result[is.na(result)] <- 0
  }

  return(result)
}
