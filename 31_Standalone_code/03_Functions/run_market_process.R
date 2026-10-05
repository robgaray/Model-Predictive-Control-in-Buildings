# -------------------------------------------------------------
# Function: run_market_process.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Runs one market over the working table, from i0 to i_end_horizon:
#   1. Initial state. The thermostat state at i0 is deduced from the
#      plan's indoor temperature and setpoints with the hysteresis
#      rule of the model, and the three itineraries start from the
#      plan's state.
#   2. Initialization stretch, from i0 to i_begin_horizon. The plan is
#      flown with the setpoints it already carries, from the plan's
#      state at i0, and both flexibility itineraries are projected over
#      it: the windows committed from i0 onwards are drawn as the new
#      plan allows, without judging them and without changing any
#      commitment. The state reached at i_begin_horizon is written into
#      the working table. When a window whose Commitment Phase starts
#      in this stretch runs into the horizon, the stretch is extended to
#      the end of its Recovery Phase. The optimization continues its
#      tail over the plan of each candidate, from the state the window
#      left at i_begin_horizon, and starts no window of that leg on it.
#   3. Optimization, from i_begin_horizon to i_end_horizon, according
#      to the aim of the market:
#        - "energy", "flexibility": the modes are optimized
#        - "operation": the plan is simulated as it is and its
#          itineraries rebuilt
#        - "operationflex": the plan is simulated as it is and
#          flexibility is searched over it
#      Whatever the aim, the commitments of the market interval are
#      kept inside the commitment margin: the part the new plan no
#      longer holds is given back (see derive_flex_itineraries()).
#      That is the only flexibility a market with the "operation" aim
#      trades.
#   4. The result is written into the working table over the control
#      horizon, from i_begin_horizon to i_end_control. A market with
#      the "operationflex" aim only writes the flexibility itineraries
#      and the commitments, never the plan.
# -------------------------------------------------------------
# The first row of each stretch
# The first row of a stretch is its initial condition. Its time step
# falls in the market interval before the stretch, so it is left out
# of the valuation, and it is never the start of a flexibility window:
# its new-commitment prices and its commitments are set to 0 inside
# the stretch.
# -------------------------------------------------------------
# Inputs
#   period_chunk     : Data frame. Working table, as built by
#                      expand_to_steps() and build_comfort_bands().
#   aim_raw          : Character. Aim of the market: "E", "E+F", "O"
#                      or "O+F".
#   row_index        : Named list of row positions in period_chunk:
#                      i_begin_horizon, i_end_control, i_end_horizon.
#   parameters       : Named list. Simulation parameters.
#   marginal_context : Named list. As returned by
#                      resolve_marginal_context().
# -------------------------------------------------------------
# Outputs
#   Data frame. period_chunk with the plan, the flexibility
#   itineraries and the commitments written over the control horizon,
#   and the state written at i_begin_horizon.
# -------------------------------------------------------------
# Code outline
# 1. Aim of the market
# 2. Initial state at i0
# 3. Initialization stretch
# 4. Optimization
# 5. Injection
# -------------------------------------------------------------
# Usage instructions
# period_chunk <- run_market_process(period_chunk, "E+F", row_index,
#                                    parameters, marginal_context)
# -------------------------------------------------------------
# Where this function/script is used
#   - optimize_market(): once per call.
# -------------------------------------------------------------
# functions/scripts called
#   - map_optimization_aim(): turns the aim code into its internal name
#   - pre_horizon_window_tails(): where the windows that start before
#     the horizon end
#   - hand_over_window_tail(): what the optimization needs to continue
#     the tail of those windows
#   - period_calculation(): simulates the plan
#   - derive_flex_itineraries(): rebuilds both flexibility itineraries
#   - optimize_control_step(): optimizes the modes
#   - evaluate_control(): searches flexibility over a given plan
# -------------------------------------------------------------

