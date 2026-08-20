# -------------------------------------------------------------
# Script: simulation.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# This script implements the main MPC simulation loop.
# For each MarketUTC step (row in Main_df), it performs:
#   1) Scheduling process (if Sched_Market_Name != 0)
#   2) Piloting process   (if Pilot_Market_Name != 0)
#   3) Execution process  (always)
# Scheduling and Piloting each integrate their market result the same
# way (via integrate_market_process.R): first as a differential energy
# commitment accumulated into market_commitments (Elec_net/buy/sell_plan_df,
# their _flex counterparts, and the explicit-flexibility
# Elec_flex_{down,up}_{sell,buy}_plan_df), using the market row/column
# mapping given by market_time and the per-interval SUM aggregation of
# Elec_total_plan, Elec_total_plan_flex and Elec_flex_plan; then as the
# usual absolute update of the *_plan/*_plan_flex columns of Main_df;
# then as the net cash flow of the explicit flexibility service (both
# down and up legs, value_flex_operation() - registered for both
# Scheduling and Piloting, see finding 3 of
# 01_Agent_Comments/20260817_Auditoria_Consistencia_Economica.md) and
# of the energy commitment (base energy for Scheduling, flex-adjusted
# energy for Piloting; calc_differential_cost()), each accumulated into
# its own market_commitments cost matrix and propagated unit-value-per-
# timestamp into Main_df$Elec_flex_commitment_revenue_h and
# Elec_market_net_cost_h respectively. The same two differentials are
# also broken into their elementary operations
# (value_flex_operation()/split_market_operation()) and summed, on the
# market's own row, into Main_df$Elec_flex_sell_revenue_market/
# Elec_flex_purchase_cost_market and Elec_sell_revenue_market/
# Elec_purchase_cost_market - see
# 01_Agent_Comments/20260725_Plan_Reporte_Costes_Mercados_Main_df.md.
# Every one of these signals follows the same sign convention: income
# positive, expense negative - see
# 00_Agent_Input/20260818_comentarios_observaciones_anteriores.md.
# -------------------------------------------------------------
# Inputs
# Main_df : Data frame. The main simulation data frame.
# parameters : List. Complete parameters list with all sub-lists.
# market_commitments : Named list of 12 data frames (Elec_buy/sell/net_plan_df,
# their _flex counterparts, Elec_flex_{down,up}_{sell,buy}_plan_df,
# Elec_Cost_plan_df, Elec_flex_Cost_plan_df), one row per market event,
# created by market_commitments_setup.R.
# full_market_information : Named list of 13 data frames (Elec_unit_cost_import_buy_df,
# _import_sell_df, _export_buy_df, _export_sell_df, Elec_unit_cost_distribution_df,
# and the 8 Flex_unit_cost_{down,up}_{com,exec}_{buy,sell}_df), one row per market
# event, created by full_market_information_setup.R.
# economic_analysis : Named list of economic analysis accumulators (market, slot
# and the index sub-list), created by economic_analysis_setup.R.
# -------------------------------------------------------------
# Outputs
# Main_df : Data frame. Updated with simulation results, including the
# incrementally propagated Elec_market_net_cost_h and
# Elec_flex_commitment_revenue_h columns, the lump-sum
# Elec_purchase_cost_market/Elec_sell_revenue_market/
# Elec_flex_purchase_cost_market/Elec_flex_sell_revenue_market columns,
# and (row by row, at Execution) Elec_total_no_flex.
# execution_time : List. Timing information for the simulation.
# market_commitments : Updated in place with the differential energy and
# cost commitments of every Scheduling and Piloting market executed
# during the simulation.
# economic_analysis : Updated in place with the elementary market operations of
# every Scheduling and Piloting market executed during the simulation.
# -------------------------------------------------------------
# Code outline
# 1. Data frame formatting (ensure needed columns exist)
# 2. Model initialization (set initial temperatures)
# 3. Compute auxiliary variables, the market-interval index
#    (market_time) and create simulation_control object
# 4. Main simulation loop:
#    4.0 Load Scheduling/Piloting market parameters for each row
#    4.1 Scheduling process (conditional): differential energy into
#        the market commitments, absolute Main_df update, then
#        differential cash flow of the explicit flexibility service
#        and of the base energy commitment
#    4.2 Piloting process (conditional): differential energy into
#        the market commitments, absolute Main_df update, then
#        differential cash flow of the explicit flexibility service
#        and of the flex-adjusted energy commitment
#    4.3 Execution process (always) - implement_control_step() also
#        fixes Elec_total_no_flex for the executed rows (see finding 4
#        of 00_Agent_Input/20260818_comentarios_observaciones_anteriores.md)
#    4.4 Track execution progress
# -------------------------------------------------------------
# Usage
# source(file.path("30_Simulation", "04_Scripts", "simulation.R"))
# -------------------------------------------------------------
# Where this script is used
# Sourced by Main.R, after reference_temperature_profiles.R.
# -------------------------------------------------------------
# functions/scripts called
# is_market_active(), resolve_market_index(), resolve_marginal_context(),
# run_market_process() (which calls map_optimization_aim() and
# optimize_control_step(), the latter valuing its GA reward at the
# marginal cash flow of marginal_context via reward_function(),
# compute_marginal_energy_cost() and compute_marginal_flex_revenue()),
# implement_control_step(),
# integrate_market_process() (which calls value_flex_operation(),
# propagate_unit_value(), calc_differential_cost() and
# propagate_differential_cost()), reset_index_list(), context_forecast_step()
# from 30_Simulation/03_Functions/
# -------------------------------------------------------------

