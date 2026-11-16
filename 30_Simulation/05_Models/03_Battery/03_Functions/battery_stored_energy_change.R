# -------------------------------------------------------------
# Function: battery_stored_energy_change.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Operation stored_energy_change of the type of model Battery: the
# change of the energy the battery stores on each row of one
# itinerary, expressed on the side of the system (kWh), so that the
# reward can value it as stored energy.
# It is computed from the flows of the row, and not from the
# difference between the stored energy of two rows. With C the
# energy the battery takes, D the energy it gives, eta_c and eta_d
# its efficiencies, f the share of the energy it keeps in the step
# after the self-discharge (f = (1 - s)^(dt / 24), s the share per
# day) and E_(k-1) the energy stored in the row before:
#   s_k = eta_d * (eta_c * C_k - D_k / eta_d - (1 - f_k) * E_(k-1))
# When the stored energy of the itinerary follows its flows,
# s_k = eta_d * (E_k - E_(k-1)). The flows are used because an
# itinerary that copies the plan from row 2 on, and starts from a
# different energy in row 1, has a jump in its stored energy between
# rows 1 and 2 that is not a change of energy of the battery: the
# jump is not valued.
# Row 1 is the initial condition of the run: its change is 0.
# -------------------------------------------------------------
# Inputs
#   asset_df  : Data frame. The table of the battery (not its view),
#               with the columns time, Elec_charge_<itinerary>,
#               Elec_discharge_<itinerary> and
#               Stored_energy_<itinerary>.
#   itinerary : Character scalar. plan, plan_flex_down or
#               plan_flex_up.
#   asset     : Named list. The parameters of the battery, its entry
#               of parameters$assets.
# -------------------------------------------------------------
# Outputs
#   Numeric vector, one value per row of asset_df (kWh of the system
#   side, positive when the battery stores energy). The run stops if
#   the itinerary is not valid, if a column is missing or if a value
#   of rows 2 to n is missing.
# -------------------------------------------------------------
# Code outline
# 1. Check the itinerary and the columns
# 2. Compute the change of each row
# -------------------------------------------------------------
# Usage instructions
# change <- battery_stored_energy_change(
#   asset_df  = piece$assets[["Battery_001"]]$df,
#   itinerary = "plan",
#   asset     = asset
# )
# -------------------------------------------------------------

battery_stored_energy_change <- function(asset_df,
                                         itinerary,
                                         asset
                                         ) {

  # -------------------------------------------------------------
  # 1. Check the itinerary and the columns
  # -------------------------------------------------------------
  {
    if (length(itinerary) != 1 ||
        !(itinerary %in% c("plan", "plan_flex_down", "plan_flex_up"))) {
      stop("battery_stored_energy_change: itinerary must be plan, ",
           "plan_flex_down or plan_flex_up (", asset$asset_id, ")")
    }

    charge_col    <- paste0("Elec_charge_", itinerary)
    discharge_col <- paste0("Elec_discharge_", itinerary)
    energy_col    <- paste0("Stored_energy_", itinerary)
    needed        <- c("time", charge_col, discharge_col, energy_col)
    missing_cols  <- setdiff(needed, names(asset_df))
    if (length(missing_cols) > 0) {
      stop("battery_stored_energy_change: the table of ", asset$asset_id,
           " is missing the columns ",
           paste(missing_cols, collapse = ", "))
    }

    n_rows <- nrow(asset_df)
  }

  # -------------------------------------------------------------
  # 2. Compute the change of each row
  # The hours of a day and the percent are conversions of unit.
  # -------------------------------------------------------------
  {
    stored_change <- numeric(n_rows)

    if (n_rows >= 2) {
      rows      <- 2:n_rows
      delta_t_h <- diff(as.numeric(asset_df$time)) / 3600
      keep      <- (1 - asset$battery$Self_discharge / 100)^(delta_t_h / 24)
      charge    <- asset_df[[charge_col]][rows]
      discharge <- asset_df[[discharge_col]][rows]
      energy_0  <- asset_df[[energy_col]][rows - 1]

      if (anyNA(delta_t_h) || anyNA(charge) || anyNA(discharge) ||
          anyNA(energy_0)) {
        stop("battery_stored_energy_change: the itinerary ", itinerary,
             " of ", asset$asset_id, " has missing values in rows 2 ",
             "to n")
      }

      eta_charge <- asset$battery$Charge_efficiency
      eta_disch  <- asset$battery$Discharge_efficiency

      stored_change[rows] <- eta_disch *
        (eta_charge * charge - discharge / eta_disch -
           (1 - keep) * energy_0)

      rm(list = c("rows", "delta_t_h", "keep", "charge", "discharge",
                  "energy_0", "eta_charge", "eta_disch"))
    }

    rm(list = c("charge_col", "discharge_col", "energy_col", "needed",
                "missing_cols", "n_rows"))
  }

  return(stored_change)
}