run_market_process <- function(period_chunk,
                               aim_raw,
                               row_index,
                               parameters,
                               marginal_context
                               ) {

  # -------------------------------------------------------------
  # 1. Aim of the market
  # -------------------------------------------------------------
  {
    # map_optimization_aim is called to turn the aim code into the
    # internal name that selects the optimization branch below.
    parameters$control$optimization_aim <- map_optimization_aim(aim_raw = aim_raw)

    contexts <- c("plan", "plan_flex_down", "plan_flex_up")

    # Builds the simulation_control object the reward and the
    # flexibility functions read, for a stretch of the working table
    # that starts at its row 1:
    #   - indexes_local$i_end_control: last row a window may reach
    #   - indexes_local$i_flex: row where a flexibility window starts
    #   - flexibility$commitment_phase_length: 0, no window is being
    #     evaluated yet
    # The callers add the rest of the flexibility fields when they
    # evaluate a window.
    stretch_control <- function(i_end_control) {
      list(
        indexes_local = list(
          i_end_control = i_end_control,
          i_flex        = 1
        ),
        flexibility   = list(commitment_phase_length = 0)
      )
    }

    # Leaves the first row of a stretch out of any flexibility window.
    neutralize_first_row <- function(stretch) {
      stretch$Flex_unit_cost_down_com_sell[1] <- 0
      stretch$Flex_unit_cost_up_com_sell[1]   <- 0
      stretch$Elec_flex_down_plan[1]          <- 0
      stretch$Elec_flex_up_plan[1]            <- 0
      return(stretch)
    }
  }

  # -------------------------------------------------------------
  # 2. Initial state at i0
  # -------------------------------------------------------------
  # Setpoints missing over the initialization stretch take the default
  # setpoints of 02_Control.csv. The heat pump powers of the previous
  # step are 0.
  # -------------------------------------------------------------
  {
    init_rows <- seq_len(row_index$i_begin_horizon)
    deadband  <- parameters$control$Deadband
    defaults  <- list(
      STP_heat      = parameters$control$set_point_default_heating,
      STP_heat_low  = parameters$control$set_point_default_heating - deadband / 2,
      STP_heat_high = parameters$control$set_point_default_heating + deadband / 2,
      STP_cool      = parameters$control$set_point_default_cooling,
      STP_cool_low  = parameters$control$set_point_default_cooling - deadband / 2,
      STP_cool_high = parameters$control$set_point_default_cooling + deadband / 2
    )

    for (CONT_001 in contexts) {
      for (CONT_002 in names(defaults)) {
        column      <- paste0(CONT_002, "_", CONT_001)
        needs_fill  <- init_rows[is.na(period_chunk[[column]][init_rows])]
        period_chunk[[column]][needs_fill] <- defaults[[CONT_002]]
      }
    }

    Ti_0     <- period_chunk$Ti_plan[1]
    Te_0     <- period_chunk$Te_plan[1]
    heat_on  <- as.integer(Ti_0 < period_chunk$STP_heat_low_plan[1])
    cool_on  <- as.integer(Ti_0 > period_chunk$STP_cool_high_plan[1] & heat_on == 0L)

    for (CONT_003 in contexts) {
      period_chunk[[paste0("Ti_", CONT_003)]][1]       <- Ti_0
      period_chunk[[paste0("Te_", CONT_003)]][1]       <- Te_0
      period_chunk[[paste0("Act_heat_", CONT_003)]][1] <- heat_on
      period_chunk[[paste0("Act_cool_", CONT_003)]][1] <- cool_on
    }

    rm(CONT_001, CONT_002, CONT_003, column, needs_fill, deadband,
       Ti_0, Te_0, heat_on, cool_on)
  }

  # -------------------------------------------------------------
  # 3. Initialization stretch
  # -------------------------------------------------------------
  # A window whose Commitment Phase starts in this stretch may run its
  # Neutral and Recovery Phases into the optimization horizon. The
  # stretch is then extended to the end of the last of those Recovery
  # Phases, so that the window is projected whole, over the plan the
  # earlier markets left there. The optimization continues its tail
  # and starts no window of the same leg on it.
  # -------------------------------------------------------------
  {
    pre_horizon_tail <- list()

    if (row_index$i_begin_horizon > 1) {
      # pre_horizon_window_tails is called to find where the windows
      # that start in this stretch end, for each leg.
      tails    <- pre_horizon_window_tails(period_chunk,
                                           row_index$i_begin_horizon,
                                           parameters)
      init_end <- min(max(row_index$i_begin_horizon, tails$down, tails$up),
                      row_index$i_end_horizon)

      init_chunk <- neutralize_first_row(period_chunk[seq_len(init_end), ])

      # Past i_begin_horizon the plan may carry no setpoint (a market
      # that trades energy decides them). There it takes the default
      # setpoints, as the stretch before i_begin_horizon does.
      if (init_end > row_index$i_begin_horizon) {
        tail_rows <- (row_index$i_begin_horizon + 1):init_end
        for (CONT_004 in contexts) {
          for (CONT_005 in names(defaults)) {
            column     <- paste0(CONT_005, "_", CONT_004)
            needs_fill <- tail_rows[is.na(init_chunk[[column]][tail_rows])]
            init_chunk[[column]][needs_fill] <- defaults[[CONT_005]]
          }
        }
        rm(tail_rows, CONT_004, CONT_005, column, needs_fill)
      }

      init_control <- stretch_control(nrow(init_chunk))
      init_control$flexibility$restatement_mode <- "projection"

      # period_calculation is called to fly the plan over the
      # initialization stretch with the setpoints it already carries.
      init_chunk <- period_calculation(period_chunk        = init_chunk,
                                       parameters          = parameters,
                                       calculation_mode    = 1,
                                       calculation_context = "plan")
      committed_chunk <- init_chunk

      # derive_flex_itineraries is called to project both flexibility
      # itineraries over the plan just flown. No market trades this
      # stretch any more: the windows that fall in it are drawn as the
      # new plan allows, without judging them, and no commitment is
      # changed.
      init_chunk <- derive_flex_itineraries(period_chunk       = init_chunk,
                                            parameters         = parameters,
                                            simulation_control = init_control
                                            )$period_chunk

      state_columns <- unlist(lapply(contexts, function(context) {
        paste0(c("Ti", "Te", "Act_heat", "Act_cool", "Q_heat", "Q_cool",
                 "Elec_heat", "Elec_cool", "Elec_total", "Comfort"),
               "_", context)
      }))
      period_chunk[row_index$i_begin_horizon, state_columns] <-
        init_chunk[row_index$i_begin_horizon, state_columns]

      # hand_over_window_tail is called for each leg whose window runs
      # into the horizon, so that the optimization continues it over the
      # plan of each candidate.
      for (CONT_006 in c("down", "up")) {
        if (tails[[CONT_006]] > row_index$i_begin_horizon) {
          pre_horizon_tail[[CONT_006]] <- hand_over_window_tail(
            stretch_chunk   = init_chunk,
            committed_chunk = committed_chunk,
            i_begin_horizon = row_index$i_begin_horizon,
            tail_end        = min(tails[[CONT_006]], init_end),
            leg             = CONT_006,
            parameters      = parameters)
        }
      }

      rm(init_chunk, committed_chunk, init_control, state_columns, tails,
         init_end, CONT_006)
    }
    rm(init_rows, defaults)
  }

  # -------------------------------------------------------------
  # 4. Optimization
  # -------------------------------------------------------------
  {
    horizon_rows      <- row_index$i_begin_horizon:row_index$i_end_horizon
    ctrl_end_in_chunk <- row_index$i_end_control - row_index$i_begin_horizon + 1

    optimization_chunk <- neutralize_first_row(period_chunk[horizon_rows, ])
    optimization_control <- stretch_control(ctrl_end_in_chunk)
    optimization_control$flexibility$pre_horizon_tail <- pre_horizon_tail

    timestamps <- list(
      target_periods = sort(unique(optimization_chunk$MarketUTC[-1]))
    )

    aim <- parameters$control$optimization_aim

    if (aim %in% c("energy", "flexibility")) {
      # optimize_control_step is called to search the modes of the
      # horizon with the genetic algorithm.
      optimization_chunk <- optimize_control_step(
        period_chunk       = optimization_chunk,
        timestamps         = timestamps,
        parameters         = parameters,
        simulation_control = optimization_control,
        marginal_context   = marginal_context
      )$period_chunk
    } else if (aim == "operation") {
      # period_calculation is called to simulate the plan as it is,
      # since this aim optimizes nothing.
      optimization_chunk <- period_calculation(period_chunk        = optimization_chunk,
                                               parameters          = parameters,
                                               calculation_mode    = 1,
                                               calculation_context = "plan")

      # derive_flex_itineraries is called to rebuild the itineraries of
      # the commitments already held over the plan just recomputed. The
      # guard zone is the only flexibility this aim trades: the part of
      # a commitment the new plan no longer holds is given back.
      derived <- derive_flex_itineraries(
        period_chunk       = optimization_chunk,
        parameters         = parameters,
        simulation_control = optimization_control
      )
      optimization_chunk <- derived$period_chunk
      optimization_chunk$Standing_commitment_held_plan <- as.integer(derived$feasible)
      rm(derived)
    } else {
      # evaluate_control is called to simulate the plan as it is and
      # search flexibility over it, without optimizing the plan.
      optimization_chunk <- evaluate_control(
        period_chunk       = optimization_chunk,
        parameters         = parameters,
        simulation_control = optimization_control,
        marginal_context   = marginal_context
      )$period_chunk
    }

    # A window of the guard zone that would raise both thermal systems
    # over the plan of this market cannot be drawn. It is held as it
    # stands, without giving any of it back, and reported, because the
    # plan may not be able to deliver it.
    if (any(optimization_chunk$Standing_commitment_held_plan == 0L, na.rm = TRUE)) {
      warning("A flexibility commitment of the market interval is held as it stands: ",
              "rebuilding it over the plan would raise both the heating and the cooling system.",
              call. = FALSE)
    }
  }

  # -------------------------------------------------------------
  # 5. Injection
  # -------------------------------------------------------------
  # Only the control horizon is written. Rows of the working table
  # past i_end_control keep their input values.
  # -------------------------------------------------------------
  {
    itinerary_columns <- grep("(_plan|_plan_flex_down|_plan_flex_up)$",
                              names(period_chunk), value = TRUE)
    itinerary_columns <- setdiff(itinerary_columns,
                                 c("Flex_phase_down_plan", "Flex_phase_up_plan"))

    inject_columns <- if (aim == "operationflex") {
      c(grep("(_plan_flex_down|_plan_flex_up)$", itinerary_columns, value = TRUE),
        "Elec_flex_down_plan", "Elec_flex_up_plan")
    } else {
      itinerary_columns
    }

    ctrl_rows <- row_index$i_begin_horizon:row_index$i_end_control
    period_chunk[ctrl_rows, inject_columns] <-
      optimization_chunk[seq_len(ctrl_end_in_chunk), inject_columns]

    rm(itinerary_columns, inject_columns, ctrl_rows, horizon_rows,
       ctrl_end_in_chunk, optimization_chunk, optimization_control,
       timestamps, aim, pre_horizon_tail)
  }

  rm(contexts, stretch_control, neutralize_first_row)

  return(period_chunk)
}