# Data frame formatting
{
  # Ensure all needed columns exist
  for (CONT_001 in parameters$needed_cols) {
    if (!CONT_001 %in% names(Main_df)) {
      Main_df[[CONT_001]] <- 0
    }
  }
  rm(CONT_001)

  # Convert numeric columns to double to ensure compatibility with calculations
  # This is necessary because columns initialized with integer 0 need to accept
  # double values from period_calculation and implement_control_step
  # Automatically detect and convert all numeric columns to double
  numeric_cols <- names(Main_df)[sapply(Main_df, is.numeric)]
  numeric_cols <- setdiff(numeric_cols, c("time", "MarketUTC"))  # Exclude time columns
  for (CONT_002 in numeric_cols) {
    if (!is.double(Main_df[[CONT_002]])) {
      Main_df[[CONT_002]] <- as.double(Main_df[[CONT_002]])
    }
  }
  rm(numeric_cols, CONT_002)

  # -----------------------------------------------------------
  # Main_df becomes a data.table here, once every column it will
  # ever hold already exists.
  # The simulation loop writes into Main_df once per timestep and
  # several times per market. With a plain data frame, every one of
  # those writes goes through `[<-.data.frame`, which rebuilds the
  # object instead of editing it, so a full year (105 120 rows by
  # ~120 columns) is duplicated on each write just to change two
  # rows. setDT() converts in place and lets the loop use
  # data.table::set(), which writes into the existing columns - see
  # finding 2 of 01_Agent_Comments/20260820_Revision_Global_Codigo.md.
  # Only Main_df is converted. Every subset taken from it inside the
  # loop is turned back into a plain data frame (see the "2. Subset"
  # blocks), so period_chunk and everything downstream of it - the
  # GA, the physics, flex_evaluation() - keep data.frame semantics
  # untouched.
  # -----------------------------------------------------------
  setDT(Main_df)
}

# Model initialization
{
  set(Main_df, i = 1L, j = "Ti_exec",      value = parameters$model$Ti_0)
  set(Main_df, i = 1L, j = "Te_exec",      value = parameters$model$Te_0)
  set(Main_df, i = 1L, j = "Ti_plan",      value = parameters$model$Ti_0)
  set(Main_df, i = 1L, j = "Te_plan",      value = parameters$model$Te_0)
  set(Main_df, i = 1L, j = "Ti_plan_flex", value = parameters$model$Ti_0)
  set(Main_df, i = 1L, j = "Te_plan_flex", value = parameters$model$Te_0)
  set(Main_df, i = 1L, j = "Q_heat_exec",  value = parameters$model$Qh_0)
  set(Main_df, i = 1L, j = "Q_cool_exec",  value = parameters$model$Qc_0)
}

