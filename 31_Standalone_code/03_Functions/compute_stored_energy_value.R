# -------------------------------------------------------------
# Function: compute_stored_energy_value.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Values the energy the assets of the system leave stored, at the
# mean price at which the market buys energy over its horizon:
#   V = price * sum_k probability_k * stored_change_k
# stored_change_k is the change of the energy stored on row k, on
# the side of the system (system_stored_energy()), positive when
# energy is stored, and probability_k the weight of the row. The
# value is positive when energy is stored, and negative when stored
# energy is given up: stored energy is worth what it saves to buy.
# It is the plain value, in EUR: the revenue discount and the
# difference with what was committed are applied by
# economic_terms().
# -------------------------------------------------------------
# Inputs
#   stored_change : Numeric vector. Change of the stored energy of
#                   each row (kWh, positive when stored).
#   probability   : Numeric vector, as long as stored_change.
#                   Weight of each row: 1 for the plan, and the
#                   activation probability of the leg for a
#                   flexibility itinerary.
#   price         : Numeric scalar (EUR/kWh). Mean price at which
#                   the market buys energy over its horizon.
# -------------------------------------------------------------
# Outputs
#   Numeric scalar (EUR). The run stops if the lengths differ, if
#   a value is missing or if the price is not finite.
# -------------------------------------------------------------
# Code outline
# 1. Check the inputs
# 2. Value the stored energy
# -------------------------------------------------------------
# Usage instructions
# value <- compute_stored_energy_value(
#   stored_change = stored_energy$plan,
#   probability   = rep(1, length(stored_energy$plan)),
#   price         = marginal_context$stored_energy_price
# )
# -------------------------------------------------------------

compute_stored_energy_value <- function(stored_change,
                                        probability,
                                        price
                                        ) {

  # -------------------------------------------------------------
  # 1. Check the inputs
  # -------------------------------------------------------------
  {
    if (length(stored_change) != length(probability)) {
      stop("compute_stored_energy_value: stored_change and probability ",
           "have ", length(stored_change), " and ", length(probability),
           " elements")
    }
    if (anyNA(stored_change) || anyNA(probability)) {
      stop("compute_stored_energy_value: stored_change or probability ",
           "has missing values")
    }
    if (length(price) != 1 || !is.finite(price)) {
      stop("compute_stored_energy_value: price must be a single finite ",
           "number")
    }
  }

  # -------------------------------------------------------------
  # 2. Value the stored energy
  # -------------------------------------------------------------
  {
    value <- price * sum(probability * stored_change)
  }

  return(value)
}
