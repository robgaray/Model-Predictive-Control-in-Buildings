# -------------------------------------------------------------
# Function: simulate.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Runs the main MPC simulation loop and returns the final state of
# the simulation.
# For each row of Main_df, it performs:
#   1) Scheduling process (if Sched_Market_Name != 0)
#   2) Piloting process   (if Pilot_Market_Name != 0)
#   3) Execution process  (always)
# Scheduling and Piloting each run and integrate their market result
# the same way, via run_market_role(). First, write_itineraries()
# gives the absolute update of the *_plan/*_plan_flex_down/
# *_plan_flex_up columns of each asset and of the commitments of
# Main_df. Then
# settle_market() settles the decision: a differential energy
# commitment accumulated into market_commitments (its twelve tables
# are listed under Inputs), using the market row/column mapping
# given by market_time and the per-interval SUM aggregation of:
#   - Elec_total_plan
#   - Elec_total_plan_flex_down
#   - Elec_flex_down_plan
#   - Elec_flex_up_plan
# then the net cash flow of the explicit flexibility service (both
# down and up legs, value_flex_operation(), registered for both
# Scheduling and Piloting) and of the base energy commitment
# (calc_differential_cost(), the same track for Scheduling and
# Piloting), each accumulated into its own market_commitments cost
# matrix and propagated, as a unit value per timestamp, into
# Main_df$Elec_flex_commitment_revenue_h and Elec_market_net_cost_h
# respectively. The same two differentials are also broken into
# their elementary operations
# (value_flex_operation()/split_market_operation()) and summed, on
# the decision's own row of economic_analysis$decision, into
# Flex_sell_revenue/Flex_purchase_cost and Energy_sell_revenue/
# Energy_purchase_cost, next to the Reward of the decision.
# Every one of these signals follows the same sign convention:
# income positive, expense negative.
# -------------------------------------------------------------
# The state of the simulation
# state holds everything the loop reads, other than the parameters,
# and everything it updates. The loop is its only writer: the
# functions it calls return what has to be written, and the loop
# writes it. parameters is only read.
# The data are held in two kinds of table: Main_df, with what is
# common to every asset and the balances of the system, and the table
# of each asset, assets[[asset_id]]$df, one row per row of Main_df.
# The markets work on a piece of the rows they cover, with the table
# of the system, taken from Main_df, and one table per asset
# (build_market_piece()). The execution runs each asset in turn, on
# a table that joins Main_df with the table of that asset only
# (join_asset_tables()), and then settles the step once, on the net
# electricity that Main_df holds. The assets that read the net
# electricity of the rest of the system (operation reads_rest_net of
# their type of model) run after the others
# (asset_simulation_order()), and their table holds the electricity
# that the others have had in the step (write_rest_net()). What each
# piece returns is written back to the table that holds each column
# (apply_table_writes()).
# The net electricity of the system, in Main_df, is always written as
# the sum of that of the assets.
# The state is unpacked once, into objects of this function, and
# the list itself is not kept. Main_df and the table of each asset
# become data.tables here (see block 2), and every write the loop
# makes into them goes through data.table::set(), which writes into
# the existing columns. So the loop never copies a table, however
# many other objects refer to it.
# -------------------------------------------------------------
# Console
# When verbose, the loop writes through console_message(): a line
# when the run starts, one per market (written by the market when
# it ends), and one per step, which reports the energy transfer of
# the assets whatever their number and type. The end of the run and
# the warnings are written whatever verbose is. The markets note
# the instants of the forecast that found no history in
# console_state, and the totals are reported when the run ends.
# -------------------------------------------------------------
# Rows of a market
# A row holds the state of the building at its instant and the
# energy of the time step that ends there, so a market controls the
# rows whose time step lies in its control period: from the row
# after Period_Begin to the row at Period_End (idx_ctrl), and
# likewise up to the end of its optimization horizon (idx_horizon).
# The row at Period_Begin is the initial condition of the
# optimization: its time step, and its energy, belong to the
# interval before the period.
# -------------------------------------------------------------
# Inputs
# state : Named list. The state of the simulation before the loop:
#   - Main_df : Data frame. The main simulation data frame, with the
#     common and system columns, as the preparation steps leave it.
#   - assets : Named list, one entry per asset, named by its asset
#     id, each with df, the table of the asset, as the preparation
#     steps leave it.
#   - full_market_information : Named list of 13 data frames, one
#     row per market event, created by prepare_market_information()
#     (read-only):
#       - Elec_unit_cost_import_buy_df
#       - Elec_unit_cost_import_sell_df
#       - Elec_unit_cost_export_buy_df
#       - Elec_unit_cost_export_sell_df
#       - Elec_unit_cost_distribution_df
#       - Flex_unit_cost_{down,up}_{com,exec}_{buy,sell}_df (eight
#         tables, one per combination of leg, price type and side)
#   - market_commitments : Named list of 12 data frames, one row
#     per market event, created by prepare_commitments():
#       - Elec_buy_plan_df
#       - Elec_sell_plan_df
#       - Elec_net_plan_df
#       - Elec_buy_plan_flex_down_df
#       - Elec_sell_plan_flex_down_df
#       - Elec_net_plan_flex_down_df
#       - Elec_flex_down_sell_plan_df
#       - Elec_flex_down_buy_plan_df
#       - Elec_flex_up_sell_plan_df
#       - Elec_flex_up_buy_plan_df
#       - Elec_Cost_plan_df
#       - Elec_flex_Cost_plan_df
#   - economic_analysis : Named list of economic analysis
#     accumulators, created by prepare_economic_analysis():
#       - market
#       - slot
#       - index
#   - paths : List. The file paths of the simulator (read-only).
#     Uses paths$cpp_source_path, the C++ modules every worker
#     compiles when parallel == 1.
# parameters : List. Complete parameters list with all sub-lists
#   (read-only). Its asset registry (parameters$assets) gives the
#   type of model and the parameters of the building.
# -------------------------------------------------------------
# Outputs
# Named list. The final state, with the same elements as state,
# plus execution_time:
#   - Main_df : Data table. Updated with the simulation results of
#     the system, including the incrementally propagated
#     Elec_market_net_cost_h and Elec_flex_commitment_revenue_h
#     columns and (row by row, at Execution) Elec_total_no_flex.
#   - assets : Updated with the itineraries and the executed state of
#     each asset.
#   - full_market_information : as received.
#   - market_commitments : Updated with the differential energy and
#     cost commitments of every Scheduling and Piloting market
#     executed during the simulation.
#   - economic_analysis : Updated with the elementary market
#     operations of every Scheduling and Piloting market executed
#     during the simulation.
#   - paths : as received.
#   - execution_time : List. Timing information for the simulation
#     (t_begin, t_end, t_process in seconds, and the progress
#     estimates of the last step).
# -------------------------------------------------------------
# Code outline
# 1. State: check it and unpack it
# 2. Data frame formatting (ensure needed columns exist), for Main_df
#    and for the table of each asset
# 3. Model initialization (set initial temperatures of the building)
# 4. Compute auxiliary variables, the market-interval index
#    (market_time), the list of the market events (market_index) and
#    create simulation_control object
# 5. Start the worker cluster of the genetic algorithm, once,
#    when parallel == 1
# 6. Main simulation loop:
#    6.1. Load Scheduling/Piloting market parameters for each row
#    6.2. Scheduling process (conditional, run_market_role()):
#         differential energy into the market commitments, absolute
#         Main_df update, then differential cash flow of the
#         explicit flexibility service and of the base energy
#         commitment
#    6.3. Piloting process (conditional, run_market_role()): the
#         same steps as Scheduling
#    6.4. Execution process (always): for each asset, the operation
#         execute_step of its type of model (model_type_contract();
#         implement_control_step() for a Building) runs its physics
#         of the step and its columns are written into its table.
#         Then, once per row, Elec_total_no_flex is fixed for the
#         executed rows from the net electricity of the system in
#         Main_df, and settle_execution() settles their cash flows
#         from that energy and the prices
#    6.5. Track execution progress: one console line per step
# 7. Stop the worker cluster
# 8. Final state
# -------------------------------------------------------------
# Usage instructions
# state <- simulate(
#   state = list(
#     Main_df                 = Main_df,
#     assets                  = assets,
#     full_market_information = full_market_information,
#     market_commitments      = market_commitments,
#     economic_analysis       = economic_analysis,
#     paths                   = paths
#   ),
#   parameters = parameters
# )
# -------------------------------------------------------------

