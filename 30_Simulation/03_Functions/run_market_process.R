# -------------------------------------------------------------
# Function: run_market_process.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings_WORK4
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Executes one market optimization process (Scheduling or Piloting)
# over a sliced simulation period.
# -------------------------------------------------------------
# Inputs
# prefix             : Character. "Sched" or "Pilot".
# row_index          : Integer. Current simulation row index.
# period_chunk       : Data frame. Sliced Main_df period to process.
# period_start_index : Integer. Global start index of period_chunk.
# market_parameters  : List. Market fields for the current row.
# simulation_control : List. Control metadata (indexes, evaluation,
#                      flexibility, calculation_mode).
# timestamps         : List. Timestamp metadata for period_chunk.
# parameters         : List. Simulation parameters.
# -------------------------------------------------------------
# Outputs
# List with period_chunk and updated metadata.
# -------------------------------------------------------------
# Usage instructions
# run_market_process(prefix, row_index, period_chunk, ...)
# -------------------------------------------------------------
# Where this function/script is used
# Called by simulation.R in scheduling and piloting blocks.
# -------------------------------------------------------------
# functions/scripts called
# is_market_active(), resolve_market_index(), map_optimization_aim(),
# context_forecast_step(), implement_control_step(), optimize_control_step()
# -------------------------------------------------------------

run_market_process <- function(prefix,
                               row_index,
                               period_chunk,
                               market_parameters,
                               simulation_control,
                               timestamps,
                               parameters) {
  market_name_col   <- paste0(prefix, "_Market_Name")
  bid_time_col      <- paste0(prefix, "_Market_Bid_time")
  period_begin_col  <- paste0(prefix, "_Market_Period_Begin")
  period_end_col    <- paste0(prefix, "_Market_Period_End")
  horizon_col       <- paste0(prefix, "_Optimization_Horizon")
  market_aim_col    <- paste0(prefix, "_Market_Aim")

  # 0. Error management
  {
    if (!is_market_active(market_parameters[[market_name_col]])) {
      return(list(
        period_chunk      = period_chunk,
        indexes           = simulation_control$indexes_local,
        optimization_aim  = simulation_control$evaluation$optimization_aim,
        target_periods    = NULL,
        is_active         = FALSE
      ))
    }
    
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
        optimization_chunk <- optimize_control_step(
          period_chunk       = optimization_chunk,
          timestamps         = timestamps,
          parameters         = parameters,
          simulation_control = simulation_control
        )$period_chunk
      } else if (parameters$control$optimization_aim == "flexibility") {
        optimization_chunk <- optimize_control_step(
          period_chunk       = optimization_chunk,
          timestamps         = timestamps,
          parameters         = parameters,
          simulation_control = simulation_control
        )$period_chunk
      } else if (parameters$control$optimization_aim == "operation") {
        optimization_chunk <- period_calculation (period_chunk        = optimization_chunk,                                           
                                                  parameters          = parameters,
                                                  calculation_mode    = 1,
                                                  calculation_context = "plan")
      } else  if (parameters$control$optimization_aim == "operationflex") {
        optimization_chunk <- evaluate_control(period_chunk       = optimization_chunk,
                                               parameters         = parameters,
                                               simulation_control = simulation_control)$period_chunk
      } else {
        stop("Invalid optimization aim: ", parameters$control$optimization_aim)
      }
    }
    
    # 3. Injection
    {
      plan_cols      <- grep("_plan$", names(optimization_chunk), value = TRUE)
      plan_flex_cols <- grep("_plan_flex$", names(optimization_chunk), value = TRUE)
      inject_cols    <- unique(c(plan_cols, plan_flex_cols))
      inject_cols    <- inject_cols[inject_cols %in% parameters$needed_cols]
      idx_inject     <- simulation_control$indexes_local$idx_ctrl - (simulation_control$indexes_local$i_begin_horizon - 1)
      period_chunk[simulation_control$indexes_local$idx_ctrl, inject_cols] <- optimization_chunk[idx_inject, inject_cols]
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
