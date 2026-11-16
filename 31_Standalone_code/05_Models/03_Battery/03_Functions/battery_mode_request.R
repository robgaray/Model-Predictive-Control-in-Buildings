# -------------------------------------------------------------
# Function: battery_mode_request.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Gives the electricity that the mode of each row asks the battery to
# exchange with the system. A positive request asks the battery to
# charge, and a negative one to discharge. The request only depends
# on the mode and on the net electricity N of the rest of the system
# on the row (positive when the rest imports), not on the state of
# the battery: battery_trajectory() clips it with the limits of the
# battery. With the codes of battery_modes():
#   - 1, surplus_charge: max(-N, 0), the export of the rest.
#   - 2, charge: Inf, as much as the limits allow.
#   - 3, local_discharge: -max(N, 0), the import of the rest.
#   - 4, discharge: -Inf, as much as the limits allow.
#   - 5, stop: 0.
# -------------------------------------------------------------
# Inputs
#   mode        : Integer vector. The mode of each row, from 1 to 5.
#   rest_energy : Numeric vector, as long as mode. The net
#                 electricity of the rest of the system on each row
#                 (kWh, positive when the rest imports).
# -------------------------------------------------------------
# Outputs
#   Numeric vector, as long as mode. The request of each row (kWh of
#   the system side), which may be Inf or -Inf. The run stops if a
#   mode is not one of the five.
# -------------------------------------------------------------
# Code outline
# 1. Check the modes
# 2. Compute the request of each mode
# -------------------------------------------------------------
# Usage instructions
# request <- battery_mode_request(
#   mode        = c(1L, 4L),
#   rest_energy = c(-0.2, 0.1)
# )
# -------------------------------------------------------------

battery_mode_request <- function(mode,
                                 rest_energy
                                 ) {

  # -------------------------------------------------------------
  # 1. Check the modes
  # -------------------------------------------------------------
  {
    # battery_modes is called to get the codes of the five modes.
    codes <- battery_modes()

    if (length(mode) != length(rest_energy)) {
      stop("battery_mode_request: mode and rest_energy have ",
           length(mode), " and ", length(rest_energy), " elements")
    }
    if (anyNA(mode) || !all(mode %in% codes)) {
      stop("battery_mode_request: a mode is not one of the codes ",
           paste(codes, collapse = ", "))
    }
  }

  # -------------------------------------------------------------
  # 2. Compute the request of each mode
  # -------------------------------------------------------------
  {
    request <- numeric(length(mode))

    is_mode <- mode == codes[["surplus_charge"]]
    request[is_mode] <- pmax(-rest_energy[is_mode], 0)

    is_mode <- mode == codes[["charge"]]
    request[is_mode] <- Inf

    is_mode <- mode == codes[["local_discharge"]]
    request[is_mode] <- -pmax(rest_energy[is_mode], 0)

    is_mode <- mode == codes[["discharge"]]
    request[is_mode] <- -Inf

    rm(list = c("codes", "is_mode"))
  }

  return(request)
}
