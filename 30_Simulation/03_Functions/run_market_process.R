# -------------------------------------------------------------
# Function: run_market_process.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Executes one market optimization process (Scheduling or Piloting)
# over a sliced simulation period.
# -------------------------------------------------------------
# Inputs
# prefix             : Character. "Sched" or "Pilot".
# row_index          : Integer. Current simulation row index.
# period_chunk       : Data frame. Sliced Main_df period to process.
# market_parameters  : List. Market fields for the current row.
# simulation_control : List. Control metadata (indexes, evaluation,
#                      flexibility, calculation_mode).
# timestamps         : List. Timestamp metadata for period_chunk.
# parameters         : List. Simulation parameters.
# marginal_context   : Named list or NULL (default NULL). As returned
#                      by resolve_marginal_context(), computed by
#                      14_simulation.R from Main_df before this market's
#                      optimization. Passed through to
#                      optimize_control_step() (for "energy"/
#                      "flexibility" aims) and evaluate_control() (for
#                      "operationflex"); unused for "operation".
# Callers must guard the call with is_market_active() on the
# relevant *_Market_Name field; this function assumes the market is
# active and does not re-check it.
# -------------------------------------------------------------
# Outputs
# Data frame. The updated period_chunk with plan/plan_flex_down columns
# injected over the implementation horizon.
# -------------------------------------------------------------
# Usage instructions
# run_market_process(prefix, row_index, period_chunk, ...)
# -------------------------------------------------------------
# Code outline
# 1. Translate the market's aim into its internal name.
# 2. Build the forecast the decision is taken on.
# 3. Optimize, or fly the plan straight when the aim is operation.
# 4. Re-derive the itineraries of the accepted plan and value it.
# -------------------------------------------------------------
# Where this function/script is used
# Called by 14_simulation.R in scheduling and piloting blocks.
# -------------------------------------------------------------
# functions/scripts called
#   - map_optimization_aim()
#   - implement_control_step()
#   - optimize_control_step()
#   - evaluate_control()
#   - period_calculation()
#   - derive_flex_itineraries()
#   - reward_function()
# -------------------------------------------------------------