# Auxiliary variables and simulation control object
{
  timestamps <- list()

  timestamps$time_sec <- as.numeric(Main_df$time)
  timestamps$t0       <- timestamps$time_sec[1]

  simulation_control <- list()
  simulation_control$indexes_global <- list(
    n_steps          = nrow(Main_df),
    i0               = 0,
    i1               = 0,
    i_begin_horizon  = 0,
    i_end_horizon    = 0,
    i_end_control    = 0,
    i_impl_end       = 0,
    idx_period       = 0,
    idx_horizon      = 0,
    idx_ctrl         = 0,
    i_flex           = 0
  )
  simulation_control$indexes_local <- list(
    n_steps          = nrow(Main_df),
    i0               = 0,
    i1               = 0,
    i_begin_horizon  = 0,
    idx_period       = 0,
    i_end_horizon    = 0,
    i_end_control    = 0,
    i_impl_end       = 0,
    idx_horizon      = 0,
    idx_ctrl         = 0,
    i_flex           = 0
  )
  simulation_control$parameters <- list(
    Sched_Market_Name          = 0,
    Sched_Market_Bid_time      = 0,
    Sched_Market_Period_Begin  = 0,
    Sched_Market_Period_End    = 0,
    Sched_Optimization_Horizon = 0,
    Sched_Market_Aim           = 0,
    Pilot_Market_Name          = 0,
    Pilot_Market_Bid_time      = 0,
    Pilot_Market_Period_Begin  = 0,
    Pilot_Market_Period_End    = 0,
    Pilot_Optimization_Horizon = 0,
    Pilot_Market_Aim           = 0
  )
  simulation_control$evaluation <- list(
    optimization_aim = "NA"
  )
  simulation_control$flexibility <- list(
    flexibility_event_length = 0,
    flexibility              = 0
  )
  simulation_control$calculation_mode <- 1

  set(Main_df, j = "MarketUTC",
      value = as.POSIXct(floor(as.numeric(Main_df$time) / (parameters$market$market_resolution * 60)) *
                         (parameters$market$market_resolution * 60),
                         origin = "1970-01-01",
                         tz = "UTC"))

  market_time <- sort(unique(Main_df$MarketUTC))

}

