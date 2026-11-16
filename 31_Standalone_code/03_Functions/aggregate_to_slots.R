# -------------------------------------------------------------
# Function: aggregate_to_slots.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Turns the piece after the market process back into the itineraries
# returned by the script, one value per market interval, from the
# interval that starts at i_begin_horizon to the closing interval, the
# one that starts at i_end_control. It gives them for the system and
# for each asset of the call.
# The itineraries of an asset are those of its type of model: the
# operation slot_output of its contract turns its table into them,
# each variable aggregated by its own nature (a state is read at the
# start of the interval, a control on its first time step and an
# energy is summed over the steps of the interval).
# The itineraries of the system are its net electricity in each of
# the three itineraries, the sum of the assets, and the flexibility
# committed on the plan. Energies are summed over the time steps of
# the interval.
# The closing interval only carries the state of the assets: it
# passes the state reached at i_end_control to the next market and
# commits no energy, so the energy of the system and of the assets,
# and the commitments, are missing (NA) there.
# -------------------------------------------------------------
# Inputs
#   piece      : List. The piece after run_market_process().
#   checked    : Named list, as returned by validate_inputs().
#   parameters : Named list. Uses market$market_resolution and assets
#                (the assets of the call).
# -------------------------------------------------------------
# Outputs
#   Named list:
#     - system : list with itineraries, a list of plan,
#                plan_flex_down and plan_flex_up, each a data frame
#                with time and Elec_total (kWh, the net electricity of
#                the system); plan also carries Elec_flex_down and
#                Elec_flex_up (kWh)
#     - assets : list with one entry per asset of the call, named by
#                its asset id, each a list with itineraries: the
#                plan, plan_flex_down and plan_flex_up that the
#                operation slot_output of its type of model gives
# -------------------------------------------------------------
# Code outline
# 1. Output intervals
# 2. Itineraries of the system
# 3. Itineraries of each asset
# -------------------------------------------------------------
# Usage instructions
# itineraries <- aggregate_to_slots(piece, checked, parameters)
# -------------------------------------------------------------

aggregate_to_slots <- function(piece,
                               checked,
                               parameters
                               ) {

  # -------------------------------------------------------------
  # 1. Output intervals
  # slots is the list of the output intervals that the operation
  # slot_output of each type of model receives: out_time, n_out,
  # row_at_start, first_row and slot_rows.
  # -------------------------------------------------------------
  {
    resolution_sec <- parameters$market$market_resolution * 60
    out_time <- seq(from = checked$market$i_begin_horizon,
                    to   = checked$market$i_end_control,
                    by   = resolution_sec)
    n_out     <- length(out_time)
    committed <- seq_len(n_out - 1)

    slots <- list(
      out_time     = out_time,
      n_out        = n_out,
      row_at_start = match(as.numeric(out_time),
                           as.numeric(piece$system$time)),
      first_row    = match(as.numeric(out_time[committed]),
                           as.numeric(piece$system$MarketUTC)),
      slot_rows    = match(as.numeric(piece$system$MarketUTC),
                           as.numeric(out_time[committed]))
    )

    rm(list = c("resolution_sec", "out_time", "n_out", "committed"))
  }

  # -------------------------------------------------------------
  # 2. Itineraries of the system
  # -------------------------------------------------------------
  {
    system_itineraries <- list()

    for (CONT_001 in c("plan", "plan_flex_down", "plan_flex_up")) {
      itinerary <- data.frame(time = slots$out_time)

      # sum_over_slots is called to add up the net electricity of the
      # system over the steps of each committed interval.
      itinerary$Elec_total <- sum_over_slots(
        values = system_net_energy(piece$system, CONT_001),
        slots  = slots
      )

      if (CONT_001 == "plan") {
        # sum_over_slots is called to add up the flexibility committed
        # on each leg over the steps of each committed interval.
        itinerary$Elec_flex_down <- sum_over_slots(
          values = piece$system$Elec_flex_down_plan,
          slots  = slots
        )
        itinerary$Elec_flex_up   <- sum_over_slots(
          values = piece$system$Elec_flex_up_plan,
          slots  = slots
        )
      }

      system_itineraries[[CONT_001]] <- itinerary
    }
    rm(list = c("CONT_001", "itinerary"))
  }

  # -------------------------------------------------------------
  # 3. Itineraries of each asset
  # -------------------------------------------------------------
  {
    asset_itineraries <- list()

    for (CONT_002 in names(piece$assets)) {
      asset <- parameters$assets[[CONT_002]]

      # model_type_contract is called to take the operations of the
      # type of model of the asset.
      model <- model_type_contract(asset$asset_type)

      # The operation slot_output of the model is called to turn the
      # table of the asset into its three itineraries per interval.
      asset_itineraries[[CONT_002]] <- list(
        itineraries = model$slot_output(
          asset_df = piece$assets[[CONT_002]]$df,
          slots    = slots,
          asset    = asset
        )
      )
      rm(list = c("asset", "model"))
    }
    rm(list = "CONT_002")
  }

  rm(list = "slots")

  return(list(
    system = list(itineraries = system_itineraries),
    assets = asset_itineraries
  ))
}