run_market_process <- function(prefix,
                               row_index,
                               period_chunk,
                               market_parameters,
                               simulation_control,
                               timestamps,
                               parameters,
                               marginal_context = NULL) {
  market_name_col   <- paste0(prefix, "_Market_Name")
  bid_time_col      <- paste0(prefix, "_Market_Bid_time")
  period_begin_col  <- paste0(prefix, "_Market_Period_Begin")
  period_end_col    <- paste0(prefix, "_Market_Period_End")
  horizon_col       <- paste0(prefix, "_Optimization_Horizon")
  market_aim_col    <- paste0(prefix, "_Market_Aim")

  # 0. Error management
  {
    if (simulation_control$indexes_local$i0 > simulation_control$indexes_local$i_begin_horizon) {
      stop("Invalid market range at row ", row_index,
           ": i0 > i_begin_horizon for ", prefix)
    }
    if (simulation_control$indexes_local$i_begin_horizon > simulation_control$indexes_local$i_end_horizon) {
      stop("Invalid market range at row ", row_index,
           ": i_begin_horizon > i_end_horizon for ", prefix)
    }
    if (simulation_control$indexes_local$i_begin_horizon > simulation_control$indexes_local$i1) {
      stop("Invalid market range at row ", row_index,
           ": i_begin_horizon > i1 for ", prefix)
    }
  }
  
  # 1. Define Optimization aim
  {
    # map_optimization_aim is called to translate this market's raw aim
    # code (market_parameters[[market_aim_col]]) into the internal aim
    # label that drives which optimization branch runs below.
    parameters$control$optimization_aim <- map_optimization_aim(
      aim_raw      = market_parameters[[market_aim_col]],
      column_name  = market_aim_col,
      row_index    = row_index
    )
    simulation_control$evaluation$optimization_aim <- parameters$control$optimization_aim
  }

  # 2. Iintialization period
  {
    if (simulation_control$indexes_local$i0 < simulation_control$indexes_local$i_begin_horizon) {
      
      # 1. Subset
      {
        init_cols <- unique(c(parameters$needed_cols, "time"))
        period_init <- data.frame(
          period_chunk[1:simulation_control$indexes_local$i_begin_horizon, init_cols]
        )
      }
      
      # 2. Check for setpoints in the initialization period and fill
      #    with defaults if missing (NA) or uninitialized (0)
      {
        if("STP_heat_plan" %in% colnames(period_init)) {
          needs_fill <- is.na(period_init$STP_heat_plan) | period_init$STP_heat_plan == 0
          period_init$STP_heat_plan[needs_fill] <-
            parameters$control$set_point_default_heating
          rm(needs_fill)
        }
        if ("STP_heat_low_plan" %in% colnames(period_init)) {
          needs_fill <- is.na(period_init$STP_heat_low_plan) | period_init$STP_heat_low_plan == 0
          period_init$STP_heat_low_plan[needs_fill] <-
            parameters$control$set_point_default_heating - parameters$control$Deadband / 2
          rm(needs_fill)
        }
        if ("STP_heat_high_plan" %in% colnames(period_init)) {
          needs_fill <- is.na(period_init$STP_heat_high_plan) | period_init$STP_heat_high_plan == 0
          period_init$STP_heat_high_plan[needs_fill] <-
            parameters$control$set_point_default_heating + parameters$control$Deadband / 2
          rm(needs_fill)
        }
        if ("STP_cool_plan" %in% colnames(period_init)) {
          needs_fill <- is.na(period_init$STP_cool_plan) | period_init$STP_cool_plan == 0
          period_init$STP_cool_plan[needs_fill] <-
            parameters$control$set_point_default_cooling
          rm(needs_fill)
        }
        if ("STP_cool_low_plan" %in% colnames(period_init)) {
          needs_fill <- is.na(period_init$STP_cool_low_plan) | period_init$STP_cool_low_plan == 0
          period_init$STP_cool_low_plan[needs_fill] <-
            parameters$control$set_point_default_cooling - parameters$control$Deadband / 2
          rm(needs_fill)
        }
        if ("STP_cool_high_plan" %in% colnames(period_init)) {
          needs_fill <- is.na(period_init$STP_cool_high_plan) | period_init$STP_cool_high_plan == 0
          period_init$STP_cool_high_plan[needs_fill] <-
            parameters$control$set_point_default_cooling + parameters$control$Deadband / 2
          rm(needs_fill)
        }
      }
      
      # 3. Initialization
      {
        # implement_control_step is called to run the initialization
        # period's setpoints through the actual (non-forecast) building
        # physics, so period_init holds real Ti/Te/comfort states before
        # any of it is injected back into period_chunk below.
        period_init <- implement_control_step(
          period_chunk        = period_init,
          simulation_control  = simulation_control,
          timestamps          = timestamps,
          parameters          = parameters,
          calculation_context = "plan"
        )
      }
      
      # 4. Injection
      {
        plan_cols <- grep("_plan$", names(period_init), value = TRUE)
        plan_cols <- plan_cols[plan_cols %in% parameters$needed_cols]
        period_chunk[simulation_control$indexes_local$i_begin_horizon, plan_cols] <-
          period_init[simulation_control$indexes_local$i_begin_horizon, plan_cols]
      }

      rm(period_init, plan_cols, init_cols)
    }
  }

  # 3. Optimization
  {
    # 1. Subset
    {
      optimization_chunk <- period_chunk[simulation_control$indexes_local$idx_horizon, ]
      
      timestamps$target_periods <- sort(unique(optimization_chunk$MarketUTC))
    }
    
    # 2. Optimization
    {
      
      if (parameters$control$optimization_aim =="energy") {
        # optimize_control_step is called to run the GA-based search for
        # the setpoints/modes that minimise marginal energy cost over
        # this horizon, since the aim is plain "energy".
        optimization_chunk <- optimize_control_step(
          period_chunk       = optimization_chunk,
          timestamps         = timestamps,
          parameters         = parameters,
          simulation_control = simulation_control,
          marginal_context   = marginal_context
        )$period_chunk
      } else if (parameters$control$optimization_aim == "flexibility") {
        # optimize_control_step is called again here for the
        # "flexibility" aim, so the same GA search additionally values
        # explicit-flexibility revenue in its reward.
        optimization_chunk <- optimize_control_step(
          period_chunk       = optimization_chunk,
          timestamps         = timestamps,
          parameters         = parameters,
          simulation_control = simulation_control,
          marginal_context   = marginal_context
        )$period_chunk
      } else if (parameters$control$optimization_aim == "operation") {
        # period_calculation is called directly (no GA search) to
        # simulate the building under the setpoints already present in
        # period_chunk, since "operation" only evaluates operation as
        # scheduled, without optimizing it.
        optimization_chunk <- period_calculation (period_chunk        = optimization_chunk,
                                                  parameters          = parameters,
                                                  calculation_mode    = 1,
                                                  calculation_context = "plan")

        # derive_flex_itineraries is called next because recomputing the
        # plan and leaving the two flexibility itineraries as they were
        # produces an incoherent pair: itineraries that belong to the
        # PREVIOUS plan, written back to Main_df beside the new one.
        # This aim optimizes nothing, so the derivation only holds what
        # is already committed over the plan it has just recomputed.
        optimization_chunk <- derive_flex_itineraries(
          period_chunk       = optimization_chunk,
          parameters         = parameters,
          simulation_control = simulation_control
        )$period_chunk

        # reward_function is called so that a market with this aim
        # reports a reward like any other. It decides nothing with it -
        # there is no search to steer - but a market that evaluates the
        # three itineraries and says nothing about them is a market
        # whose behaviour cannot be read afterwards.
        optimization_chunk <- reward_function(
          period_chunk       = optimization_chunk,
          parameters         = parameters,
          simulation_control = simulation_control,
          marginal_context   = marginal_context
        )
      } else  if (parameters$control$optimization_aim == "operationflex") {
        # evaluate_control is called directly (no GA search) to simulate
        # both the plan and the best flexibility scenario for the
        # already-scheduled setpoints, since "operationflex" evaluates
        # flexibility without optimizing the underlying schedule.
        optimization_chunk <- evaluate_control(period_chunk       = optimization_chunk,
                                               parameters         = parameters,
                                               simulation_control = simulation_control,
                                               marginal_context   = marginal_context)$period_chunk
      } else {
        stop("Invalid optimization aim: ", parameters$control$optimization_aim)
      }
    }
    
    # 3. Injection
    {
      plan_cols      <- grep("_plan$", names(optimization_chunk), value = TRUE)
      plan_flex_cols <- grep("(_plan_flex_down$|_plan_flex_up$)", names(optimization_chunk), value = TRUE)

      # A market that trades flexibility and not energy may rewrite the
      # two flexibility itineraries and the commitment they carry, but
      # not the plan itself: the plan belongs to the markets that trade
      # energy. "operationflex" re-simulates the plan on its way through
      # evaluate_control(), with the forecast of the moment and the
      # setpoints it was given, and that re-simulation used to be
      # written back to Main_df - indistinguishable, from outside, from
      # a market deciding the plan it was not allowed to touch.
      # The committed energy is kept: it is the flexibility decision,
      # even though its column ends in _plan.
      inject_cols    <- if (parameters$control$optimization_aim == "operationflex") {
        unique(c(plan_flex_cols, "Elec_flex_down_plan", "Elec_flex_up_plan"))
      } else {
        unique(c(plan_cols, plan_flex_cols))
      }
      inject_cols    <- inject_cols[inject_cols %in% parameters$needed_cols]

      # The phase codes are the optimizer's own labels and are not
      # written back: they are scratch state of the search and match the
      # pattern above only by name. Nothing outside the optimization
      # chunk reads them.
      inject_cols    <- setdiff(inject_cols,
                                c("Flex_phase_down_plan", "Flex_phase_up_plan"))
      idx_inject     <- simulation_control$indexes_local$idx_ctrl - (simulation_control$indexes_local$i_begin_horizon - 1)
      period_chunk[simulation_control$indexes_local$idx_ctrl, inject_cols] <- optimization_chunk[idx_inject, inject_cols]

      # The reward travels back per row, outside inject_cols, because it
      # is not a "_plan" column and because Main_df is not where it ends
      # up row by row: integrate_market_process() adds it up and books
      # the total on the decision's own row, the same way it books the
      # lump-sum cost signals. Carrying it here is what gives that
      # function something to add up; without it the reward the optimizer
      # maximised was computed and then discarded.
      # It is carried over the whole OPTIMIZATION horizon, not just the
      # market's period, because that is the window reward_function()
      # evaluates and whose total the optimizer maximises. Summing only
      # the period would report a different number from the one the
      # search actually compared its candidates on.
      # Every aim calls reward_function() now, "operation" included, so
      # the number carried here is always the one its own evaluation
      # produced.
      period_chunk[simulation_control$indexes_local$idx_horizon, "Reward"] <-
        optimization_chunk[["Reward"]]
    }

    rm(optimization_chunk, plan_cols, plan_flex_cols, inject_cols, idx_inject)
  }

  if (parameters$debug_and_config$verbose) {
    process_name <- if (prefix == "Sched") "Scheduling" else "Piloting"
    cat("\n")
    cat("======================================\n")
    cat(process_name, "market bid completed\n")
    cat("Market name:", as.character(market_parameters[[market_name_col]]), "\n")
    cat("Market bid time:", as.character(market_parameters[[bid_time_col]]), "\n")
    cat("Market period begin:", as.character(market_parameters[[period_begin_col]]), "\n")
    cat("Market period end:", as.character(market_parameters[[period_end_col]]), "\n")
    cat("======================================\n")
  }

  return(period_chunk)
}