# Simulation loop
{
  execution_time <- list()
  execution_time$t_begin <- Sys.time()

  if (parameters$debug_and_config$verbose) {
    cat("======================================\n")
    cat("======================================\n")
    cat("Simulation started.\n"                   )
    cat("Total timesteps:", simulation_control$indexes_global$n_steps, "\n" )
    cat("Period to be optimized:\n"               )
    cat("Begins ", format(min(Main_df$time)), "\n")
    cat("Ends "  , format(max(Main_df$time)), "\n")
    cat("======================================\n")
    cat("======================================\n")
  }

  for (CONT_003 in seq_len(simulation_control$indexes_global$n_steps)) {
    # =========================================================
    # 0. LOAD MARKET PARAMETERS FOR CURRENT ROW
    # =========================================================
    {
      market_parameter_fields <- c(
        "Sched_Market_Name",
        "Sched_Market_Bid_time",
        "Sched_Market_Period_Begin",
        "Sched_Market_Period_End",
        "Sched_Optimization_Horizon",
        "Sched_Market_Aim",
        "Pilot_Market_Name",
        "Pilot_Market_Bid_time",
        "Pilot_Market_Period_Begin",
        "Pilot_Market_Period_End",
        "Pilot_Optimization_Horizon",
        "Pilot_Market_Aim"
      )

      for (CONT_004 in market_parameter_fields) {
        simulation_control$parameters[[CONT_004]] <- Main_df[[CONT_004]][CONT_003]
      }
      rm(CONT_004,market_parameter_fields)
    }

    # =========================================================
    # 1. SCHEDULING PROCESS (CONDITIONAL)
    # =========================================================
    {
      market_parameters <- simulation_control$parameters[grep("^Sched_", names(simulation_control$parameters))]

      # is_market_active is called to check whether a Scheduling
      # market actually clears on this row, so the whole Scheduling
      # process below only runs when there is a market to process.
      if (is_market_active(market_parameters$Sched_Market_Name)) {
        
        # 0 Get indexes
        {
          # Global indexes (relative to full Main_df)
          {
            # resolve_market_index is called once per Scheduling
            # market-timeline field (bid time, period begin/end,
            # optimization horizon) to convert its raw timestamp into
            # the corresponding row index of Main_df.
            simulation_control$indexes_global$i0 <- resolve_market_index(
              time_raw     = market_parameters$Sched_Market_Bid_time,
              column_name  = "Sched_Market_Bid_time",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i_begin_horizon <- resolve_market_index(
              time_raw     = market_parameters$Sched_Market_Period_Begin,
              column_name  = "Sched_Market_Period_Begin",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i_end_horizon <- resolve_market_index(
              time_raw     = market_parameters$Sched_Optimization_Horizon,
              column_name  = "Sched_Optimization_Horizon",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            simulation_control$indexes_global$i_end_control <- resolve_market_index(
              time_raw     = market_parameters$Sched_Market_Period_End,
              column_name  = "Sched_Market_Period_End",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i1          <- simulation_control$indexes_global$i_end_horizon
            simulation_control$indexes_global$idx_period  <- simulation_control$indexes_global$i0:simulation_control$indexes_global$i_end_horizon
            simulation_control$indexes_global$idx_horizon <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_horizon
            simulation_control$indexes_global$idx_ctrl    <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_control
            simulation_control$indexes_global$i_flex      <- simulation_control$indexes_global$i0
            
          }
          
          # Adapt to local indexes
          {
            simulation_control$indexes_local$i0              <- 1
            simulation_control$indexes_local$i1              <- simulation_control$indexes_global$i1              - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_begin_horizon <- simulation_control$indexes_global$i_begin_horizon - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_end_horizon   <- simulation_control$indexes_global$i_end_horizon   - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_end_control   <- simulation_control$indexes_global$i_end_control   - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$idx_period      <- simulation_control$indexes_global$idx_period      - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$idx_horizon     <- simulation_control$indexes_global$idx_horizon     - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$idx_ctrl        <- simulation_control$indexes_global$idx_ctrl        - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_flex          <- simulation_control$indexes_local$i0
          }
        }
        
        # 1. Forecast context
        {
          # context_forecast_step is called to (re)generate the
          # Text_forec/SolarR_forec forecast values over this
          # Scheduling market's idx_period window, before the market
          # itself is run.
          ctx <- context_forecast_step(
            simulation_control = simulation_control,
            time_sec           = timestamps$time_sec,
            Main_df            = Main_df,
            parameters         = parameters
          )

          Main_df$Text_forec[simulation_control$indexes_global$idx_period]   <- ctx$forecast_df$Text_forec
          Main_df$SolarR_forec[simulation_control$indexes_global$idx_period] <- ctx$forecast_df$SolarR_forec

          rm(ctx)
        }

        # 2. Subset
        {
          # as.data.frame keeps the subset a plain data frame: Main_df
          # is a data.table (see "Data frame formatting"), but every
          # function downstream of period_chunk is written against
          # data.frame semantics.
          period_chunk <- as.data.frame(Main_df[simulation_control$indexes_global$idx_period, ])

          sched_timestamps <- list(
            time_sec = timestamps$time_sec[simulation_control$indexes_global$idx_period]
          )
        }

        # 3. Run market
        {
          # resolve_marginal_context is called to properly define previous
          # commitments, and unit energy/flexibility costs/revenues for this
          # market. Then to be passed-on to the actual execution of the market.
          marginal_context <- resolve_marginal_context(
            row_index               = CONT_003,
            Main_df                 = Main_df,
            simulation_control      = simulation_control,
            market_time             = market_time,
            full_market_information = full_market_information
          )

          # run_market_process is called to execute the Scheduling
          # market itself (forecast/optimization over period_chunk),
          # using the marginal context just resolved to value its result.
          scheduling_results <- run_market_process(
            prefix             = "Sched",
            row_index          = CONT_003,
            period_chunk       = period_chunk,
            market_parameters  = market_parameters,
            simulation_control = simulation_control,
            timestamps         = sched_timestamps,
            parameters         = parameters,
            marginal_context   = marginal_context
          )

          rm(marginal_context)
        }

        # 4. Integrate results (differential energy, then _plan/_plan_flex columns)
        {
          # integrate_market_process is called to accumulate the
          # Scheduling result's differential energy into
          # market_commitments and to write the absolute
          # _plan/_plan_flex columns back into Main_df.
          integration_result <- integrate_market_process(
            prefix                  = "Sched",
            row_index               = CONT_003,
            results_df              = scheduling_results,
            Main_df                 = Main_df,
            simulation_control      = simulation_control,
            market_time             = market_time,
            full_market_information = full_market_information,
            market_commitments      = market_commitments,
            economic_analysis        = economic_analysis
          )
          Main_df            <- integration_result$Main_df
          market_commitments <- integration_result$market_commitments
          economic_analysis  <- integration_result$economic_analysis

          rm(
            integration_result,
            period_chunk,
            sched_timestamps, scheduling_results
          )
        }
        
        # 5. Reset indexes
        {
          # reset_index_list is called to fetch the neutral
          # (zeroed-out) index template, so the Scheduling-specific
          # global/local indexes do not leak into the next block.
          simulation_control$indexes_global[names(reset_index_list())] <- reset_index_list()
          simulation_control$indexes_local[names(reset_index_list())]  <- reset_index_list()
        }
      }

      rm(market_parameters)
    }

    # =========================================================
    # 2. PILOTING PROCESS (CONDITIONAL)
    # =========================================================
    {
      market_parameters <- simulation_control$parameters[grep("^Pilot_", names(simulation_control$parameters))]

      # is_market_active is called to check whether a Piloting market
      # actually clears on this row, so the whole Piloting process
      # below only runs when there is a market to process.
      if (is_market_active(market_parameters$Pilot_Market_Name)) {

        # 0 Get indexes
        {
          # Global indexes (relative to full Main_df)
          {
            # resolve_market_index is called once per Piloting
            # market-timeline field (bid time, period begin/end,
            # optimization horizon) to convert its raw timestamp into
            # the corresponding row index of Main_df.
            simulation_control$indexes_global$i0 <- resolve_market_index(
              time_raw     = market_parameters$Pilot_Market_Bid_time,
              column_name  = "Pilot_Market_Bid_time",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i_begin_horizon <- resolve_market_index(
              time_raw     = market_parameters$Pilot_Market_Period_Begin,
              column_name  = "Pilot_Market_Period_Begin",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i_end_horizon <- resolve_market_index(
              time_raw     = market_parameters$Pilot_Optimization_Horizon,
              column_name  = "Pilot_Optimization_Horizon",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i_end_control <- resolve_market_index(
              time_raw     = market_parameters$Pilot_Market_Period_End,
              column_name  = "Pilot_Market_Period_End",
              row_index    = CONT_003,
              time_vector  = Main_df$time
            )
            
            simulation_control$indexes_global$i1          <- simulation_control$indexes_global$i_end_horizon
            simulation_control$indexes_global$idx_period  <- simulation_control$indexes_global$i0:simulation_control$indexes_global$i_end_horizon
            simulation_control$indexes_global$idx_horizon <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_horizon
            simulation_control$indexes_global$idx_ctrl    <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_control
            simulation_control$indexes_global$i_flex      <- simulation_control$indexes_global$i0
            
          }
          
          # Adapt to local indexes
          {
            simulation_control$indexes_local$i0              <- 1
            simulation_control$indexes_local$i1              <- simulation_control$indexes_global$i1              - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_begin_horizon <- simulation_control$indexes_global$i_begin_horizon - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_end_horizon   <- simulation_control$indexes_global$i_end_horizon   - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_end_control   <- simulation_control$indexes_global$i_end_control   - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$idx_period      <- simulation_control$indexes_global$idx_period      - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$idx_horizon     <- simulation_control$indexes_global$idx_horizon     - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$idx_ctrl        <- simulation_control$indexes_global$idx_ctrl        - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
            simulation_control$indexes_local$i_flex          <- simulation_control$indexes_local$i0
          }
        }

        # 1. Forecast context
        {
          # context_forecast_step is called to (re)generate the
          # Text_forec/SolarR_forec forecast values over this
          # Piloting market's idx_period window, before the market
          # itself is run.
          ctx <- context_forecast_step(
            simulation_control = simulation_control,
            time_sec           = timestamps$time_sec,
            Main_df            = Main_df,
            parameters         = parameters
          )

          Main_df$Text_forec[simulation_control$indexes_global$idx_period]   <- ctx$forecast_df$Text_forec
          Main_df$SolarR_forec[simulation_control$indexes_global$idx_period] <- ctx$forecast_df$SolarR_forec

          rm(ctx)
        }

        # 2. Subset
        {
          # as.data.frame keeps the subset a plain data frame - see the
          # equivalent note in the Scheduling block above.
          period_chunk <- as.data.frame(Main_df[simulation_control$indexes_global$idx_period, ])

          pilot_timestamps <- list(
            time_sec = timestamps$time_sec[simulation_control$indexes_global$idx_period]
          )
        }
        
        # 3. Run market
        {
          # resolve_marginal_context is called to properly define previous
          # commitments, and unit energy/flexibility costs/revenues for this
          # market. Then to be passed-on to the actual execution of the market.
          marginal_context <- resolve_marginal_context(
            row_index               = CONT_003,
            Main_df                 = Main_df,
            simulation_control      = simulation_control,
            market_time             = market_time,
            full_market_information = full_market_information
          )

          # run_market_process is called to execute the Piloting
          # market itself (forecast/optimization over period_chunk),
          # using the marginal context just resolved to value its result.
          piloting_results <- run_market_process(
            prefix             = "Pilot",
            row_index          = CONT_003,
            period_chunk       = period_chunk,
            market_parameters  = market_parameters,
            simulation_control = simulation_control,
            timestamps         = pilot_timestamps,
            parameters         = parameters,
            marginal_context   = marginal_context
          )

          rm(marginal_context)
        }

        # 4. Integrate results (differential energy, then _plan/_plan_flex columns)
        {
          # integrate_market_process is called to accumulate the
          # Piloting result's differential energy into
          # market_commitments and to write the absolute
          # _plan/_plan_flex columns back into Main_df.
          integration_result <- integrate_market_process(
            prefix                  = "Pilot",
            row_index               = CONT_003,
            results_df              = piloting_results,
            Main_df                 = Main_df,
            simulation_control      = simulation_control,
            market_time             = market_time,
            full_market_information = full_market_information,
            market_commitments      = market_commitments,
            economic_analysis        = economic_analysis
          )
          Main_df            <- integration_result$Main_df
          market_commitments <- integration_result$market_commitments
          economic_analysis  <- integration_result$economic_analysis

          rm(
            integration_result,
            period_chunk,
            pilot_timestamps, piloting_results
          )
        }
        
        # 5. Reset indexes
        {
          # reset_index_list is called to fetch the neutral
          # (zeroed-out) index template, so the Piloting-specific
          # global/local indexes do not leak into the next block.
          simulation_control$indexes_global[names(reset_index_list())] <- reset_index_list()
          simulation_control$indexes_local[names(reset_index_list())]  <- reset_index_list()
        }
      }

      rm(market_parameters)
    }

    # =========================================================
    # 3. EXECUTION PROCESS (ALWAYS)
    # =========================================================
    {
      # 0 Get indexes
      {
        # Global indexes (relative to full Main_df)
        {
          simulation_control$indexes_global$i0              <- CONT_003
          simulation_control$indexes_global$i_begin_horizon <-simulation_control$indexes_global$i0
          simulation_control$indexes_global$i1              <- min(CONT_003 + 1L, simulation_control$indexes_global$n_steps)
          simulation_control$indexes_global$i_end_horizon   <- simulation_control$indexes_global$i1
          simulation_control$indexes_global$i_end_control   <- simulation_control$indexes_global$i1
          simulation_control$indexes_global$idx_period      <- simulation_control$indexes_global$i0:simulation_control$indexes_global$i_end_horizon
          simulation_control$indexes_global$idx_horizon     <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_horizon
          simulation_control$indexes_global$idx_ctrl        <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_control
          simulation_control$indexes_global$i_flex          <- simulation_control$indexes_global$i0
        }
        
        # Adapt to local indexes
        {
          simulation_control$indexes_local$i0              <- 1
          simulation_control$indexes_local$i1              <- simulation_control$indexes_global$i1              - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$i_begin_horizon <- simulation_control$indexes_global$i_begin_horizon - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$i_end_horizon   <- simulation_control$indexes_global$i_end_horizon   - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$i_end_control   <- simulation_control$indexes_global$i_end_control   - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$idx_period      <- simulation_control$indexes_global$idx_period      - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$idx_horizon     <- simulation_control$indexes_global$idx_horizon     - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$idx_ctrl        <- simulation_control$indexes_global$idx_ctrl        - simulation_control$indexes_global$i0 + simulation_control$indexes_local$i0
          simulation_control$indexes_local$i_flex          <- simulation_control$indexes_local$i0
        }
      }

      # 1-4. Run and integrate the execution step
      # -----------------------------------------------------------
      # Skipped when i0 == i1 (last simulation row): there is no next
      # row to pair with, so idx_period would resolve to a single
      # row and there is nothing to execute (that row already
      # received its values as the i1 endpoint of the previous step).
      # -----------------------------------------------------------
      if (simulation_control$indexes_global$i0 != simulation_control$indexes_global$i1) {

        # 1. Forecast context
        # Not needed, we just use real context

        # 2. Subset
        {
          # as.data.frame keeps the subset a plain data frame - see the
          # equivalent note in the Scheduling block above.
          period_chunk <- as.data.frame(Main_df[simulation_control$indexes_global$idx_period, ])

          timestamps$ctrl_periods <- sort(unique(Main_df$MarketUTC[simulation_control$indexes_global$idx_period]))
        }

        # 3. Run market
        {
          # implement_control_step is called to execute the real
          # (execution-phase) control action on period_chunk, using
          # the actual (non-forecast) context for this row/next-row pair.
          period_chunk <- implement_control_step(period_chunk        = period_chunk,
                                                 simulation_control  = simulation_control,
                                                 timestamps          = timestamps,
                                                 parameters          = parameters,
                                                 calculation_context = "execution"
          )
        }

        # 4. Integrate results (only execution columns, not _plan or _plan_flex)
        # -----------------------------------------------------------
        # This is the single most-executed write of the whole
        # simulation: once per timestep, for the full length of the
        # run. data.table::set() writes the two affected rows straight
        # into Main_df's existing columns, instead of rebuilding the
        # whole object the way `[<-.data.frame` did.
        # -----------------------------------------------------------
        {
          exec_cols <- setdiff(
            names(period_chunk),
            grep("(_plan$|_plan_flex$)", names(period_chunk), value = TRUE)
          )

          for (CONT_005 in exec_cols) {
            set(Main_df,
                i     = simulation_control$indexes_global$idx_ctrl,
                j     = CONT_005,
                value = period_chunk[[CONT_005]])
          }

          rm(period_chunk, exec_cols, CONT_005)
        }
      }

      # 5. Reset indexes
      {
        # reset_index_list is called to fetch the neutral (zeroed-out)
        # index template, so the Execution-specific global/local
        # indexes do not leak into the next simulation step.
        simulation_control$indexes_global[names(reset_index_list())] <- reset_index_list()
        simulation_control$indexes_local[names(reset_index_list())]  <- reset_index_list()
      }
    }

    # =========================================================
    # Progress tracking
    # =========================================================
    {
      execution_time$t_elapsed <- as.numeric(difftime(Sys.time(), execution_time$t_begin, units = "secs"))
      execution_time$t_estimated_total <- execution_time$t_elapsed / CONT_003 * simulation_control$indexes_global$n_steps
      execution_time$t_remaining <- execution_time$t_estimated_total - execution_time$t_elapsed

      if (parameters$debug_and_config$verbose) {
        cat("Step", CONT_003,"/", simulation_control$indexes_global$n_steps, " completed. \n")
        cat("Elapsed time:", execution_time$t_elapsed, "Estimated remaining time:", execution_time$t_remaining, "\n")
        cat("======================================\n")
      }
    }
  }
}

rm(
  list = intersect(
    c(
      "simulation_control",
      "needed_cols",
      "CONT_003",
      "CONT_004",
      "timestamps",
      "market_time",
      "market_parameter_fields"
    ),
    ls()
  )
)

execution_time$t_end <- Sys.time()
execution_time$t_process <- as.numeric(difftime(execution_time$t_end, execution_time$t_begin, units = "secs"))

if (parameters$debug_and_config$verbose) {
  cat("Simulation ended at", format(execution_time$t_end), "\n")
  cat("Total time:", execution_time$t_process, "seconds\n")
}
