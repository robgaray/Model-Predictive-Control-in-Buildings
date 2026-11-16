# -------------------------------------------------------------
# Function: sum_over_slots.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Adds up a column of the working table over the time steps of each
# market interval of the output. The closing interval, the one that
# starts at i_end_control, commits no energy, so its sum is missing
# (NA).
# -------------------------------------------------------------
# Inputs
#   values : Numeric vector. One value per row of the working table.
#   slots  : Named list. The output intervals, as the market process
#            builds them. Uses:
#            - n_out: integer scalar, the number of output instants,
#              the closing one included
#            - slot_rows: integer vector, one value per row of the
#              working table, the position in the committed
#              intervals of the interval the row belongs to, and NA
#              for a row outside them
# -------------------------------------------------------------
# Outputs
#   Numeric vector of n_out values: the sum of each committed
#   interval, and NA for the closing instant.
# -------------------------------------------------------------
# Code outline
# 1. Sum the rows of each committed interval
# -------------------------------------------------------------
# Usage instructions
# energy <- sum_over_slots(period_chunk$Elec_total_plan, slots)
# -------------------------------------------------------------

sum_over_slots <- function(values,
                           slots
                           ) {

  # -------------------------------------------------------------
  # 1. Sum the rows of each committed interval
  # -------------------------------------------------------------
  {
    committed         <- seq_len(slots$n_out - 1)
    totals            <- rep(NA_real_, slots$n_out)
    totals[committed] <- vapply(committed, function(CONT_001) {
      sum(values[which(slots$slot_rows == CONT_001)])
    }, numeric(1))
    rm(list = "committed")
  }

  return(totals)
}
