# -------------------------------------------------------------
# Function: run_market_role.R
# Part of the Model Predictive Control in buildings repository
# https://github.com/robgaray/Model-Predictive-Control-in-Buildings
# Developed by Roberto Garay Martinez
# -------------------------------------------------------------
# Overall description
# Runs, for the current row of the simulation loop, the market of
# one role: Scheduling (prefix "Sched") or Piloting (prefix
# "Pilot"). Both roles go through exactly the same steps, and only
# the prefix of the market columns tells them apart.
# If no market of the role clears on the row, nothing is done and
# the objects received are returned as they came.
# Otherwise the function:
#   - finds the rows of Main_df that the market covers (its
#     period, its optimization horizon and its control horizon)
#   - regenerates the weather forecast over the period, in Main_df
#     and in the table of each asset whose type declares it as an
#     input
#   - runs the market itself over a piece of those rows: the table
#     of the system, taken from Main_df, and one table per asset,
#     all plain data frames (build_market_piece())
#   - writes the decision into the itineraries of each asset: the
#     _plan columns and the two flexibility itineraries of its table,
#     and the commitments of Main_df (write_itineraries(), applied by
#     apply_table_writes(), which writes the net electricity of the
#     system in Main_df as the sum of that of the assets)
#   - settles the decision: the differential energy and cost
#     commitments, the elementary market operations and the cash
#     flows of Main_df (settle_market())
#   - sets the indexes back to their neutral value, so that they do
#     not leak into the next market
# Main_df and the tables of the assets are data.tables that are
# written in place (see "Data frame formatting" in simulate()), so
# the caller receives the updated tables through the returned list.
# The indexes of simulation_control are modified only inside the
# function. They are 0 when the function is called and 0 again
# when it ends, so simulation_control is not returned.
# -------------------------------------------------------------
# Inputs
# prefix                  : Character. "Sched" or "Pilot".
# row_index               : Integer. Current simulation row index.
# Main_df                 : Data table. The main simulation data
#                           frame, with the common and system
#                           columns.
# assets                  : Named list, one entry per asset, each
#                           with df, the table of the asset (a data
#                           table).
# parameters              : Named list. Simulation parameters.
# simulation_control      : Named list. Control metadata. Its
#                           parameters element holds the market
#                           columns of the current row, and its
#                           indexes elements are 0.
# timestamps              : Named list. Timestamp metadata of the
#                           whole simulation (time_sec).
# market_time             : POSIXct vector. Sorted unique
#                           MarketUTC intervals of the simulation.
# market_index            : Data frame. The market events of both
#                           families and the periods they trade, as
#                           market_event_index() lists them, built
#                           once for the whole simulation.
# full_market_information : Named list of 13 market-event price
#                           data frames (read-only).
# market_commitments      : Named list of 12 market-event output
#                           data frames.
# economic_analysis       : Named list of economic analysis
#                           accumulators (market, slot and index).
# worker_cluster          : Cluster of worker processes of the
#                           simulation when parallel = 1, NULL
#                           otherwise.
# console_state           : Environment. The record of the console
#                           messages of the run, updated in place:
#                           market_name_width (width of the market
#                           names), and no_history_markets and
#                           no_history_instants (what the markets
#                           report about the forecast). The first
#                           market whose forecast has instants with no
#                           history writes a warning, and the totals
#                           are reported at the end of the run.
# -------------------------------------------------------------
# Outputs
# Named list with:
#   Main_df            : Data table. Updated with the net
#                        electricity of the system, the commitments,
#                        the forecast columns and the market cash
#                        flow columns.
#   assets             : Named list. The table of each asset,
#                        updated with the absolute *_plan/
#                        *_plan_flex_down/*_plan_flex_up columns.
#   market_commitments : Named list. Updated with the differential
#                        energy and cost commitments of the market.
#   economic_analysis  : Named list. Updated with the elementary
#                        operations of the market and the totals of
#                        its decision.
# -------------------------------------------------------------
# Code outline
# 1. Market parameters and check that a market clears
# 2. Indexes
#    2.1. Global indexes
#    2.2. Local indexes
# 3. Forecast context
# 4. Subset
# 5. Run market
# 6. Integrate results
#    6.1. Itineraries of the assets
#    6.2. Settlement of the market
# 7. Reset indexes
# -------------------------------------------------------------
# Usage instructions
# market_result <- run_market_role(
#   prefix                  = "Sched",
#   row_index               = CONT_003,
#   Main_df                 = Main_df,
#   assets                  = assets,
#   parameters              = parameters,
#   simulation_control      = simulation_control,
#   timestamps              = timestamps,
#   market_time             = market_time,
#   market_index            = market_index,
#   full_market_information = full_market_information,
#   market_commitments      = market_commitments,
#   economic_analysis       = economic_analysis,
#   worker_cluster          = worker_cluster,
#   console_state           = console_state
# )
# -------------------------------------------------------------

