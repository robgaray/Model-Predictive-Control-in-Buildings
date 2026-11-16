# -------------------------------------------------------------
# Function: battery_simulate_itinerary.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Computes what a battery stores, takes from the system and gives to
# it over a chunk, for one itinerary. It is the operation
# simulate_itinerary of the contract of the type Battery (see
# model_type_contract()). Row 1 of the chunk is the initial
# condition and it is never written. Each row i >= 2 holds the
# energy of the step that ends in it, with the duration of the step,
# delta_t_h = (time[i] - time[i - 1]) / 3600. The itineraries are:
#   - plan: the battery works in the mode of each row, Mode_plan,
#       over the net electricity of the rest of the system of the
#       plan, Elec_rest_plan.
#   - execution: the battery keeps the mode of the plan, Mode_plan,
#       and works over the net electricity that the rest of the
#       system has actually had, Elec_rest_exec, so the electricity
#       it exchanges is the real one.
#   - plan_flex_down and plan_flex_up: the battery follows the energy
#       of the plan, Elec_charge_plan minus Elec_discharge_plan,
#       from the energy it stores in the itinerary, and clipped by its
#       limits. It does not choose its modes again.
# A row whose mode is missing has been decided by no market: the
# battery stops on it, and the mode 5 is written. A mode that is not
# missing nor one of the five, a 0 among them, is not valid and stops
# the run.
# The physics of the energy is in battery_trajectory(). The suffix
# of the columns follows the context: _exec, _plan, _plan_flex_down
# and _plan_flex_up.
# -------------------------------------------------------------
# Inputs
#   period_chunk        : Data frame. The chunk, with time,
#                         MarketUTC when set_point_df is given, and
#                         the columns Mode, Stored_energy, Elec_rest,
#                         Elec_charge, Elec_discharge and Elec_total
#                         of the context. The itineraries of the
#                         flexibility also read the columns of the
#                         plan.
#   asset               : Named list. The parameters of the battery,
#                         its entry of parameters$assets, with the
#                         group battery.
#   calculation_mode    : Not read.
#   calculation_context : Character. One of "execution", "plan",
#                         "plan_flex_down" and "plan_flex_up".
#   set_point_df        : Optional data frame, only read in the plan
#                         context. The control of the battery: the
#                         columns period (POSIXct, the market
#                         interval) and Mode, one row per interval.
#   Q_heat_cap          : Not read.
#   Q_cool_cap          : Not read.
#   Every operation simulate_itinerary of the contract receives the
#   same arguments (see model_type_contract()). A battery has no
#   heat or cooling power, so it does not read the last two.
# -------------------------------------------------------------
# Outputs
#   Data frame. period_chunk with Stored_energy, Elec_charge,
#   Elec_discharge and Elec_total of the context written on rows 2
#   to n, and Mode in the plan and execution contexts. A chunk of
#   fewer than 2 rows comes back as it was. The run stops if the
#   context is not valid, if set_point_df lacks an interval of the
#   chunk or repeats one, if a mode is not valid or if the net
#   electricity of the rest has missing values in the rows to
#   compute.
# -------------------------------------------------------------
# Code outline
# 1. Check the context
# 2. Set the mode of each row
# 3. Compute the request of each row
# 4. Run the battery and write the result
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- battery_simulate_itinerary(
#   period_chunk        = period_chunk,
#   asset               = asset,
#   calculation_context = "plan",
#   set_point_df        = controls[["Battery_001"]]
# )
# -------------------------------------------------------------

battery_simulate_itinerary <- function(period_chunk,
                                       asset,
                                       calculation_mode = 1,
                                       calculation_context = "execution",
                                       set_point_df = NULL,
                                       Q_heat_cap = NULL,
                                       Q_cool_cap = NULL) {

  # -------------------------------------------------------------
  # 1. Check the context
  # The column suffix depends on the context. A chunk of one row
  # has no step to compute.
  # -------------------------------------------------------------
  {
    n <- nrow(period_chunk)
    if (n < 2) {
      return(period_chunk)
    }

    col_sfx <- switch(calculation_context,
                      "execution"      = "_exec",
                      "plan"           = "_plan",
                      "plan_flex_down" = "_plan_flex_down",
                      "plan_flex_up"   = "_plan_flex_up",
                      stop("battery_simulate_itinerary: invalid ",
                           "calculation_context '", calculation_context,
                           "'"))

    rows      <- 2:n
    delta_t_h <- diff(as.numeric(period_chunk$time)) / 3600

    # battery_modes is called to get the codes of the modes.
    codes <- battery_modes()
  }

  # -------------------------------------------------------------
  # 2. Set the mode of each row
  # Only the execution and the plan have modes. The execution keeps
  # the mode of the plan. In the plan, the control of the battery
  # sets the mode of each market interval. A row that no market has
  # decided has no mode, and the battery stops on it. A mode that is
  # not one of the codes stops the run.
  # -------------------------------------------------------------
  {
    if (calculation_context %in% c("execution", "plan")) {
      mode_col <- paste0("Mode", col_sfx)

      if (calculation_context == "execution") {
        period_chunk[[mode_col]][rows] <- period_chunk$Mode_plan[rows]
      }

      if (calculation_context == "plan" && !is.null(set_point_df)) {
        missing_sp_cols <- setdiff(c("period", "Mode"),
                                   names(set_point_df))
        if (length(missing_sp_cols) > 0) {
          stop("battery_simulate_itinerary: set_point_df is missing ",
               "required columns: ",
               paste(missing_sp_cols, collapse = ", "))
        }
        if (anyDuplicated(set_point_df$period) > 0) {
          stop("battery_simulate_itinerary: set_point_df$period ",
               "contains duplicated values")
        }
        idx <- match(period_chunk$MarketUTC[rows], set_point_df$period)
        if (anyNA(idx)) {
          stop("battery_simulate_itinerary: control not found for ",
               "MarketUTC in row(s): ",
               paste(rows[is.na(idx)], collapse = ", "))
        }
        period_chunk[[mode_col]][rows] <- set_point_df$Mode[idx]
        rm(list = c("missing_sp_cols", "idx"))
      }

      row_mode  <- period_chunk[[mode_col]][rows]
      undecided <- is.na(row_mode)
      invalid   <- !undecided & !(row_mode %in% codes)
      if (any(invalid)) {
        stop("battery_simulate_itinerary: the mode ",
             paste(unique(row_mode[invalid]), collapse = ", "), " of ",
             mode_col, " in row(s) ", paste(rows[invalid], collapse = ", "),
             " is not valid: a mode is one of the codes ",
             paste(codes, collapse = ", "), ", and a row that no market ",
             "has decided has no mode (", asset$asset_id, ")")
      }
      row_mode[undecided] <- codes[["stop"]]
      rm(list = "invalid")
      period_chunk[[mode_col]][rows] <- row_mode
    }
  }

  # -------------------------------------------------------------
  # 3. Compute the request of each row
  # In the plan and the execution the request comes from the mode
  # and from the net electricity of the rest of the system. In the
  # flexibility itineraries it is the energy of the plan.
  # -------------------------------------------------------------
  {
    if (calculation_context %in% c("execution", "plan")) {
      rest_energy <- period_chunk[[paste0("Elec_rest", col_sfx)]][rows]
      if (anyNA(rest_energy)) {
        stop("battery_simulate_itinerary: Elec_rest", col_sfx,
             " has missing values in the rows to compute (",
             asset$asset_id, ")")
      }

      # battery_mode_request is called to turn the mode of each row
      # into the energy it asks the battery to exchange with the
      # system.
      energy_request <- battery_mode_request(
        mode        = row_mode,
        rest_energy = rest_energy
      )
      rm(list = c("mode_col", "row_mode", "undecided", "rest_energy"))
    } else {
      energy_request <- period_chunk$Elec_charge_plan[rows] -
        period_chunk$Elec_discharge_plan[rows]
    }
  }

  # -------------------------------------------------------------
  # 4. Run the battery and write the result
  # Row 1 is the initial condition and keeps its value.
  # -------------------------------------------------------------
  {
    # battery_trajectory is called to compute the energy the battery
    # stores, takes and gives in each step, within its limits.
    run <- battery_trajectory(
      stored_energy_start = period_chunk[[paste0("Stored_energy",
                                                  col_sfx)]][1],
      delta_t_h           = delta_t_h,
      energy_request      = energy_request,
      battery             = asset$battery
    )

    period_chunk[[paste0("Stored_energy", col_sfx)]][rows]  <-
      run$stored_energy
    period_chunk[[paste0("Elec_charge", col_sfx)]][rows]    <- run$charge
    period_chunk[[paste0("Elec_discharge", col_sfx)]][rows] <- run$discharge
    period_chunk[[paste0("Elec_total", col_sfx)]][rows]     <-
      run$charge - run$discharge

    rm(list = c("n", "col_sfx", "rows", "delta_t_h", "codes", "energy_request",
                "run"))
  }

  return(period_chunk)
}