simulate <- function(state,
                     parameters) {

  # -------------------------------------------------------------
  # 1. State: check it and unpack it
  # Every element of the state must be present. They are taken out
  # of the list once, and the list is removed, so that the loop
  # works on objects of its own.
  # -------------------------------------------------------------
  {
    state_elements <- c(
      "Main_df",
      "assets",
      "full_market_information",
      "market_commitments",
      "economic_analysis",
      "paths"
    )
    missing_elements <- setdiff(state_elements, names(state))
    if (length(missing_elements) > 0) {
      stop("simulate.R: the state lacks the elements: ",
           paste(missing_elements, collapse = ", "))
    }

    Main_df                 <- state$Main_df
    assets                  <- state$assets
    full_market_information <- state$full_market_information
    market_commitments      <- state$market_commitments
    economic_analysis       <- state$economic_analysis
    paths                   <- state$paths

    rm(list = c("state", "state_elements", "missing_elements"))
  }

  # -------------------------------------------------------------
  # 2. Data frame formatting
  # Every needed column is created, and every numeric column is
  # turned into a double, before Main_df and the table of each asset
  # become data.tables.
  # -------------------------------------------------------------
  {
    # format_table creates at 0 every needed column the table lacks
    # and converts its numeric columns to double. This is necessary
    # because columns initialized with integer 0 need to accept double
    # values from period_calculation, implement_control_step and
    # settle_execution. The time columns are not numeric data to fill.
    format_table <- function(table, needed_columns) {
      for (CONT_001 in needed_columns) {
        if (!CONT_001 %in% names(table)) {
          table[[CONT_001]] <- 0
        }
      }
      numeric_cols <- names(table)[sapply(table, is.numeric)]
      numeric_cols <- setdiff(numeric_cols, c("time", "MarketUTC"))
      for (CONT_002 in numeric_cols) {
        if (!is.double(table[[CONT_002]])) {
          table[[CONT_002]] <- as.double(table[[CONT_002]])
        }
      }
      return(table)
    }

    Main_df <- format_table(Main_df, parameters$needed_cols)

    # -----------------------------------------------------------
    # Main_df and the table of each asset become data.tables here,
    # once every column they will ever hold already exists.
    # The simulation loop writes into them once per timestep and
    # several times per market. With a plain data frame, every one
    # of those writes goes through `[<-.data.frame`, which rebuilds
    # the object instead of editing it, so a full year (105 120 rows
    # by ~120 columns) would be duplicated on each write just to
    # change two rows. setDT() converts in place and lets the loop
    # use data.table::set(), which writes into the existing columns.
    # Only the tables are converted. Every piece taken from them
    # inside the loop is made of plain data frames
    # (build_market_piece(), in block 4 of run_market_role(), and
    # join_asset_tables(), in block 6.4.2 below, one asset at a
    # time), so the chunk of an asset and everything downstream of it
    # - the GA, the physics, flex_evaluation() - keep data.frame
    # semantics untouched.
    # -----------------------------------------------------------
    setDT(Main_df)

    for (CONT_003 in names(assets)) {
      # The columns an asset needs are those of its type of model.
      asset_df <- format_table(
        assets[[CONT_003]]$df,
        parameters$asset_cols[[parameters$assets[[CONT_003]]$asset_type]]
      )
      setDT(asset_df)
      assets[[CONT_003]]$df <- asset_df
    }
    rm(list = c("format_table", "CONT_003", "asset_df"))
  }

  # -------------------------------------------------------------
  # 3. Model initialization
  # Row 1 is the only true initial condition of the whole run: the
  # simulation loop never recomputes it, in any context. The four
  # contexts (execution, plan, plan_flex_down and plan_flex_up) are
  # therefore seeded with the same state, so that none of them
  # starts from a different building than the others.
  # The operation initial_state of the model of each asset writes
  # its initial condition into row 1 of its table, from its entry of
  # parameters$assets. An asset with no state to start has nothing
  # to write.
  # -------------------------------------------------------------
  {
    delta_t_h_init <- as.numeric(difftime(Main_df$time[2],
                                          Main_df$time[1],
                                          units = "hours"))

    for (CONT_007 in names(assets)) {
      # model_type_contract is called to take the operations of the
      # type of model of this asset, through which its initial state
      # is written.
      model <- model_type_contract(parameters$assets[[CONT_007]]$asset_type)

      # The operation initial_state of the model is called to write
      # the initial condition of the asset into row 1 of its table.
      assets[[CONT_007]]$df <- model$initial_state(
        asset_df  = assets[[CONT_007]]$df,
        asset     = parameters$assets[[CONT_007]],
        delta_t_h = delta_t_h_init
      )
      rm(list = "model")
    }

    rm(list = c("delta_t_h_init", "CONT_007"))
  }

  # -------------------------------------------------------------
  # 4. Auxiliary variables and simulation control object
  # The timestamps of the whole simulation, the control object
  # with its indexes at 0, market_time, the grid of the market
  # intervals, and market_index, the market events of both families
  # and the periods they trade.
  # -------------------------------------------------------------
  {
    timestamps <- list()

    timestamps$time_sec <- as.numeric(Main_df$time)
    timestamps$t0       <- timestamps$time_sec[1]

    simulation_control <- list()
    simulation_control$indexes_global <- list(
      n_steps          = nrow(Main_df),
      i0               = 0,
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
      commitment_phase_length = 0,
      flexibility              = 0
    )
    simulation_control$calculation_mode <- 1

    # The market interval of every row, MarketUTC, is assigned by
    # prepare_market_calendar() from the row's time step.
    # market_time is the full grid of those intervals.
    market_time <- sort(unique(Main_df$MarketUTC))

    # market_event_index is called once per family to list the market
    # events and the periods they trade. The market columns of Main_df
    # do not change during the loop, so the list is built once for the
    # whole simulation, and every market looks up the earlier prices
    # in it.
    market_index <- rbind(
      market_event_index(
        Main_df           = Main_df,
        role              = "Sched",
        market_resolution = parameters$market$market_resolution
      ),
      market_event_index(
        Main_df           = Main_df,
        role              = "Pilot",
        market_resolution = parameters$market$market_resolution
      )
    )
  }

  # -------------------------------------------------------------
  # 5. Worker cluster
  # With parallel == 1, the genetic algorithm evaluates its
  # candidates in worker processes. They are created once for the
  # whole simulation: start_worker_cluster() exports every function
  # of the simulator and compiles the C++ engine on each of them
  # only once, and each optimization then only sends the data of
  # its own market. The cluster is stopped when the loop ends (block
  # 7). With parallel == 0 there is no cluster, and worker_cluster
  # is NULL.
  # -------------------------------------------------------------
  {
    worker_cluster <- NULL
    if (parameters$debug_and_config$parallel == 1) {
      # start_worker_cluster is called to create the worker
      # processes and prepare them once for every optimization of
      # the run.
      worker_cluster <- start_worker_cluster(
        parallel_workers = parameters$debug_and_config$parallel_workers,
        random_seed      = parameters$debug_and_config$random_seed,
        cpp_source_path  = paths$cpp_source_path
      )
    }
  }

  # -------------------------------------------------------------
  # 6. Simulation loop
  # One pass per row of Main_df, in order.
  # 6.1. Market parameters of the row
  # 6.2. Scheduling process
  # 6.3. Piloting process
  # 6.4. Execution process
  # 6.5. Progress tracking
  # -------------------------------------------------------------
  {
    execution_time <- list()
    execution_time$t_begin <- Sys.time()

    # console_state is the record of the console messages of the run:
    # the width of the market names, and what the markets report about
    # the forecast. It is an environment, so that the markets update
    # it in place.
    console_state <- new.env()
    console_state$market_name_width <- max(nchar(as.character(
      c(Main_df$Sched_Market_Name, Main_df$Pilot_Market_Name)
    )))
    console_state$n_steps             <- simulation_control$indexes_global$n_steps
    console_state$no_history_markets  <- 0L
    console_state$no_history_instants <- 0L

    if (parameters$debug_and_config$verbose) {
      # console_message is called to announce the run, at its first
      # instant.
      console_message(
        label = "RUN",
        text  = paste0("Simulation of ",
                       simulation_control$indexes_global$n_steps,
                       " steps, until ", console_time(max(Main_df$time))),
        time  = min(Main_df$time)
      )
    }

    for (CONT_003 in seq_len(simulation_control$indexes_global$n_steps)) {

      # ---------------------------------------------------------
      # 6.1. Market parameters of the row
      # The twelve market columns of the row are copied into
      # simulation_control.
      # ---------------------------------------------------------
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
        rm(list = c("CONT_004", "market_parameter_fields"))
      }

      # ---------------------------------------------------------
      # 6.2. Scheduling process
      # Runs only when a Scheduling market clears on the row.
      # ---------------------------------------------------------
      {
        # run_market_role is called to run the Scheduling market of
        # this row, if one clears on it. Main_df and the tables of the
        # assets are data.tables that are written in place, and the
        # commitment and economic tables are returned, so all of them
        # are assigned back here.
        market_result <- run_market_role(
          prefix                  = "Sched",
          row_index               = CONT_003,
          Main_df                 = Main_df,
          assets                  = assets,
          parameters              = parameters,
          simulation_control      = simulation_control,
          timestamps              = timestamps,
          market_time             = market_time,
          market_index            = market_index,
          full_market_information = full_market_information,
          market_commitments      = market_commitments,
          economic_analysis       = economic_analysis,
          worker_cluster          = worker_cluster,
          console_state           = console_state
        )
        Main_df            <- market_result$Main_df
        assets             <- market_result$assets
        market_commitments <- market_result$market_commitments
        economic_analysis  <- market_result$economic_analysis

        rm(list = "market_result")
      }

      # ---------------------------------------------------------
      # 6.3. Piloting process
      # Runs only when a Piloting market clears on the row.
      # ---------------------------------------------------------
      {
        # run_market_role is called to run the Piloting market of
        # this row, if one clears on it, in the same way as the
        # Scheduling market above.
        market_result <- run_market_role(
          prefix                  = "Pilot",
          row_index               = CONT_003,
          Main_df                 = Main_df,
          assets                  = assets,
          parameters              = parameters,
          simulation_control      = simulation_control,
          timestamps              = timestamps,
          market_time             = market_time,
          market_index            = market_index,
          full_market_information = full_market_information,
          market_commitments      = market_commitments,
          economic_analysis       = economic_analysis,
          worker_cluster          = worker_cluster,
          console_state           = console_state
        )
        Main_df            <- market_result$Main_df
        assets             <- market_result$assets
        market_commitments <- market_result$market_commitments
        economic_analysis  <- market_result$economic_analysis

        rm(list = "market_result")
      }

      # ---------------------------------------------------------
      # 6.4. Execution process
      # Runs at every row: one real step of each asset, from the
      # row to the next one, with the real weather, and the
      # settlement of the step on the net electricity of the system.
      # 6.4.1. Indexes
      # 6.4.2. Execution of each asset
      # 6.4.3. Settle the execution
      # 6.4.4. Reset indexes
      # ---------------------------------------------------------
      {
        # -------------------------------------------------------
        # 6.4.1. Indexes
        # The global indexes (relative to the full Main_df) of the
        # row and the next one, and the same indexes counted from
        # the first row of the piece cut for the step, and the market
        # intervals the rows of the step fall in.
        # -------------------------------------------------------
        {
          simulation_control$indexes_global$i0              <- CONT_003
          simulation_control$indexes_global$i_begin_horizon <- simulation_control$indexes_global$i0
          simulation_control$indexes_global$i_end_horizon   <- min(CONT_003 + 1L, simulation_control$indexes_global$n_steps)
          simulation_control$indexes_global$i_end_control   <- simulation_control$indexes_global$i_end_horizon
          simulation_control$indexes_global$idx_period      <- simulation_control$indexes_global$i0:simulation_control$indexes_global$i_end_horizon
          simulation_control$indexes_global$idx_horizon     <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_horizon
          simulation_control$indexes_global$idx_ctrl        <- simulation_control$indexes_global$i_begin_horizon:simulation_control$indexes_global$i_end_control
          simulation_control$indexes_global$i_flex          <- simulation_control$indexes_global$i0

          # to_local_indexes is called to shift the global indexes
          # so that i0 becomes row 1 of the piece of Main_df cut
          # for this period.
          local_indexes <- to_local_indexes(
            indexes_global = simulation_control$indexes_global
          )
          simulation_control$indexes_local[names(local_indexes)] <- local_indexes

          rm(list = "local_indexes")

          timestamps$ctrl_periods <- sort(unique(Main_df$MarketUTC[simulation_control$indexes_global$idx_period]))
        }

        # The execution step is skipped when i0 == i_end_horizon
        # (last simulation row): there is no next row to pair with,
        # so idx_period would resolve to a single row and there is
        # nothing to execute (that row already received its values
        # as the i_end_horizon endpoint of the previous step).
        if (simulation_control$indexes_global$i0 != simulation_control$indexes_global$i_end_horizon) {

          # -----------------------------------------------------
          # 6.4.2. Execution of each asset
          # One real step of each asset. The piece of an asset joins
          # Main_df with the table of that asset only, the operation
          # execute_step of its type of model runs its physics, and
          # the columns the asset holds are written back into its
          # table. The assets that read the net electricity of the
          # rest of the system execute after the others, with the
          # electricity the others have had in the step. The forecast
          # context is not needed: the execution step uses the real
          # context. Only the execution columns
          # are written, not the _plan, _plan_flex_down or
          # _plan_flex_up ones, not the inputs of the type, and not
          # the key time.
          # This is the single most-executed write of the whole
          # simulation: once per timestep and asset, for the full
          # length of the run. data.table::set() writes the two
          # affected rows straight into the existing columns of each
          # table, instead of rebuilding the whole object as
          # `[<-.data.frame` would.
          # -----------------------------------------------------
          {
            # asset_simulation_order is called to order the assets:
            # those that read the net electricity of the rest of the
            # system execute after the others, so they read the
            # electricity the others have actually had in the step.
            simulation_order <- asset_simulation_order(parameters)
            simulated        <- character(0)

            for (CONT_008 in simulation_order) {

              asset <- parameters$assets[[CONT_008]]

              # model_type_contract is called to take the operations
              # of the type of model of the asset, which is executed
              # here.
              model <- model_type_contract(asset$asset_type)

              # join_asset_tables is called to join the two rows of
              # Main_df and of the table of this asset into one plain
              # data frame: the tables are data.tables (see block 2),
              # but every function downstream of period_chunk is
              # written against data.frame semantics.
              period_chunk <- join_asset_tables(
                Main_df      = Main_df,
                assets       = assets[CONT_008],
                rows         = simulation_control$indexes_global$idx_period,
                column_order = parameters$joined_cols
              )

              # The operation reads_rest_net of the model says whether
              # the asset works over the net electricity of the rest
              # of the system. If it does, write_rest_net is called
              # to write in its chunk the electricity that the assets
              # executed before it have had in the step.
              if (model$reads_rest_net(asset)) {
                period_chunk <- write_rest_net(
                  view      = period_chunk,
                  assets    = assets,
                  asset_ids = simulated,
                  itinerary = "exec",
                  rows      = simulation_control$indexes_global$idx_period
                )
              }

              # The operation execute_step of the model
              # (implement_control_step() for a building) is called
              # to execute the real (execution-phase) control action
              # on period_chunk, using the actual (non-forecast)
              # context for this row/next-row pair. It runs the
              # physics of the asset only.
              period_chunk <- model$execute_step(
                period_chunk        = period_chunk,
                simulation_control  = simulation_control,
                timestamps          = timestamps,
                parameters          = parameters,
                asset               = asset,
                calculation_context = "execution"
              )

              # itinerary_columns is called to name the columns of
              # the plan and of the two flexibility itineraries,
              # which the markets write; the commitments and the
              # phase codes of the two legs belong to the plan too.
              exec_cols <- setdiff(
                names(period_chunk),
                c("time",
                  itinerary_columns("plan", parameters),
                  itinerary_columns("plan_flex_down", parameters),
                  itinerary_columns("plan_flex_up", parameters),
                  "Elec_flex_down_plan", "Elec_flex_up_plan",
                  "Flex_phase_down_plan", "Flex_phase_up_plan")
              )
              exec_cols <- intersect(
                exec_cols,
                setdiff(names(assets[[CONT_008]]$df), "time")
              )

              # The inputs of the type are copies of Main_df, never
              # written by the execution.
              exec_cols <- setdiff(
                exec_cols,
                parameters$asset_input_cols[[
                  parameters$assets[[CONT_008]]$asset_type
                ]]
              )
              exec_writes <- lapply(exec_cols, function(CONT_005) {
                list(column = CONT_005,
                     rows   = simulation_control$indexes_global$idx_ctrl,
                     value  = period_chunk[[CONT_005]],
                     mode   = "assign")
              })

              # apply_table_writes is called to write each execution
              # column into the table of the asset, and the executed
              # net electricity of the system as the sum of that of
              # the assets.
              tables  <- apply_table_writes(
                writes   = exec_writes,
                Main_df  = Main_df,
                assets   = assets,
                asset_id = CONT_008
              )
              Main_df <- tables$Main_df
              assets  <- tables$assets

              simulated <- c(simulated, CONT_008)
              rm(list = c("asset", "model", "period_chunk", "exec_cols",
                          "exec_writes", "tables"))
            }
            rm(list = c("CONT_008", "simulation_order", "simulated"))
          }

          # -----------------------------------------------------
          # 6.4.3. Settle the execution
          # The cash flows of the executed row: the system side of
          # the execution. It reads the net energy of the system that
          # Main_df holds once every asset has executed the step, the
          # prices of the row and the cash flow its markets
          # accumulated. It is settled once per row, never per asset.
          # -----------------------------------------------------
          {
            new_rows <- simulation_control$indexes_global$idx_period[-1]

            # system_net_energy is called to read the executed net
            # electricity of the system, the sum over the assets that
            # Main_df holds.
            exec_energy <- system_net_energy(Main_df, "exec")[new_rows]

            # system_net_energy is called to read the net electricity
            # of the system in the plan, the only other energy the
            # settlement works with.
            # settle_execution is called to value the deviation of the
            # executed energy from the plan, the distribution cost and
            # the net cost of the executed row.
            settlement <- settle_execution(
              energy_plan        = system_net_energy(Main_df, "plan")[new_rows],
              energy_exec        = exec_energy,
              price_import_buy   = Main_df$Elec_unit_cost_import_buy[new_rows],
              price_import_sell  = Main_df$Elec_unit_cost_import_sell[new_rows],
              price_export_buy   = Main_df$Elec_unit_cost_export_buy[new_rows],
              price_export_sell  = Main_df$Elec_unit_cost_export_sell[new_rows],
              price_distribution = Main_df$Elec_unit_cost_distribution[new_rows],
              market_net_cost    = Main_df$Elec_market_net_cost_h[new_rows]
            )

            # Elec_total_no_flex is fixed once per executed row: the
            # executed net electricity of the system without an
            # executed flexibility event. Until flexibility execution
            # is simulated, it equals the executed energy.
            system_writes <- list(
              list(column = "Elec_total_no_flex",
                   rows   = new_rows,
                   value  = exec_energy,
                   mode   = "assign"),
              list(column = "Elec_deviations_net_cost_h",
                   rows   = new_rows,
                   value  = settlement$deviations_net_cost,
                   mode   = "assign"),
              list(column = "Elec_cost_distr_h",
                   rows   = new_rows,
                   value  = settlement$distribution_cost,
                   mode   = "assign"),
              list(column = "Elec_net_cost_h",
                   rows   = new_rows,
                   value  = settlement$net_cost,
                   mode   = "assign")
            )

            # apply_table_writes is called to write the four columns
            # of the system into Main_df.
            tables  <- apply_table_writes(
              writes   = system_writes,
              Main_df  = Main_df,
              assets   = assets,
              asset_id = NULL
            )
            Main_df <- tables$Main_df
            assets  <- tables$assets

            rm(list = c("new_rows", "exec_energy", "settlement",
                        "system_writes", "tables"))
          }
        }

        # -------------------------------------------------------
        # 6.4.4. Reset indexes
        # The indexes of the execution step are set back to their
        # neutral value.
        # -------------------------------------------------------
        {
          # reset_index_list is called to fetch the neutral
          # (zeroed-out) index template, so the Execution-specific
          # global/local indexes do not leak into the next
          # simulation step.
          simulation_control$indexes_global[names(reset_index_list())] <- reset_index_list()
          simulation_control$indexes_local[names(reset_index_list())]  <- reset_index_list()
        }
      }

      # ---------------------------------------------------------
      # 6.5. Progress tracking
      # The elapsed and the remaining time, written when verbose as the
      # line of the step: the energy transfer of the assets, once per
      # step.
      # ---------------------------------------------------------
      {
        execution_time$t_elapsed <- as.numeric(difftime(Sys.time(), execution_time$t_begin, units = "secs"))
        execution_time$t_estimated_total <- execution_time$t_elapsed / CONT_003 * simulation_control$indexes_global$n_steps
        execution_time$t_remaining <- execution_time$t_estimated_total - execution_time$t_elapsed

        if (parameters$debug_and_config$verbose) {
          # console_duration is called to write the elapsed and the
          # remaining time as h:mm:ss.
          # console_message is called to write the line of the step:
          # the energy transfer of the assets, at the instant where it
          # ends, and the progress of the run.
          console_message(
            label = "TRANSFER",
            text  = paste0(
              "Step ",
              formatC(CONT_003,
                      width = nchar(simulation_control$indexes_global$n_steps)),
              " / ", simulation_control$indexes_global$n_steps,
              "  elapsed ", console_duration(execution_time$t_elapsed),
              "  remaining ", console_duration(execution_time$t_remaining)
            ),
            time  = Main_df$time[min(CONT_003 + 1L, nrow(Main_df))]
          )
        }
      }
    }

    rm(list = c("CONT_003", "simulation_control", "timestamps", "market_time",
                "market_index"))
  }

  # -------------------------------------------------------------
  # 7. Stop the worker cluster
  # rm() + gc() release the PSOCK connection objects right away;
  # otherwise R's automatic gc cycles may not reach them before the
  # session ends, and they get closed with a warning at exit.
  # -------------------------------------------------------------
  {
    if (!is.null(worker_cluster)) {
      stopCluster(worker_cluster)
      registerDoSEQ()
    }
    rm(list = "worker_cluster")
    gc(verbose = FALSE)
  }

  # -------------------------------------------------------------
  # 8. Final state
  # The total duration of the loop is stored, and the state is
  # returned with every element it received, plus execution_time.
  # -------------------------------------------------------------
  {
    execution_time$t_end     <- Sys.time()
    execution_time$t_process <- as.numeric(difftime(execution_time$t_end,
                                                    execution_time$t_begin,
                                                    units = "secs"))

    # console_message is called to report what the markets noted about
    # the forecast, once, at the end of the run: the weather forecast
    # keeps the actual value where there is no history to blend.
    if (console_state$no_history_markets > 0L) {
      console_message(
        label = "WARNING",
        text  = paste0("imperfect_forecast: ",
                       console_state$no_history_markets,
                       " markets had instants with no history, ",
                       console_state$no_history_instants,
                       " instants in total"),
        time  = max(Main_df$time)
      )
    }

    # console_duration is called to write the total time as h:mm:ss.
    # console_message is called to close the run, at its last instant.
    console_message(
      label = "RUN",
      text  = paste0("Simulation ended: ",
                     console_state$n_steps,
                     " steps in ",
                     console_duration(execution_time$t_process)),
      time  = max(Main_df$time)
    )

    rm(list = "console_state")
  }

  return(list(
    Main_df                 = Main_df,
    assets                  = assets,
    full_market_information = full_market_information,
    market_commitments      = market_commitments,
    economic_analysis       = economic_analysis,
    paths                   = paths,
    execution_time          = execution_time
  ))
}