run_market_role <- function(prefix,
                            row_index,
                            Main_df,
                            assets,
                            parameters,
                            simulation_control,
                            timestamps,
                            market_time,
                            market_index,
                            full_market_information,
                            market_commitments,
                            economic_analysis,
                            worker_cluster,
                            console_state) {

  # -------------------------------------------------------------
  # 1. Market parameters and check that a market clears
  # The market columns of this role are taken from the parameters
  # of the current row. The rest of the function only runs when
  # there is a market to process.
  # -------------------------------------------------------------
  {
    market_parameters <- simulation_control$parameters[
      grep(paste0("^", prefix, "_"), names(simulation_control$parameters))
    ]

    # is_market_active is called to check whether a market of this
    # role actually clears on this row, so the whole process below
    # only runs when there is a market to process.
    market_is_active <- is_market_active(
      market_name_raw = market_parameters[[paste0(prefix, "_Market_Name")]]
    )
  }

  if (market_is_active) {

    # -----------------------------------------------------------
    # 2. Indexes
    # The rows of Main_df that the market covers, as global indexes
    # (relative to the full Main_df) and as local indexes (relative
    # to the piece of Main_df cut in block 4).
    # 2.1. Global indexes
    # 2.2. Local indexes
    # -----------------------------------------------------------
    {
      # ---------------------------------------------------------
      # 2.1. Global indexes
      # The row of every field of the market timeline, and the
      # ranges of rows derived from them.
      # ---------------------------------------------------------
      {
        # resolve_market_index is called once per market-timeline
        # field (bid time, period begin/end, optimization horizon)
        # to convert its raw timestamp into the corresponding row
        # index of Main_df.
        simulation_control$indexes_global$i0 <- resolve_market_index(
          time_raw    = market_parameters[[paste0(prefix, "_Market_Bid_time")]],
          column_name = paste0(prefix, "_Market_Bid_time"),
          row_index   = row_index,
          time_vector = Main_df$time
        )

        simulation_control$indexes_global$i_begin_horizon <- resolve_market_index(
          time_raw    = market_parameters[[paste0(prefix, "_Market_Period_Begin")]],
          column_name = paste0(prefix, "_Market_Period_Begin"),
          row_index   = row_index,
          time_vector = Main_df$time
        )

        simulation_control$indexes_global$i_end_horizon <- resolve_market_index(
          time_raw    = market_parameters[[paste0(prefix, "_Optimization_Horizon")]],
          column_name = paste0(prefix, "_Optimization_Horizon"),
          row_index   = row_index,
          time_vector = Main_df$time
        )

        simulation_control$indexes_global$i_end_control <- resolve_market_index(
          time_raw    = market_parameters[[paste0(prefix, "_Market_Period_End")]],
          column_name = paste0(prefix, "_Market_Period_End"),
          row_index   = row_index,
          time_vector = Main_df$time
        )

        # The market controls the time steps of its period, which
        # end at the rows after Period_Begin. A period with no time
        # step trades nothing, and build_market_timeline() does not
        # place such a market.
        if (simulation_control$indexes_global$i_end_control <=
            simulation_control$indexes_global$i_begin_horizon) {
          stop("run_market_role.R: the market clearing at row ", row_index,
               " has a control period with no time step.")
        }
        simulation_control$indexes_global$idx_period  <- simulation_control$indexes_global$i0:simulation_control$indexes_global$i_end_horizon
        simulation_control$indexes_global$idx_horizon <- (simulation_control$indexes_global$i_begin_horizon + 1L):simulation_control$indexes_global$i_end_horizon
        simulation_control$indexes_global$idx_ctrl    <- (simulation_control$indexes_global$i_begin_horizon + 1L):simulation_control$indexes_global$i_end_control
        simulation_control$indexes_global$i_flex      <- simulation_control$indexes_global$i0
      }

      # ---------------------------------------------------------
      # 2.2. Local indexes
      # The same indexes, counted from the first row of the piece
      # of Main_df that the market works on.
      # ---------------------------------------------------------
      {
        # to_local_indexes is called to shift the global indexes
        # so that i0 becomes row 1 of the piece of Main_df cut
        # for this period.
        local_indexes <- to_local_indexes(
          indexes_global = simulation_control$indexes_global
        )
        simulation_control$indexes_local[names(local_indexes)] <- local_indexes

        rm(list = "local_indexes")
      }
    }

    # -----------------------------------------------------------
    # 3. Forecast context
    # The weather forecast, and the mean outdoor temperature known
    # when the market clears, are regenerated over the period of the
    # market, in Main_df and in the table of each asset that holds
    # them, before the market itself is run.
    # -----------------------------------------------------------
    {
      # context_forecast_step is called to (re)generate the
      # Text_forec/SolarR_forec forecast values over this market's
      # idx_period window, and the T_ext_24h_forec the plan reads (the
      # mean Text of the day before the clearing date), before the
      # market itself is run.
      ctx <- context_forecast_step(
        simulation_control = simulation_control,
        time_sec           = timestamps$time_sec,
        Main_df            = Main_df,
        parameters         = parameters
      )

      # set() writes the forecast into the existing columns of
      # Main_df. Assigning through Main_df$col[rows] <- would make
      # data.table copy the whole table, every column of it.
      set(Main_df,
          i     = simulation_control$indexes_global$idx_period,
          j     = "Text_forec",
          value = ctx$forecast_df$Text_forec)
      set(Main_df,
          i     = simulation_control$indexes_global$idx_period,
          j     = "SolarR_forec",
          value = ctx$forecast_df$SolarR_forec)
      set(Main_df,
          i     = simulation_control$indexes_global$idx_period,
          j     = "T_ext_24h_forec",
          value = ctx$forecast_df$T_ext_24h_forec)

      # copy_asset_inputs is called to write the same forecast into
      # the table of each asset whose type declares it as an input,
      # so both tables hold the same values on the rows of this
      # market before the piece is built.
      assets <- copy_asset_inputs(
        Main_df    = Main_df,
        assets     = assets,
        parameters = parameters,
        rows       = simulation_control$indexes_global$idx_period,
        columns    = c("Text_forec", "SolarR_forec", "T_ext_24h_forec")
      )

      # The instants with no history are noted in console_state. The
      # first market that has some writes a warning right away, and
      # the totals are reported at the end of the run.
      if (ctx$no_history > 0L) {
        if (console_state$no_history_markets == 0L) {
          # console_message is called to warn, at the instant of the
          # market, that the forecast keeps the actual value where
          # there is no history.
          console_message(
            label = "WARNING",
            text  = paste0("imperfect_forecast: ", ctx$no_history,
                           " instants of the forecast of the weather ",
                           "keep their actual value (no history)"),
            time  = Main_df$time[simulation_control$indexes_global$i0]
          )
        }
        console_state$no_history_markets  <- console_state$no_history_markets + 1L
        console_state$no_history_instants <- console_state$no_history_instants + ctx$no_history
      }

      rm(list = "ctx")
    }

    # -----------------------------------------------------------
    # 4. Subset
    # The piece of the market: the rows of Main_df and of the table of
    # each asset over the period of the market.
    # -----------------------------------------------------------
    {
      # build_market_piece is called to take the rows of the period
      # from Main_df and from the table of each asset, each into a
      # plain data frame: the tables are data.tables (see "Data frame
      # formatting" in simulate()), but every function downstream of
      # the piece is written against data.frame semantics.
      piece <- build_market_piece(
        Main_df = Main_df,
        assets  = assets,
        rows    = simulation_control$indexes_global$idx_period
      )

      market_timestamps <- list(
        time_sec = timestamps$time_sec[simulation_control$indexes_global$idx_period]
      )
    }

    # -----------------------------------------------------------
    # 5. Run market
    # The market is run over the piece, valued with the marginal
    # context of this row.
    # -----------------------------------------------------------
    {
      # resolve_marginal_context is called to properly define previous
      # commitments, and unit energy/flexibility costs/revenues for this
      # market. Then to be passed-on to the actual execution of the market.
      marginal_context <- resolve_marginal_context(
        row_index               = row_index,
        Main_df                 = Main_df,
        simulation_control      = simulation_control,
        market_time             = market_time,
        market_index            = market_index,
        full_market_information = full_market_information,
        parameters              = parameters
      )

      # run_market_process is called to execute the market itself
      # (forecast/optimization over the piece), using the
      # marginal context just resolved to value its result.
      market_piece <- run_market_process(
        prefix             = prefix,
        row_index          = row_index,
        piece              = piece,
        market_parameters  = market_parameters,
        simulation_control = simulation_control,
        timestamps         = market_timestamps,
        parameters         = parameters,
        marginal_context   = marginal_context,
        worker_cluster     = worker_cluster,
        market_name_width  = console_state$market_name_width
      )

      rm(list = "marginal_context")
    }

    # -----------------------------------------------------------
    # 6. Integrate results
    # The decision is written into the itineraries of the assets
    # first, and then settled. The settlement spreads the cash flow
    # of each interval over its rows, weighted by the energy of the
    # plan and of the commitments as this decision leaves them, so
    # it reads them once the itineraries are written.
    # 6.1. Itineraries of the assets
    # 6.2. Settlement of the market
    # -----------------------------------------------------------
    {
      # ---------------------------------------------------------
      # 6.1. Itineraries of the assets
      # The absolute plan and flexibility itineraries of each asset,
      # and the commitments of the system, over the control rows.
      # The energy of every row before the decision is kept first,
      # for the settlement.
      # ---------------------------------------------------------
      {
        # write_itineraries is called to get the writes of the plan
        # and of the two flexibility itineraries of each asset, and of
        # the commitments of the system, that the market leaves on its
        # control rows.
        itinerary_writes <- write_itineraries(
          piece              = market_piece,
          simulation_control = simulation_control,
          parameters         = parameters
        )

        # The settlement sees only the energy of each row and its
        # market interval:
        #   - the net electricity of the system in the plan and in
        #     the downward itinerary
        #   - the flexibility committed on each leg
        # system_net_energy_column is called to name the columns of
        # the net electricity of the system. Selecting the columns
        # copies them, so energy_before keeps the values before the
        # writes below.
        energy_columns <- c("MarketUTC",
                            system_net_energy_column("plan"),
                            system_net_energy_column("plan_flex_down"),
                            "Elec_flex_down_plan",
                            "Elec_flex_up_plan")
        energy_before  <- as.data.frame(Main_df[, energy_columns, with = FALSE])

        # apply_table_writes is called to write what the market
        # returned into the existing columns of the table that holds
        # each one, in the order in which the writes were produced:
        # the itineraries of each asset into its table, the
        # commitments into Main_df, and the net electricity of the
        # system into Main_df as the sum of that of the assets.
        for (CONT_001 in names(assets)) {
          tables  <- apply_table_writes(
            writes   = itinerary_writes$assets[[CONT_001]],
            Main_df  = Main_df,
            assets   = assets,
            asset_id = CONT_001
          )
          Main_df <- tables$Main_df
          assets  <- tables$assets
        }
        tables  <- apply_table_writes(
          writes   = itinerary_writes$system,
          Main_df  = Main_df,
          assets   = assets,
          asset_id = NULL
        )
        Main_df <- tables$Main_df
        assets  <- tables$assets

        rm(list = c("tables", "itinerary_writes", "CONT_001"))
      }

      # ---------------------------------------------------------
      # 6.2. Settlement of the market
      # The differential energy and cost commitments, the
      # elementary market operations and the cash flows of Main_df.
      # ---------------------------------------------------------
      {
        energy_after <- as.data.frame(Main_df[, energy_columns, with = FALSE])

        # settle_market is called to accumulate the differential
        # energy of the decision into market_commitments, its
        # operations and totals into economic_analysis, and to return
        # the cash flows to add to Main_df. It receives energy,
        # commitments and prices only.
        settlement <- settle_market(
          prefix                  = prefix,
          row_index               = row_index,
          clearing_time           = Main_df$time[row_index],
          control_rows            = simulation_control$indexes_global$idx_ctrl,
          energy_before           = energy_before,
          energy_after            = energy_after,
          reward_by_step          = market_piece$system$Reward[simulation_control$indexes_local$idx_horizon],
          market_time             = market_time,
          full_market_information = full_market_information,
          market_commitments      = market_commitments,
          economic_analysis       = economic_analysis,
          parameters              = parameters
        )
        market_commitments <- settlement$market_commitments
        economic_analysis  <- settlement$economic_analysis

        # apply_table_writes is called to add the cash flows into the
        # existing columns of Main_df, in the order in which the writes
        # were produced, as above. They are cash flows of the system,
        # so they carry no asset_id.
        tables  <- apply_table_writes(
          writes   = settlement$main_df_writes,
          Main_df  = Main_df,
          assets   = assets,
          asset_id = NULL
        )
        Main_df <- tables$Main_df
        assets  <- tables$assets

        rm(list = c("tables", "settlement", "energy_columns", "energy_before",
                    "energy_after"))
      }

      rm(list = c("piece", "market_timestamps", "market_piece"))
    }

    # -----------------------------------------------------------
    # 7. Reset indexes
    # The indexes of this market are set back to their neutral
    # value.
    # -----------------------------------------------------------
    {
      # reset_index_list is called to fetch the neutral
      # (zeroed-out) index template, so the market-specific
      # global/local indexes do not leak into the next block.
      simulation_control$indexes_global[names(reset_index_list())] <- reset_index_list()
      simulation_control$indexes_local[names(reset_index_list())]  <- reset_index_list()
    }
  }

  rm(list = c("market_parameters", "market_is_active"))

  return(list(Main_df            = Main_df,
              assets             = assets,
              market_commitments = market_commitments,
              economic_analysis  = economic_analysis))
}
